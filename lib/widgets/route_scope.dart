import 'package:material_ui/material_ui.dart';

import '../controllers/photo_controller.dart';

/// Common chrome for routes: loading spinner, out-of-memory dialog,
/// and SnackBar notifications.
class RouteScope extends StatefulWidget {
  final PhotoController controller;
  final Widget child;

  const RouteScope({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<RouteScope> createState() => _RouteScopeState();
}

class _RouteScopeState extends State<RouteScope> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void didUpdateWidget(RouteScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChange);
      widget.controller.addListener(_onControllerChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    final message = widget.controller.transientMessage;
    if (message != null) {
      widget.controller.clearTransientMessage();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Stack(
          children: [
            widget.child,
            if (widget.controller.oomDialogMessage != null)
              Center(
                child: AlertDialog(
                  icon: Icon(
                    Icons.warning,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: const Text(
                    'Device Memory Limit Reached',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  content: Text(
                    widget.controller.oomDialogMessage!,
                    style: const TextStyle(fontSize: 14),
                  ),
                  actions: [
                    TextButton(
                      onPressed: widget.controller.dismissOomDialog,
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
            if (widget.controller.loading) _loadingOverlay(context),
          ],
        );
      },
    );
  }

  Widget _loadingOverlay(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: Card(
              color: colors.surface,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(color: colors.primary),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Optimizing Image Quality',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Running direct iterations to target exact limits.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
