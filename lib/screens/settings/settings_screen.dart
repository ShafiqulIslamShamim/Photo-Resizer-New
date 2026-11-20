import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../controllers/theme_controller.dart';
import 'check_update_dialog.dart';
import 'news_updates_dialog.dart';
import 'settings_links.dart';
import 'settings_tiles.dart';
import 'style_settings_view.dart';

/// Main settings entry point.
class SettingsScreen extends StatelessWidget {
  final ThemeController themeController;

  const SettingsScreen({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) {
    return MainSettingsView(themeController: themeController);
  }
}

/// Main settings screen.
class MainSettingsView extends StatefulWidget {
  final ThemeController themeController;

  const MainSettingsView({super.key, required this.themeController});

  @override
  State<MainSettingsView> createState() => _MainSettingsViewState();
}

class _MainSettingsViewState extends State<MainSettingsView> {
  String appVersion = '1.0';

  bool showNewsDialog = false;
  bool showUpdateDialog = false;

  @override
  void initState() {
    super.initState();
    _getAppVersion();
  }

  Future<void> _getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();

      if (mounted) {
        setState(() {
          appVersion = info.version.isNotEmpty ? info.version : '1.0';
        });
      }
    } catch (_) {}
  }

  void _openStyleSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StyleSettingsView(themeController: widget.themeController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 4),

              const SectionTitle(title: 'Appearance'),

              SettingsSection(
                children: [
                  SettingItem(
                    headlineText: 'Style',
                    supportingText: 'Theme mode • Color palette • AMOLED',
                    leadingContent: const Icon(Icons.palette),
                    trailingContent: const Icon(Icons.keyboard_arrow_right),
                    onTap: _openStyleSettings,
                  ),
                ],
              ),

              const SettingsSectionDivider(),

              const SectionTitle(title: 'About'),

              SettingsSection(
                children: [
                  SettingItem(
                    headlineText: 'Developed by',
                    supportingText: 'Shafiqul Islam Shamim',
                    leadingContent: const Icon(Icons.person),
                    trailingContent: const Icon(Icons.keyboard_arrow_right),
                    onTap: () => openUrl(context, 'https://t.me/md_shamim12'),
                  ),

                  const SettingsSectionDivider(),

                  SettingItem(
                    headlineText: 'News & Updates',
                    supportingText: 'Follow Facebook and GitHub channels',
                    leadingContent: const Icon(Icons.campaign),
                    trailingContent: const Icon(Icons.keyboard_arrow_right),
                    onTap: () {
                      setState(() {
                        showNewsDialog = true;
                      });
                    },
                  ),

                  const SettingsSectionDivider(),

                  SettingItem(
                    headlineText: 'Check for updates',
                    supportingText:
                        'Check for updates on Play Store / App Store',
                    leadingContent: const Icon(Icons.system_update),
                    trailingContent: const Icon(Icons.keyboard_arrow_right),
                    onTap: () {
                      setState(() {
                        showUpdateDialog = true;
                      });
                    },
                  ),

                  const SettingsSectionDivider(),

                  SettingItem(
                    headlineText: 'Version',
                    supportingText: appVersion,
                    leadingContent: const Icon(Icons.info),
                  ),

                  const SettingsSectionDivider(),

                  SettingItem(
                    headlineText: 'Privacy policy',
                    supportingText: 'Privacy policy • Terms & conditions',
                    leadingContent: const Icon(Icons.privacy_tip),
                    trailingContent: const Icon(Icons.keyboard_arrow_right),
                    onTap: () => openUrl(
                      context,
                      'https://github.com/ShafiqulIslamShamim/Land-Measurement/blob/main/PrivacyPolicy.txt',
                    ),
                  ),
                ],
              ),

              const SettingsSectionDivider(),

              const SectionTitle(title: 'Support'),

              SettingsSection(
                children: [
                  SettingItem(
                    headlineText: 'Rate us',
                    supportingText: 'Every star makes us better',
                    leadingContent: const Icon(Icons.star),
                    trailingContent: const Icon(Icons.keyboard_arrow_right),
                    onTap: () => openUrl(
                      context,
                      'https://play.google.com/store/apps/details?id=com.shamim.landmeasurement',
                    ),
                  ),

                  const SettingsSectionDivider(),

                  SettingItem(
                    headlineText: 'Try more apps',
                    supportingText: 'Try more amazing apps from us',
                    leadingContent: const Icon(Icons.shop),
                    trailingContent: const Icon(Icons.keyboard_arrow_right),
                    onTap: () => openUrl(
                      context,
                      'https://play.google.com/store/search?q=pub:Shafiqul%20Islam%20Shamim&c=apps',
                    ),
                  ),

                  const SettingsSectionDivider(),

                  SettingItem(
                    headlineText: 'Feedback',
                    supportingText: 'Tell us how we can improve',
                    leadingContent: const Icon(Icons.feedback),
                    trailingContent: const Icon(Icons.keyboard_arrow_right),
                    onTap: () => openEmail(
                      context,
                      'shafiqulislamshamimofficial@gmail.com',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),

          if (showNewsDialog)
            NewsUpdatesDialog(
              onDismiss: () {
                setState(() {
                  showNewsDialog = false;
                });
              },
              onFacebookClick: () => openUrl(
                context,
                'https://www.facebook.com/share/18wbmDDERe/',
              ),
              onGithubClick: () =>
                  openUrl(context, 'https://github.com/ShafiqulIslamShamim/'),
            ),

          if (showUpdateDialog)
            CheckUpdateDialog(
              onDismiss: () {
                setState(() {
                  showUpdateDialog = false;
                });
              },
            ),
        ],
      ),
    );
  }
}
