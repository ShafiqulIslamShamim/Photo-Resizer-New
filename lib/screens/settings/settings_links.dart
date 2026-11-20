import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a URL in an external browser.
Future<void> openUrl(BuildContext context, String urlString) async {
  try {
    final uri = Uri.parse(urlString);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        _showMessage(context, 'Could not open link');
      }
    }
  } catch (_) {
    if (context.mounted) {
      _showMessage(context, 'Could not open link');
    }
  }
}

/// Opens an email client.
Future<void> openEmail(BuildContext context, String toEmail) async {
  const String appName = 'Encryptor';
  String versionName = '1.0';
  String versionCode = '1';

  try {
    final packageInfo = await PackageInfo.fromPlatform();
    versionName = packageInfo.version;
    versionCode = packageInfo.buildNumber;
  } catch (_) {}

  final subject = 'Feedback - $appName v$versionName (Code: $versionCode)';

  final emailUri = Uri(
    scheme: 'mailto',
    path: toEmail,
    queryParameters: {'subject': subject},
  );

  try {
    if (!await launchUrl(emailUri)) {
      if (context.mounted) {
        _showMessage(context, 'No email client application found');
      }
    }
  } catch (_) {
    if (context.mounted) {
      _showMessage(context, 'No email client application found');
    }
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}
