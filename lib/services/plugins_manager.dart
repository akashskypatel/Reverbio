/*
 *     Copyright (C) 2025 Akash Patel
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
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/hive_service.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/services/widget_factory.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/notifiable_list.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/section_header.dart';
import 'package:reverbio/widgets/spinner.dart';

typedef WF = WidgetFactory;
typedef PM = PluginsManager;

class PluginsManager {
  PluginsManager._();
  static final NotifiableList<Map<String, dynamic>> _pluginsData =
      NotifiableList<Map<String, dynamic>>.fromHive('settings', 'pluginsData');
  static List testMethods = ['pluginName', 'pluginVersion', 'asyncTest'];
  static NotifiableList<Map<String, dynamic>> get pluginsData => _pluginsData;
  static final NotifiableList<Map<String, dynamic>> _plugins = NotifiableList();
  static final Map _futures = {};
  static final Map _activeJob = {};
  static final Map _completed = {};
  static final Map<String, ValueNotifier<UniqueKey?>> _backgroundJobNotifiers =
      {};
  static final Map<String, ValueNotifier<bool>> _isProcessingNotifiers = {};

  static Map<String, ValueNotifier<bool>> get isProcessing =>
      _isProcessingNotifiers;
  static Map<String, ValueNotifier<UniqueKey?>> get backgroundJobNotifier =>
      _backgroundJobNotifiers;
  static List<Map<String, dynamic>> get plugins => _plugins;

  /// R25 fix: Validate URL for security - must be HTTPS and from allowed domains
  static bool _isValidPluginUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // Must use HTTPS
      if (uri.scheme != 'https') return false;
      // Allowlist: GitHub, GitLab, and common CDN domains
      final allowedHosts = [
        'raw.githubusercontent.com',
        'github.com',
        'gitlab.com',
        'cdn.jsdelivr.net',
        'unpkg.com',
      ];
      return allowedHosts.contains(uri.host.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  static Future<String> _fetchAndEvaluate(String url) async {
    // R25 fix: Validate URL before fetching
    if (!_isValidPluginUrl(url)) {
      logger.log('Invalid plugin URL blocked: $url', null, null);
      return '';
    }
    final flutterJs = getJavascriptRuntime();
    try {
      final response = await http.get(Uri.parse(url));
      // R25 fix: Validate content-type
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (response.statusCode == 200 &&
          (contentType.isEmpty ||
              contentType.contains('text/') ||
              contentType.contains('application/javascript') ||
              contentType.contains('application/json'))) {
        final result = flutterJs.evaluate(response.body);
        if (!result.isError) return response.body;
      }
      return '';
    } catch (e) {
      return '';
    } finally {
      flutterJs.dispose();
    }
  }

  static Future<void> initialize() async {
    await _pluginsData.ensureInitialized();
    await reloadPlugins();
  }

  static Future<bool> syncPlugin(Map<String, dynamic> plugin) async {
    if (_isProcessingNotifiers[plugin['name']]!.value) {
      showToast(
        '${plugin['name']}: ${L10n.current.cannotSyncPlugin}. ${L10n.current.waitForJob}.',
      );
      return false;
    }
    try {
      // R16 fix: Check if plugin exists before accessing
      final foundPlugin = _plugins.where(
        (value) => value['name'] == plugin['name'],
      ).firstOrNull;
      if (foundPlugin == null) {
        logger.log(
          'syncPlugin: Plugin not found - ${plugin['name']}',
          null,
          null,
        );
        return false;
      }
      plugin = foundPlugin;
      final settings = getUserSettings(plugin['name']);
      plugin['settings'] = settings;
      Map<String, dynamic> pluginData = {};
      final source =
          settings['source'] ?? plugin['source'] ?? plugin['originalSource'];
      if (source != null) {
        if (isFilePath(source)) {
          if (Platform.isAndroid || Platform.isIOS) {
            showToast(
              '${L10n.current.cannotReloadLocalPlugin}: ${plugin['name']}',
            );
            return false;
          }
          if (doesFileExist(source)) {
            pluginData = await getLocalPlugin(path: source);
          }
        } else if (await checkUrl(source) < 400) {
          pluginData = await getOnlinePlugin(source);
        }
        if (pluginData.isNotEmpty) {
          final flutterJs = getJavascriptRuntime();
          try {
            await flutterJs.enableFetch();
            await flutterJs.enableHandlePromises();
            final result = flutterJs.evaluate(pluginData['script']);
            if (!result.isError) {
              await addPlugin(pluginData);
              return true;
            }
          } finally {
            flutterJs.dispose();
          }
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

  static Future<void> addPlugin(Map<String, dynamic> plugin) async {
    try {
      removePlugin(plugin['name']);
      _pluginsData.add(plugin);
      _plugins.add(plugin);
      _isProcessingNotifiers[plugin['name']] = ValueNotifier(false);
      _backgroundJobNotifiers[plugin['name']] = ValueNotifier(null);
      _futures[plugin['name']] = [];
      _completed[plugin['name']] = [];
      _activeJob[plugin['name']] = null;
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
      for (final _plugin in _pluginsData) {
        if (_plugins
            .where((value) => value['name'] == _plugin['name'])
            .toList()
            .isEmpty) {
          _plugins.add(_plugin);
          _isProcessingNotifiers[_plugin['name']] = ValueNotifier(false);
          _backgroundJobNotifiers[_plugin['name']] = ValueNotifier(null);
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
    final flutterJs = getJavascriptRuntime();
    try {
      bool isValid = true;
      final manifest = _extractManifest(jsCode);
      final dependencies = <String, String>{};

      if (manifest.isEmpty) return '';

      // R7 fix: Check ALL dependencies, not just the last one
      for (final dep in manifest['dependencies']) {
        final depSource = await _fetchAndEvaluate(dep['url']);
        isValid &= depSource.isNotEmpty;  // Check all dependencies
        dependencies[dep['name']] = depSource;
      }
      if (!isValid) return '';

      // Second pass: inject dependencies into the main code
      String finalJsCode = jsCode;
      for (final dep in manifest['dependencies']) {
        final depName = dep['name'];
        final regionTag = '//#region $depName';
        const endRegionTag = '//#endregion';

        // R6 fix: Use finalJsCode instead of jsCode for subsequent iterations
        if (finalJsCode.contains(regionTag)) {
          // Find the region and inject the dependency code
          final regionStart = finalJsCode.indexOf(regionTag) + regionTag.length;
          final regionEnd = finalJsCode.indexOf(endRegionTag, regionStart);

          if (regionEnd != -1) {
            final beforeRegion = finalJsCode.substring(0, regionStart);
            final afterRegion = finalJsCode.substring(regionEnd);
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
    } finally {
      flutterJs.dispose();
    }
  }

  static Future<void> _executeBackground(String pluginName) async {
    // R20 fix: Replace unbounded recursion with while loop
    while (_futures[pluginName].isNotEmpty) {
      try {
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
              'message': L10n.current.runtimeError,
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
              showToast('${L10n.current.jobError}: ${asyncResult.stringResult}');
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
        _backgroundJobNotifiers[pluginName]!.value = null;
      } catch (e, stackTrace) {
        logger.log(
          'Error in ${stackTrace.getCurrentMethodName()}:',
          e,
          stackTrace,
        );
        break;
      }
    }
    // Exit loop: no more futures
    _activeJob[pluginName] = null;
    _isProcessingNotifiers[pluginName]!.value = false;
    _backgroundJobNotifiers[pluginName]!.value = null;
  }

  static void removeBackgroundJob(String pluginName, Map list, UniqueKey id) {
    try {
      list[pluginName].removeWhere(
        (e) => e['id'] == id && e['status'] != 'running',
      );
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
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
      final key = UniqueKey();
      _backgroundJobNotifiers[pluginName]!.value = key;
      if (!_futures.containsKey(pluginName)) _futures[pluginName] = [];
      _futures[pluginName].add({
        'id': key,
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
      _futures[pluginName].sort((a, b) {
        try {
          return ((b['priority'] as int?) ?? 0) -
              ((a['priority'] as int?) ?? 0);
        } catch (_) {
          return 0;
        }
      });
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

  static Future<Map<String, dynamic>> getLocalPlugin({String? path}) async {
    try {
      String jsContent = '';
      if (path == null || path.isEmpty) {
        path =
            (await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['js'],
            ))?.files.single.path;
        if (path == null || path.isEmpty) return {};
      }
      jsContent = await File(path).readAsString();
      unawaited(clearTempFiles());
      return getPluginData(jsContent, path);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return {};
    }
  }

  static Future<Map<String, dynamic>> getOnlinePlugin(String url) async {
    // R25 fix: Validate URL before fetching
    if (!_isValidPluginUrl(url)) {
      logger.log('Invalid plugin URL blocked: $url', null, null);
      return {};
    }
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri);
      if (response.statusCode < 400) return getPluginData(response.body, url);
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

  static Future<bool> addPluginData(Map<String, dynamic> data) async {
    if (data.isEmpty) return false;
    final flutterJs = getJavascriptRuntime();
    try {
      final result = flutterJs.evaluate(data['script']);
      if (!result.isError) {
        removePlugin(data['name']);
        _pluginsData.add(data);
        _plugins.add(data);
        _isProcessingNotifiers[data['name']] = ValueNotifier(false);
        _backgroundJobNotifiers[data['name']] = ValueNotifier(null);
        _futures[data['name']] = [];
        _completed[data['name']] = [];
        _activeJob[data['name']] = null;
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return false;
    } finally {
      flutterJs.dispose();
    }
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
      if (_isProcessingNotifiers[pluginName]?.value ?? false) {
        showToast(
          '${L10n.current.cannotRemovePlugin} ${L10n.current.waitForJob}',
        );
        return;
      }
      _clearBackgroundJobData(pluginName);
      _pluginsData.removeWhere((value) => value['name'] == pluginName);
      _plugins.removeWhere((value) => value['name'] == pluginName);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static Future<Map<String, dynamic>> getPluginData(
    String jsContent,
    String source,
  ) async {
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
        final manifest = jsonDecode(jsonEncode(_extractManifest(script)));
        if (name != null &&
            !name.isError &&
            version != null &&
            !version.isError) {
          final data = {
            'name': name.stringResult,
            'version': version.stringResult,
            'script': script,
            'manifest': manifest,
            'originalSource': source,
            'source': manifest['settings']['source'] ?? source,
            'defaultSettings': jsonDecode(jsonEncode(manifest['settings'])),
            'userSettings': jsonDecode(jsonEncode(manifest['settings'])),
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

  static void showPluginMethodResult(
    BuildContext context, {
    required String pluginName,
    dynamic result,
    String? message,
  }) {
    try {
      if (result == null) {
        showToast(
          '$pluginName: $message ${L10n.current.failed}.',
          context: context,
        );
        return;
      }
      final text =
          result == null
              ? '$pluginName: $result'
              : result is String
              ? result
              : result['message'] == null
              ? message ?? '$pluginName ${L10n.current.operationPerformed}'
              : '$pluginName: ${result['message']}';
      showToast(text, context: context);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static Future<bool> validatePlugin(String jsCode, String source) async {
    try {
      final data = await getPluginData(jsCode, source);
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
      // R5 fix: _formatArgument already adds proper quotes, don't double-wrap
      final argsString = args.map(_formatArgument).join(',');

      // Handle cases where methodName might have empty parentheses
      if (methodName.endsWith('()')) {
        return methodName.replaceAll('()', "($argsString)");
      } else {
        return "$methodName($argsString)";
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
      if (enablePlugins.value)
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
                SectionHeader(title: L10n.current.settings),
                Flexible(
                  flex: 3,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: WF.getAllSettingsWidgets(
                      pluginName,
                      widgets,
                      context,
                    ),
                  ),
                ),
                SectionHeader(title: L10n.current.backgroundJobs),
                if (_isProcessingNotifiers[pluginName] != null &&
                    _backgroundJobNotifiers[pluginName] != null)
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ValueListenableBuilder(
                        valueListenable: _isProcessingNotifiers[pluginName]!,
                        builder: (context, value, __) {
                          return ValueListenableBuilder(
                            valueListenable:
                                _backgroundJobNotifiers[pluginName]!,
                            builder: (context, value, __) {
                              return getPluginJobList(pluginName, context);
                            },
                          );
                        },
                      ),
                    ),
                  )
                else
                  Card(
                    child: ListTile(title: Text(L10n.current.nothingInQueue)),
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

  static List<Widget> _getJobList(
    String pluginName,
    BuildContext context,
    void Function(void Function()) setState,
  ) {
    return <Widget>[
      if (_activeJob[pluginName] != null)
        Card(
          child: ListTile(
            title: Text(
              '${_activeJob[pluginName]!['message']} Priority: ${_activeJob[pluginName]!['priority']}',
            ),
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: commonBarContentPadding,
                  child: SizedBox.square(dimension: 20, child: Spinner()),
                ),
                IconButton(
                  icon: Icon(size: 24, FluentIcons.dismiss_24_regular),
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      ..._futures[pluginName].map(
        (job) => Card(
          child: ListTile(
            title: Text('${job['message']} Priority: ${job['priority']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: commonBarContentPadding,
                  child: Icon(size: 24, FluentIcons.clock_24_regular),
                ),
                IconButton(
                  icon: const Icon(size: 24, FluentIcons.dismiss_24_regular),
                  onPressed: () {
                    removeBackgroundJob(pluginName, _futures, job['id']);
                    if (context.mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      ..._completed[pluginName].map((job) {
        final result = tryDecode(job['result']) ?? {};
        return Card(
          child: ListTile(
            title: Text(
              '${job['message']} Priority: ${job['priority']}, ${result['message']}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: commonBarContentPadding,
                  child: Icon(size: 24, FluentIcons.checkmark_24_filled),
                ),
                IconButton(
                  icon: const Icon(size: 24, FluentIcons.dismiss_24_regular),
                  onPressed: () {
                    removeBackgroundJob(pluginName, _completed, job['id']);
                    if (context.mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),
        );
      }),
    ];
  }

  static Widget getPluginJobList(String pluginName, BuildContext context) {
    try {
      return StatefulBuilder(
        builder: (context, setState) {
          final items = _getJobList(pluginName, context, setState);
          return ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: commonListViewBottomPadding,
            children:
                items.isEmpty
                    ? [
                      Card(
                        child: ListTile(
                          title: Text(L10n.current.nothingInQueue),
                        ),
                      ),
                    ]
                    : items,
          );
        },
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
          _pluginsData.firstWhere(
            (value) => value['name'] == pluginName,
            orElse: () => {},
          )['manifest']['widgets'];
      final widgets =
          (result as List).map((e) => Map<String, dynamic>.from(e)).toList();
      return widgets;
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
          _pluginsData.firstWhere(
            (value) => value['name'] == pluginName,
            orElse: () => {},
          )['manifest']['hooks'];
      final hooks = Map<String, dynamic>.from(result);
      return hooks;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return {};
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

  static dynamic getUserSettings(String pluginName) {
    try {
      final settings =
          _pluginsData.firstWhere(
            (value) => value['name'] == pluginName,
            orElse: () => {},
          )['userSettings'];
      return settings;
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
      final settings =
          _pluginsData.firstWhere(
            (value) => value['name'] == pluginName,
            orElse: () => {},
          )['defaultSettings'];
      return settings;
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static void setUserSettings(String pluginName, dynamic settings) async {
    try {
      final _plugin = _pluginsData.firstWhere(
        (value) => value['name'] == pluginName,
        orElse: () => {},
      );
      // R14 fix: Check _plugin.isNotEmpty before accessing properties
      if (_plugin.isEmpty) return;
      if (_plugin['userSettings'] == null) _plugin['userSettings'] = {};
      if (_plugin.isNotEmpty && settings != null) {
        _plugin['userSettings'].addAll(settings);
        _pluginsData.updateWhere(_plugin, (e) => e['name'] == pluginName);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static void updateUserSetting(
    String pluginName,
    String key,
    dynamic setting,
  ) {
    try {
      final settings = getUserSettings(pluginName);
      settings[key] = setting;
      setUserSettings(pluginName, settings);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static void saveSettings(String pluginName) async {
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
      setUserSettings(pluginName, userSettings);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static void resetSettings(String pluginName) {
    try {
      final defaultSettings = getDefaultSettings(pluginName);
      final userSettings = getUserSettings(pluginName);
      if (userSettings != null && defaultSettings != null) {
        userSettings.clear();
        userSettings.addAll(defaultSettings);
      }
      setUserSettings(pluginName, userSettings);
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
      if (!_plugins.map((e) => e['name']).contains(pluginName)) return null;
      methodName = methodName.trim();
      final methodCall = buildMethodCall(methodName, args);
      final (result, runtime) = _executeMethod(
        pluginName: pluginName,
        methodName: methodCall,
      );
      final data =
          result?.rawResult is Map
              ? result?.rawResult
              : tryDecode(result?.stringResult);
      runtime?.dispose();
      return data ??
          (result?.stringResult == 'null' ? null : result?.stringResult);
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
      jsRuntime.dispose();
      return data ??
          (result.stringResult == 'null' ? null : result.stringResult);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return null;
    }
  }

  static Future<void> cacheData(
    String pluginName,
    dynamic entity, {
    String? key,
  }) async {
    final entityCacheMap = {
      'song': {'key': 'cachedSongs', 'cache': cachedSongsList},
      'album': {'key': 'cachedAlbums', 'cache': cachedAlbumsList},
      'single': {'key': 'cachedAlbums', 'cache': cachedAlbumsList},
      'ep': {'key': 'cachedAlbums', 'cache': cachedAlbumsList},
      'broadcast': {'key': 'cachedAlbums', 'cache': cachedAlbumsList},
      'other': {'key': 'cachedAlbums', 'cache': cachedAlbumsList},
      'artist': {'key': 'cachedArtists', 'cache': cachedArtistsList},
    };
    try {
      final ids = parseEntityId(entity);
      if (ids.isEmpty)
        throw Exception([
          'cacheData - $pluginName: invalid entity provided',
          entity.toString(),
        ]);
      final type = entity['primary-type']?.toLowerCase() ?? 'unknown';
      final cacheInfo = entityCacheMap[type];
      if (cacheInfo != null) {
        final cacheKey = key ?? cacheInfo['key'] as String? ?? '';
        final cache =
            key != null
                ? Hive.box('cache').get(pluginName, defaultValue: []) as List
                : cacheInfo['cache'] as List<dynamic>;
        if (cacheKey.isEmpty)
          throw Exception([
            'cacheData - $pluginName: could not determine cacheKey for supplied entity',
            entity.toString(),
          ]);
        // R3 fix: Use indexWhere instead of indexOf with closure
        final index = cache.indexWhere(
          (e) => checkEntityId(e['id'], entity['id']),
        );
        if (cache.isEmpty || index < 0)
          cache.add(entity);
        else
          cache[index] = entity;
        await HiveService.addOrUpdateData<List<dynamic>>(
          'cache',
          cacheKey,
          cache,
        );
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static Future<void> triggerHook(dynamic entity, String hookName) async {
    const hooks = {
      'onQueueSong': {'isAsync': true, 'isBackground': false},
      'onEntityLiked': {'isAsync': true, 'isBackground': true},
      'onPlaylistPlay': {'isAsync': true, 'isBackground': true},
      'onPlaylistSongAdd': {'isAsync': true, 'isBackground': true},
      'onPlaylistAdd': {'isAsync': true, 'isBackground': true},
      'onGetArtistInfo': {'isAsync': true, 'isBackground': false},
      'onGetSongInfo': {'isAsync': true, 'isBackground': false},
      'onGetAlbumInfo': {'isAsync': true, 'isBackground': false},
    };
    if (!enablePlugins.value || plugins.isEmpty) return;
    try {
      for (final plugin in plugins) {
        // R1 fix: Check getHooks result before accessing [hookName]
        final pluginHooks = getHooks(plugin['name']);
        if (pluginHooks.isEmpty) continue;
        final hook = pluginHooks[hookName];
        // R1 fix: Check hook null/empty before dereferencing
        if (hook == null || hook.isEmpty) continue;
        final methodName = hook['onTrigger']?['methodName'];
        if (methodName == null || methodName.isEmpty)
          continue;
        if (hooks[hookName]!['isBackground']!) {
          queueBackground(
            pluginName: plugin['name'],
            methodName: methodName,
            args: [entity],
          );
          continue;
        }
        final result =
            hooks[hookName]!['isAsync']!
                ? await executeMethodAsync(
                  pluginName: plugin['name'],
                  methodName: hook['onTrigger']['methodName'],
                  args: [entity],
                )
                : executeMethod(
                  pluginName: plugin['name'],
                  methodName: hook['onTrigger']['methodName'],
                  args: [entity],
                );
        if (result is List) {
          if (entity is List) {
            entity = result;
            for (final e in entity) {
              await cacheData(plugin['name'], e, key: e['cacheKey']);
            }
            continue;
          } else if (entity is Map) {
            entity[plugin['name']][hookName] = result;
            await cacheData(plugin['name'], entity, key: entity['cacheKey']);
            continue;
          }
        }
        if (result is Map) {
          if (entity is Map) {
            // R2 fix: Merge result into entity, not self-merge
            entity.addAll(result);
            await cacheData(plugin['name'], entity, key: entity['cacheKey']);
            continue;
          } else if (entity is List) {
            for (final e in entity) {
              e[plugin['name']][hookName] = result;
              await cacheData(plugin['name'], e, key: e['cacheKey']);
              continue;
            }
          }
        }
        if (result is String) {
          showToast('${plugin['name']} - $methodName: $result');
          continue;
        }
        if (result == null) continue;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
  }

  static Future<String?> getSongUrl(
    Map song,
    Future<String> Function(dynamic) fallback,
  ) async {
    if (!enablePlugins.value || plugins.isEmpty) {
      return fallback(song);
    }
    const timeout = Duration(seconds: 10);
    final allFutures = <Future>[];
    final resultCompleter = Completer<String?>();
    String onSuccess(dynamic result) {
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
      return songUrl;
    }

    try {
      song['song'] = song['title'];
      if (song['songUrl'] == null || await checkUrl(song['songUrl']) >= 400) {
        song['songUrl'] = null;
        final pluginFutures =
            plugins.fold([], (returnValue, _plugin) {
              // R13 fix: Check hook null/empty before accessing isNotEmpty
              final hook = getHooks(_plugin['name'])['onGetSongUrl'];
              if (hook != null && hook.isNotEmpty) {
                returnValue.add(
                  executeMethodAsync(
                        pluginName: _plugin['name'],
                        methodName: hook['onTrigger']['methodName'],
                        args: [song],
                      )
                      .timeout(
                        timeout,
                        onTimeout: () {
                          return fallback(song);
                        },
                      )
                      .then((e) {
                        if (e != null &&
                            e['songUrl'] is String &&
                            e['songUrl'].isNotEmpty) {
                          e['source'] = _plugin['name'];
                          if (!resultCompleter.isCompleted) {
                            resultCompleter.complete(onSuccess(e));
                          }
                        }
                        return e;
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
        
        // R12 fix: Wait for first successful result instead of just first result
        if (allFutures.isNotEmpty) {
          await Future.wait(allFutures);
          if (resultCompleter.isCompleted) {
            return resultCompleter.future;
          }
        }
        /*
        .then((value) async {
          if (song['songUrl'] == null || song['songUrl'].isEmpty) {
            return [fallback(song)];
          }
        });
        */
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
    return fallback(song);
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
            'JavaScript Runtime could not be created for: $pluginName, $methodName',
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
      } else {
        // R4 fix: Fallback for unmatched branches - create new runtime
        jsRuntime = getJavascriptRuntime();
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
