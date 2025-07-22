/*
 *     Copyright (C) 2025 Akashy Patel
 *
 *     Reverbio is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Reverbio is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Reverbio, including how to contribute,
 *     please visit: https://github.com/akashskypatel/Reverbio
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_js/extensions/fetch.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/data_manager.dart';
import 'package:reverbio/services/router_service.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/services/widget_factory.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/section_header.dart';
import 'package:reverbio/widgets/spinner.dart';

typedef WF = WidgetFactory;

class PluginsManager {
  PluginsManager._();
  static final _pluginsCacheData =
      Hive.box('settings').get('pluginsData', defaultValue: []) as List;
  static final pluginsDataNotifier = ValueNotifier(_pluginsCacheData.length);
  static List testMethods = ['pluginName', 'pluginVersion', 'asyncTest'];
  static List get pluginsData => _pluginsCacheData;
  static final List<Map> _plugins = [];
  static final Map _futures = {};
  static final Map _activeJob = {};
  static final Map _completed = {};
  static final Map<String, ValueNotifier<int>> _backgroundJobNotifiers = {};
  static final Map<String, ValueNotifier<bool>> _isProcessingNotifiers = {};

  static Map<String, ValueNotifier<bool>> get isProcessing =>
      _isProcessingNotifiers;
  static Map<String, ValueNotifier<int>> get backgroundJobNotifier =>
      _backgroundJobNotifiers;
  static List<Map> get plugins => _plugins;

  static Future<String> _fetchAndEvaluate(String url) async {
    try {
      final flutterJs = getJavascriptRuntime();
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final result = flutterJs.evaluate(response.body);
        if (!result.isError) return response.body;
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  static Future<void> initialize() async {
    await reloadPlugins();
    await syncPlugins();
  }

  static Future<bool> syncPlugin(Map _plugin) async {
    if (_isProcessingNotifiers[_plugin['name']]!.value) {
      final context = NavigationManager().context;
      showToast(
        '${_plugin['name']}: ${context.l10n!.cannotSyncPlugin}. ${context.l10n!.waitForJob}.',
      );
      return false;
    }
    try {
      _plugin = _plugins.firstWhere(
        (value) => value['name'] == _plugin['name'],
      );
      final settings = getUserSettings(_plugin['name']);
      _plugin['settings'] = settings;
      String jsContent = '';
      if (isFilePath(settings['source'])) {
        if (doesFileExist(settings['source'])) {
          jsContent = await File(settings['source']).readAsString();
        }
      } else if (await checkUrl(settings['source']) < 400) {
        final uri = Uri.parse(settings['source']);
        final response = await http.get(uri);
        jsContent = response.body;
      }
      if (jsContent.isNotEmpty) {
        _pluginsCacheData.removeWhere(
          (value) => value['name'] == _plugin['name'],
        );
        final data = await getPluginData(jsContent);
        final flutterJs = getJavascriptRuntime();
        await flutterJs.enableFetch();
        await flutterJs.enableHandlePromises();
        final result = flutterJs.evaluate(data['script']);
        if (!result.isError) {
          _pluginsCacheData.add(data);
          flutterJs.dispose();
          return true;
        }
      }
      return false;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return false;
    }
  }

  static Future<void> syncPlugins() async {
    try {
      for (final _plugin in _plugins) {
        await syncPlugin(_plugin);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static Future<void> reloadPlugins() async {
    try {
      _plugins.clear();
      for (final _plugin in _pluginsCacheData) {
        if (_plugins
            .where((value) => value['name'] == _plugin['name'])
            .toList()
            .isEmpty) {
          _plugins.add({'name': _plugin['name'], 'script': _plugin['script']});
          _isProcessingNotifiers[_plugin['name']] = ValueNotifier(false);
          _backgroundJobNotifiers[_plugin['name']] = ValueNotifier(-1);
          _futures[_plugin['name']] = [];
          _completed[_plugin['name']] = [];
          _activeJob[_plugin['name']] = null;
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static Map<String, dynamic> _extractManifest(String jsCode) {
    try {
      final (result, _) = PluginsManager._executeMethod(
        script: jsCode,
        methodName: 'pluginManifest',
      );

      if (result == null || result.isError) return {};

      return Map<String, dynamic>.from(jsonDecode(result.stringResult));
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return {};
    }
  }

  static Future<String> _loadValidateDependencies(String jsCode) async {
    try {
      final flutterJs = getJavascriptRuntime();
      bool isValid = true;
      final manifest = _extractManifest(jsCode);
      final dependencies = <String, String>{};

      if (manifest.isEmpty) return '';

      for (final dep in manifest['dependencies']) {
        final depSource = await _fetchAndEvaluate(dep['url']);
        isValid = depSource.isNotEmpty;
        dependencies[dep['name']] = depSource;
      }
      if (!isValid) return '';

      // Second pass: inject dependencies into the main code
      String finalJsCode = jsCode;
      for (final dep in manifest['dependencies']) {
        final depName = dep['name'];
        final regionTag = '//#region $depName';
        const endRegionTag = '//#endregion';

        if (jsCode.contains(regionTag)) {
          // Find the region and inject the dependency code
          final regionStart = jsCode.indexOf(regionTag) + regionTag.length;
          final regionEnd = jsCode.indexOf(endRegionTag, regionStart);

          if (regionEnd != -1) {
            final beforeRegion = jsCode.substring(0, regionStart);
            final afterRegion = jsCode.substring(regionEnd);
            finalJsCode =
                '$beforeRegion\n${dependencies[depName]}\n$afterRegion';
          } else {
            // Region start found but no end - invalid format
            isValid = false;
            break;
          }
        } else {
          // No region tag found for this dependency - invalid
          isValid = false;
          break;
        }
      }

      if (!isValid) return '';

      // Validate the final code
      if (!flutterJs.evaluate(finalJsCode).isError) {
        return finalJsCode;
      }
      return '';
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return '';
    }
  }

  static Future<void> _executeBackground(String pluginName) async {
    try {
      final context = NavigationManager().context;
      if (_futures[pluginName].isEmpty) {
        _activeJob[pluginName] = null;
        _isProcessingNotifiers[pluginName]!.value = false;
        return;
      }
      _isProcessingNotifiers[pluginName]!.value = true;
      _activeJob[pluginName] = _futures[pluginName].removeAt(0);
      if (!_activeJob[pluginName]['cancel']) {
        _backgroundJobNotifiers[pluginName]!.value =
            _activeJob[pluginName]['id'];
        final jsRuntime = getJsRuntime(pluginName);
        if (jsRuntime == null)
          throw Exception(
            'There was an error executing background job for: $pluginName',
          );
        await jsRuntime.enableFetch();
        await jsRuntime.enableHandlePromises();
        _activeJob[pluginName]['started'] = DateTime.now();
        _activeJob[pluginName]['status'] = 'running';
        JsEvalResult? asyncResult;
        try {
          final promise = await jsRuntime.evaluateAsync(
            _activeJob[pluginName]['code'],
          );
          jsRuntime.executePendingJob();
          asyncResult = await jsRuntime.handlePromise(promise);
        } catch (e, stackTrace) {
          _activeJob[pluginName]['result'] = {
            'message': context.l10n!.runtimeError,
          };
          _activeJob[pluginName]['error'] = true;
          _activeJob[pluginName]['completed'] = DateTime.now();
          _activeJob[pluginName]['status'] = 'failed';
          logger.log(
            'Error in ${stackTrace.getCurrentMethodName()}:',
            e,
            stackTrace,
          );
        }
        if (asyncResult != null) {
          _activeJob[pluginName]['result'] = asyncResult.stringResult;
          _activeJob[pluginName]['error'] = asyncResult.isError;
          _activeJob[pluginName]['completed'] = DateTime.now();
          _activeJob[pluginName]['status'] =
              asyncResult.isError ? 'failed' : 'completed';
          if (asyncResult.isError) {
            logger.log(
              'Error in _executeBackground:',
              '${asyncResult.stringResult} ${_activeJob[pluginName]['code']}',
              null,
            );
            final context = NavigationManager().context;
            showToast('${context.l10n!.jobError}: ${asyncResult.stringResult}');
          }
        }
        jsRuntime.dispose();
      } else {
        _backgroundJobNotifiers[pluginName]!.value =
            _activeJob[pluginName]['id'];
        _activeJob[pluginName]['cancel'] = true;
        _activeJob[pluginName]['completed'] = DateTime.now();
        _activeJob[pluginName]['status'] = 'cancelled';
      }
      if (!_completed.containsKey(pluginName)) _completed[pluginName] = [];
      _completed[pluginName].add(
        Map<String, dynamic>.from(_activeJob[pluginName]),
      );
      _activeJob[pluginName] = null;
      _backgroundJobNotifiers[pluginName]!.value = -1;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
    return unawaited(_executeBackground(pluginName));
  }

  static void queueBackground({
    required String pluginName,
    required String methodName,
    String? message,
    int priority = 0,
    List<dynamic>? args,
  }) {
    try {
      final _plugin = _plugins.firstWhere(
        (value) => value['name'].toLowerCase() == pluginName.toLowerCase(),
        orElse: () => {},
      );
      if (_plugin.isEmpty) return;
      _backgroundJobNotifiers[pluginName]!.value =
          _futures.length + _completed.length + 1;
      if (!_futures.containsKey(pluginName)) _futures[pluginName] = [];
      _futures[pluginName].add({
        'id': _futures.length + _completed.length + 1,
        'code': buildMethodCall(methodName, args),
        'message': message ?? pluginName,
        'plugin': pluginName,
        'priority': priority,
        'status': 'queued',
        'created': DateTime.now(),
        'started': null,
        'completed': null,
        'cancel': false,
        'error': false,
        'result': null,
      });
      _futures[pluginName].sort(
        (a, b) =>
            (int.tryParse(b['priority']) ?? 0) -
            (int.tryParse(a['priority']) ?? 0),
      );
      if (!_isProcessingNotifiers[pluginName]!.value)
        unawaited(_executeBackground(pluginName));
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static Future<Map> getLocalPlugin() async {
    try {
      String jsContent = '';
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['js'],
      );
      if (result != null && result.files.single.path != null) {
        jsContent = await File(result.files.single.path!).readAsString();
        return getPluginData(jsContent);
      }
      return {};
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return {};
    }
  }

  static Future<Map> getOnlinePlugin(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri);
      if (response.statusCode < 400) return getPluginData(response.body);
      return {};
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return {};
    }
  }

  static Future<bool> addPluginData(Map data) async {
    try {
      if (data.isNotEmpty) {
        final flutterJs = getJavascriptRuntime();
        final result = flutterJs.evaluate(data['script']);
        if (!result.isError) {
          removePlugin(data['name']);
          _pluginsCacheData.add(data);
          _plugins.add({'name': data['name'], 'script': data['script']});
          pluginsDataNotifier.value = _pluginsCacheData.length;
          _isProcessingNotifiers[data['name']] = ValueNotifier(false);
          _backgroundJobNotifiers[data['name']] = ValueNotifier(-1);
          _futures[data['name']] = [];
          _completed[data['name']] = [];
          _activeJob[data['name']] = null;
        } else {
          return false;
        }
        return true;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
    return false;
  }

  static void _clearBackgroundJobData(String pluginName) {
    try {
      _isProcessingNotifiers.removeWhere((key, value) => key == pluginName);
      _backgroundJobNotifiers.removeWhere((key, value) => key == pluginName);
      _futures[pluginName] = [];
      _futures.removeWhere((key, value) => key == pluginName);
      _completed[pluginName] = [];
      _completed.removeWhere((key, value) => key == pluginName);
      _activeJob[pluginName] = null;
      _activeJob.removeWhere((key, value) => key == pluginName);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static void removePlugin(String pluginName) {
    try {
      if (_isProcessingNotifiers[pluginName]!.value) {
        final context = NavigationManager().context;
        showToast(
          '${context.l10n!.cannotRemovePlugin} ${context.l10n!.waitForJob}',
        );
        return;
      }
      _clearBackgroundJobData(pluginName);
      _pluginsCacheData.removeWhere((value) => value['name'] == pluginName);
      _plugins.removeWhere((value) => value['name'] == pluginName);
      pluginsDataNotifier.value = _pluginsCacheData.length;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static Future<Map> getPluginData(String jsContent) async {
    try {
      final script = await _loadValidateDependencies(jsContent);
      if (script.isNotEmpty) {
        final (name, _) = PluginsManager._executeMethod(
          script: script,
          methodName: 'pluginName',
        );
        final (version, _) = PluginsManager._executeMethod(
          script: script,
          methodName: 'pluginVersion',
        );
        final manifest = _extractManifest(script);
        if (name != null &&
            !name.isError &&
            version != null &&
            !version.isError) {
          final data = {
            'name': name.stringResult,
            'version': version.stringResult,
            'script': script,
            'manifest': manifest,
            'defaultSettings': manifest['settings'],
            'userSettings': manifest['settings'],
          };
          return data;
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
    return {};
  }

  static void showPluginMethodResult({
    required String pluginName,
    JsEvalResult? result,
    String? message,
  }) {
    try {
      final context = NavigationManager().context;
      if (result == null) {
        showToast('$pluginName: $message ${context.l10n!.failed}.');
        return;
      }
      final jsResult = tryDecode(result.stringResult);
      final text =
          jsResult == null
              ? '$pluginName: ${result.stringResult}'
              : jsResult['message'] == null
              ? message ?? '$pluginName ${context.l10n!.operationPerformed}'
              : '$pluginName: ${jsResult['message']}';
      showToast(text);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static Future<bool> validatePlugin(String jsCode) async {
    try {
      final data = await getPluginData(jsCode);
      return data.isNotEmpty;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return false;
    }
  }

  static String _formatArgument(dynamic arg) {
    try {
      if (arg == null) return 'null';
      if (arg is String) return '"${arg.replaceAll('"', '\\"')}"';
      if (arg is num || arg is bool) return arg.toString();
      if (arg is List) return '[${arg.map(_formatArgument).join(',')}]';
      return jsonEncode(arg).replaceAll(RegExp("'"), "\\'");
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return '';
    }
  }

  static String buildMethodCall(String methodName, List<dynamic>? args) {
    try {
      // Check if methodName already contains arguments (has parentheses with content)
      final hasExistingArgs = RegExp(r'\([^)]+\)').hasMatch(methodName);

      if (hasExistingArgs) {
        return methodName;
      }
      methodName = methodName.ensureBalancedParentheses();
      if (!methodName.checkAllBrackets()) return '';
      if (args == null || args.isEmpty) return methodName;
      final argsString = args.map(_formatArgument).join(',');

      // Handle cases where methodName might have empty parentheses
      if (methodName.endsWith('()')) {
        return methodName.replaceAll('()', "('$argsString')");
      } else {
        return "$methodName('$argsString')";
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return '';
    }
  }

  static List<Widget> getWidgetsByType(
    Function getDataFn,
    String type,
    BuildContext context,
  ) {
    final widgetList = <Widget>[];
    try {
      for (final plugin in _plugins) {
        final result = getWidgets(plugin['name']);
        if (result.isNotEmpty) {
          final widgets =
              result.where((value) => value['type'] == type).toList();
          for (final widget in widgets) {
            widgetList.add(
              WF.getWidget(plugin['name'], widget, context, getDataFn),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
    return widgetList;
  }

  static Widget getPluginSettingsWidgets(
    String pluginName,
    BuildContext context,
  ) {
    try {
      final result = getWidgets(pluginName);
      if (result.isEmpty) return const SizedBox.shrink();
      final widgets =
          result.where((value) => value['context'] == 'settings').toList();
      return LayoutBuilder(
        builder:
            (context, constraints) => Column(
              children: [
                SectionHeader(title: context.l10n!.settings),
                Flexible(
                  flex: 3,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: WF.getAllSettingsWidgets(pluginName, widgets),
                  ),
                ),
                SectionHeader(title: context.l10n!.backgroundJobs),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: getPluginJobList(pluginName),
                  ),
                ),
              ],
            ),
      );
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      throw ErrorDescription('Error in getPluginSettingsWidgets');
    }
  }

  static Widget getPluginJobList(String pluginName) {
    try {
      final items = <Widget>[
        if (_activeJob[pluginName] != null)
          Card(
            child: ListTile(
              title: Text(
                '${_activeJob[pluginName]!['message']} Priority: ${_activeJob[pluginName]!['priority']}',
              ),
              trailing: const SizedBox(
                width: 24,
                height: 24,
                child: Spinner(),
              ), //const Icon(Icons.bolt),
            ),
          ),
        ..._completed[pluginName].map((job) {
          final result = tryDecode(job['result']) ?? {};
          return Card(
            child: ListTile(
              title: Text(
                '${job['message']} Priority: ${job['priority']}, ${result['message']}',
              ),
              trailing: const Icon(FluentIcons.check_24_regular),
            ),
          );
        }),
        ..._futures[pluginName].map(
          (job) => Card(
            child: ListTile(
              title: Text('${job['message']} Priority: ${job['priority']}'),
              trailing: const Icon(FluentIcons.clock_24_regular),
            ),
          ),
        ),
      ];
      return StatefulBuilder(
        builder:
            (context, setState) => ValueListenableBuilder(
              valueListenable: _isProcessingNotifiers[pluginName]!,
              builder:
                  (context, value, __) => ValueListenableBuilder(
                    valueListenable: _backgroundJobNotifiers[pluginName]!,
                    builder:
                        (context, value, __) => ListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: commonListViewBottmomPadding,
                          children:
                              items.isEmpty
                                  ? [
                                    Card(
                                      child: ListTile(
                                        title: Text(
                                          context.l10n!.nothingInQueue,
                                        ),
                                      ),
                                    ),
                                  ]
                                  : items,
                        ),
                  ),
            ),
      );
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      throw ErrorDescription('Error in getPluginJobList');
    }
  }

  static List<Map<String, dynamic>> getWidgets(String pluginName) {
    try {
      final result =
          _pluginsCacheData.firstWhere(
            (value) => value['name'] == pluginName,
            orElse: () => {},
          )['manifest']['widgets'];
      return List<Map<String, dynamic>>.from(result);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return [];
    }
  }

  static Map<String, dynamic> getHooks(String pluginName) {
    try {
      final result =
          _pluginsCacheData.firstWhere(
            (value) => value['name'] == pluginName,
            orElse: () => {},
          )['manifest']['hooks'];
      return Map<String, dynamic>.from(result);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return {};
    }
  }

  static dynamic getUserSettings(String pluginName) {
    try {
      return _pluginsCacheData.firstWhere(
        (value) => value['name'] == pluginName,
        orElse: () => {},
      )['userSettings'];
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return null;
    }
  }

  static JavascriptRuntime? getJsRuntime(String pluginName) {
    try {
      final jsRuntime = getJavascriptRuntime();
      unawaited(jsRuntime.enableFetch());
      unawaited(jsRuntime.enableHandlePromises());
      final script =
          _plugins.firstWhere((value) => value['name'] == pluginName)['script']
              as String;
      final result = jsRuntime.evaluate(script);
      if (result.isError)
        throw Exception(
          'Could not create JavaScript Runtime for: $pluginName. There was an error in the script. ${result.stringResult}',
        );
      _executeMethod(
        methodName:
            'loadSettings(${getDefaultSettings(pluginName)},${getUserSettings(pluginName)})',
        runtime: jsRuntime,
      );
      return jsRuntime;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return null;
    }
  }

  static dynamic getDefaultSettings(String pluginName) {
    try {
      return _pluginsCacheData.firstWhere(
        (value) => value['name'] == pluginName,
        orElse: () => {},
      )['defaultSettings'];
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static void saveSettings(String pluginName) {
    try {
      final (result, _) = _executeMethod(
        pluginName: pluginName,
        methodName: 'pluginSettings',
      );
      if (result == null || result.isError) return;
      final settings = Map<String, dynamic>.from(
        jsonDecode(result.stringResult),
      );
      final userSettings = getUserSettings(pluginName);
      if (userSettings != null) (userSettings as Map).addAll(settings);
      addOrUpdateData('settings', 'pluginsData', pluginsData);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static void restSettings(String pluginName) {
    try {
      final (result, _) = _executeMethod(
        pluginName: pluginName,
        methodName: 'pluginSettings',
      );
      if (result == null || result.isError) return;
      final settings = getDefaultSettings(pluginName);
      final userSettings = getUserSettings(pluginName);
      if (userSettings != null && settings != null) {
        (userSettings as Map).clear();
        userSettings.addAll(settings);
      }
      addOrUpdateData('settings', 'pluginsData', pluginsData);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static dynamic executeMethod({
    required String pluginName,
    required String methodName,
    List<dynamic>? args,
  }) {
    try {
      if (_isProcessingNotifiers[pluginName]!.value) {
        final context = NavigationManager().context;
        showToast(
          '${context.l10n!.cannotRunAction} ${context.l10n!.waitForJob}',
        );
        return;
      }
      if (!_plugins.map((e) => e['name']).contains(pluginName)) return null;
      methodName = methodName.trim();
      final methodCall = buildMethodCall(methodName, args);
      final (result, _) = _executeMethod(
        pluginName: pluginName,
        methodName: methodCall,
      );
      final data = tryDecode(result?.stringResult);
      return data ?? result?.stringResult;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return null;
    }
  }

  static Future<dynamic> executeMethodAsync({
    required String pluginName,
    required String methodName,
    List<dynamic>? args,
    Duration? timeout,
  }) async {
    try {
      if (_isProcessingNotifiers[pluginName]!.value) {
        final context = NavigationManager().context;
        showToast(
          '${context.l10n!.cannotRunAction} ${context.l10n!.waitForJob}',
        );
        return;
      }
      if (!_plugins.map((e) => e['name']).contains(pluginName)) return null;
      methodName = methodName.trim();
      final methodCall = buildMethodCall(methodName, args);
      final jsRuntime = getJsRuntime(pluginName);
      if (jsRuntime == null)
        throw Exception(
          'Invalid JavaScript Runtime for: $pluginName, $methodName',
        );
      await jsRuntime.enableFetch();
      await jsRuntime.enableHandlePromises();
      final promise = await jsRuntime.evaluateAsync(methodCall);
      jsRuntime.executePendingJob();
      final result = await jsRuntime.handlePromise(promise, timeout: timeout);
      final data = tryDecode(result.stringResult);
      return data ?? result.stringResult;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return null;
    }
  }

  static void onEntityLiked(dynamic entity) async {
    if (!pluginsSupport.value || plugins.isEmpty) return;
    for (final plugin in plugins) {
      final hook = getHooks(plugin['name'])['onEntityLiked'];
      queueBackground(
        pluginName: plugin['name'],
        methodName: hook['onTrigger']['methodName'],
        args: [entity],
      );
    }
  }

  static dynamic onGetArtistInfo(dynamic artist) async {
    //TODO implement
    throw UnimplementedError('Not implemented');
  }

  static dynamic onGetSongInfo(dynamic song) async {
    //TODO implement
    throw UnimplementedError('Not implemented');
  }

  static dynamic onGetAlbumInfo(dynamic album) async {
    //TODO implement
    throw UnimplementedError('Not implemented');
  }

  static dynamic onSearch(String query) async {
    //TODO implement
    throw UnimplementedError('Not implemented');
  }

  static dynamic onPlaylistPlay(dynamic playlist) async {
    //TODO implement
    throw UnimplementedError('Not implemented');
  }

  static dynamic onPlaylistSongAdd(String query) async {
    //TODO implement
    throw UnimplementedError('Not implemented');
  }

  static dynamic onPlaylistAdd(String query) async {
    //TODO implement
    throw UnimplementedError('Not implemented');
  }

  static dynamic onQueueSong(String query) async {
    //TODO implement
    throw UnimplementedError('Not implemented');
  }

  static Future<void> getSongUrl(dynamic song, Function fallback) async {
    if (!pluginsSupport.value || plugins.isEmpty) return await fallback(song);
    const timeout = Duration(seconds: 5);
    final allFutures = <Future>[];
    void onSuccess(dynamic result) {
      var songUrl = '';
      //if (result['stream'] != null && result['stream']['error'] == null && result['stream']['liveMP4'] != null) {
      //songUrl = result['stream']['liveMP4']['full'];
      //} else if (result['songUrl'] is String) {
      songUrl = result['songUrl'];
      //}
      song['songUrl'] = songUrl;
      song['isError'] = songUrl.isEmpty;
      song['error'] =
          songUrl.isNotEmpty
              ? null
              : 'Could not find any streams for this song.';
      //song['source'] = null;
      for (final f in allFutures) {
        f.ignore();
      }
    }

    try {
      song['song'] = song['title'];
      if (song['songUrl'] == null || await checkUrl(song['songUrl']) >= 400) {
        song['songUrl'] = null;
        final pluginFutures =
            plugins.fold([], (returnValue, _plugin) {
              final hook = getHooks(_plugin['name'])['onGetSongUrl'];
              if (hook.isNotEmpty) {
                returnValue.add(
                  executeMethodAsync(
                        pluginName: _plugin['name'],
                        methodName: hook['onTrigger']['methodName'],
                        args: [song],
                      )
                      .timeout(
                        timeout,
                        onTimeout: () {
                          fallback(song);
                        },
                      )
                      .then((e) {
                        if (e != null &&
                            e['songUrl'] is String &&
                            e['songUrl'].isNotEmpty) {
                          e['source'] = _plugin['name'];
                          onSuccess(e);
                        }
                      })
                      .catchError((e, stackTrace) {
                        logger.log('Error in $stackTrace:', e, stackTrace);
                        return null;
                      }),
                );
              }
              return returnValue;
            }).toList();
        allFutures.addAll([...pluginFutures]);
        await Future.wait(allFutures).whenComplete(() async {
          if (song['songUrl'] == null || song['songUrl'].isEmpty) {
            await fallback(song);
          }
        });
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      await fallback(song);
    }
  }

  /// Executes a JavaScript method in various contexts with flexible input options.
  ///
  /// This static method provides multiple ways to execute JavaScript code:
  /// - With a direct script string
  /// - Through a registered plugin
  /// - Using an existing JavaScript runtime
  /// - Any combination of the above
  ///
  /// Returns a tuple containing:
  /// 1. The evaluation result (JsEvalResult)
  /// 2. The JavaScript runtime used (JavascriptRuntime)
  ///
  /// All return paths are nullable to handle error cases gracefully.
  ///
  /// Usage Patterns:
  /// 1. Execute standalone script:
  /// ```dart
  ///    executeMethod(script: "function test() { return 42; }", methodName: "test()")
  ///```
  /// 2. Execute plugin method:
  /// ```dart
  ///    executeMethod(pluginName: "mathUtils", methodName: "calculate()")
  ///```
  /// 3. Use existing runtime:
  /// ```dart
  ///    executeMethod(runtime: existingRuntime, methodName: "someMethod()")
  ///```
  /// 4. Combined script + runtime:
  /// ```dart
  ///    executeMethod(runtime: existingRuntime, script: "var x = 10;", methodName: "x")
  ///```
  /// @param script Optional JavaScript code string to evaluate before method execution
  /// @param methodName Required method name to execute (parentheses will be auto-added if missing)
  /// @param pluginName Optional registered plugin name containing preloaded scripts
  /// @param runtime Optional existing JavaScript runtime instance to reuse
  ///
  /// @return Tuple with:
  ///   - First item: Evaluation result (null if execution failed)
  ///   - Second item: JavaScript runtime used (null if initialization failed)
  static (JsEvalResult?, JavascriptRuntime?) _executeMethod({
    String? script,
    String? methodName,
    String? pluginName,
    JavascriptRuntime? runtime,
    List<dynamic>? args,
  }) {
    try {
      if (methodName == null || methodName.isEmpty) return (null, null);
      late final JavascriptRuntime jsRuntime;
      // if only [script] provided
      if (script != null &&
          script.isNotEmpty &&
          (pluginName == null || pluginName.isEmpty) &&
          runtime == null) {
        jsRuntime = getJavascriptRuntime()..evaluate(script);
      } else
      // if only [pluginName] provided
      if ((script == null || script.isEmpty) &&
          pluginName != null &&
          pluginName.isNotEmpty &&
          runtime == null) {
        final _plugin = _plugins.firstWhere(
          (value) => value['name'].toLowerCase() == pluginName.toLowerCase(),
          orElse: () => {},
        );
        if (_plugin.isEmpty) return (null, null);
        final jsrt = getJsRuntime(pluginName);
        if (jsrt == null)
          throw Exception(
            'JavaScript Runtime could nnot be created for: $pluginName, $methodName',
          );
        jsRuntime = jsrt;
      } else
      // if only [runtime] provided
      if ((script == null || script.isEmpty) &&
          (pluginName == null || pluginName.isEmpty) &&
          runtime != null) {
        jsRuntime = runtime;
      } else
      // if [script] and [runtime] provided
      if (script != null &&
          script.isNotEmpty &&
          (pluginName == null || pluginName.isEmpty) &&
          runtime != null) {
        jsRuntime = runtime..evaluate(script);
      }

      methodName = methodName.trim();
      final methodCall = buildMethodCall(methodName, args);

      if (methodCall.isEmpty) return (null, null);

      final result = jsRuntime.evaluate(methodCall);
      return (result, jsRuntime);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return (null, null);
    }
  }

  /// Asynchronously executes a JavaScript method that may return a Promise and resolves it.
  ///
  /// This method builds upon `executeMethod` by adding Promise handling capabilities,
  /// making it suitable for asynchronous JavaScript operations. It automatically:
  /// 1. Enables fetch API support in the runtime
  /// 2. Configures Promise handling
  /// 3. Awaits and resolves any returned Promise
  ///
  /// Usage Patterns:
  /// 1. Execute async script:
  /// ```dart
  ///    await executeMethodAsync(script: "async function fetchData() {...}", methodName: "fetchData()")
  ///```
  /// 2. Call async plugin method:
  /// ```dart
  ///    await executeMethodAsync(pluginName: "apiClient", methodName: "getUser(123)")
  ///```
  /// 3. Use with existing runtime:
  /// ```dart
  ///    await executeMethodAsync(runtime: existingRuntime, methodName: "someAsyncOperation()")
  ///```
  /// @param script Optional JavaScript code string to evaluate before method execution
  /// @param methodName Required method name to execute (parentheses auto-balanced if needed)
  /// @param pluginName Optional registered plugin name containing preloaded scripts
  /// @param runtime Optional existing JavaScript runtime instance to reuse
  ///
  /// @return The resolved value of the JavaScript execution (dynamic type) or null if:
  ///         - Input validation fails
  ///         - Promise resolution fails
  ///         - Any error occurs during execution
  static Future<(dynamic, JavascriptRuntime?)> _executeMethodAsync({
    String? script,
    String? methodName,
    String? pluginName,
    JavascriptRuntime? runtime,
    List<dynamic>? args,
    Duration? timeout,
  }) async {
    try {
      final (jsResult, jsRuntime) = _executeMethod(
        script: script,
        methodName: methodName,
        pluginName: pluginName,
        runtime: runtime,
        args: args,
      );
      if (jsResult == null || jsRuntime == null) return (null, jsRuntime);
      final result = await jsRuntime.handlePromise(jsResult, timeout: timeout);
      return (result, jsRuntime);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return (null, runtime);
    }
  }
}
