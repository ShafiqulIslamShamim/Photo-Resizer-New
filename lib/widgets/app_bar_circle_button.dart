import 'package:flutter/material.dart';

/// Circular icon button used as a leading/trailing AppBar action.
///
/// Shared by the Configure and Preview screens so their app bars stay visually
/// identical and can be updated in one place.
class AppBarCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final Key? buttonKey;

  const AppBarCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.colorScheme,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: CircleAvatar(
        backgroundColor: colorScheme.surface,
        child: IconButton(
          key: buttonKey,
          tooltip: tooltip,
          icon: Icon(icon, color: colorScheme.primary),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
