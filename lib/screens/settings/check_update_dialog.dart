import 'package:material_ui/material_ui.dart';

import '../../services/update_service.dart';
import 'settings_links.dart';

/// In-app Update dialog.
class CheckUpdateDialog extends StatefulWidget {
  final VoidCallback onDismiss;

  const CheckUpdateDialog({super.key, required this.onDismiss});

  @override
  State<CheckUpdateDialog> createState() => _CheckUpdateDialogState();
}

class _CheckUpdateDialogState extends State<CheckUpdateDialog> {
  bool isChecking = true;
  UpdateCheckResult? updateResult;

  @override
  void initState() {
    super.initState();
    _performUpdateCheck();
  }

  Future<void> _performUpdateCheck() async {
    setState(() {
      isChecking = true;
      updateResult = null;
    });

    final result = await UpdateService.checkForUpdate();

    if (mounted) {
      setState(() {
        isChecking = false;
        updateResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isChecking) ...[
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                  strokeWidth: 3.5,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Checking for Updates...',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Connecting to Play Store / App Store...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ] else if (updateResult?.status == UpdateStatus.updateAvailable) ...[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update_alt_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'New Update on ${updateResult?.storeName ?? 'Store'}!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Version v${updateResult?.latestVersion ?? ''} is now available on ${updateResult?.storeName ?? 'the store'}.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Current installed: v${updateResult?.currentVersion ?? '1.0.0'} (Build ${updateResult?.currentBuild ?? 1})',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if ((updateResult?.releaseNotes ?? '').isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "What's New:",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          updateResult!.releaseNotes!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onDismiss,
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(
                        'Update on ${updateResult?.storeName ?? 'Store'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        widget.onDismiss();
                        if (updateResult?.downloadUrl != null) {
                          openUrl(context, updateResult!.downloadUrl!);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ] else if (updateResult?.status == UpdateStatus.error) ...[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  color: colorScheme.onErrorContainer,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Update Check Failed',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                updateResult?.errorMessage ??
                    'Unable to contact ${updateResult?.storeName ?? 'the app store'}. Please check your internet connection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onDismiss,
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      onPressed: _performUpdateCheck,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your App Is Up To Date!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Installed version: v${updateResult?.currentVersion ?? '1.0.0'} (Build ${updateResult?.currentBuild ?? 1})\nNo newer updates found on ${updateResult?.storeName ?? 'app store'}.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: widget.onDismiss,
                  child: const Text('Awesome'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
