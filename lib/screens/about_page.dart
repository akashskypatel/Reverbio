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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/API/version.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, required this.navigatorObserver});
  final RouteObserver<PageRoute> navigatorObserver;

  @override
  _AboutPageState createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to the RouteObserver
    final route = ModalRoute.of(context);
    if (route != null) {
      widget.navigatorObserver.subscribe(this, route as PageRoute);
    }
  }

  @override
  void dispose() {
    widget.navigatorObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.about)),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Text(
                'Reverbio  | $appVersion',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'paytoneOne',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(color: Colors.white24, thickness: 0.8, height: 20),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(8),
                leading: Container(
                  height: 50,
                  width: 50,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      fit: BoxFit.fill,
                      image: NetworkImage(
                        'https://avatars.githubusercontent.com/u/8129618?s=96&v=4',
                      ),
                    ),
                  ),
                ),
                title: const Text(
                  'Akash Patel',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Software & Game Developer'),
                trailing: Wrap(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(FluentIcons.code_24_filled),
                      iconSize: pageHeaderIconSize,
                      tooltip: 'Github',
                      onPressed: () {
                        launchURL(
                          Uri.parse('https://github.com/akashskypatel'),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.globe_24_filled),
                      iconSize: pageHeaderIconSize,
                      tooltip: 'Website',
                      onPressed: () {
                        launchURL(Uri.parse('https://fryingpan.games/'));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
