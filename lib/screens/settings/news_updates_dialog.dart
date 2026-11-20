import 'package:material_ui/material_ui.dart';

/// News and updates dialog.
class NewsUpdatesDialog extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onFacebookClick;
  final VoidCallback onGithubClick;

  const NewsUpdatesDialog({
    super.key,
    required this.onDismiss,
    required this.onFacebookClick,
    required this.onGithubClick,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign, color: colorScheme.primary, size: 40),
            const SizedBox(height: 12),
            const Text(
              'News & Updates',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Follow our community channels to receive announcements and release logs.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.public, color: colorScheme.primary),
              title: const Text('Facebook Channel'),
              subtitle: const Text('Join our community group'),
              onTap: onFacebookClick,
            ),
            ListTile(
              leading: Icon(Icons.code, color: colorScheme.primary),
              title: const Text('GitHub Developer Profile'),
              subtitle: const Text('Check open-source repositories'),
              onTap: onGithubClick,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onDismiss,
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
