import 'package:flutter/material.dart';
import 'components.dart'; // Ensure this points to your AppColors definition

enum SnackbarType { info, success, error, warning }

class CyberSnackbar {
  static void show(
    BuildContext context, 
    String message, {
    SnackbarType type = SnackbarType.info,
    int durationSeconds = 3,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    // 1. Determine Colors & Icons based on Type
    Color accentColor;
    IconData icon;
    
    switch (type) {
      case SnackbarType.success:
        accentColor = AppColors.signalGreen;
        icon = Icons.check_circle_outline;
        break;
      case SnackbarType.error:
        accentColor = AppColors.signalRed;
        icon = Icons.error_outline;
        break;
      case SnackbarType.warning:
        accentColor = Colors.amberAccent;
        icon = Icons.warning_amber_rounded;
        break;
      case SnackbarType.info:
      default:
        accentColor = AppColors.neonBlue;
        icon = Icons.info_outline;
        break;
    }

    // 2. Clear previous snacks to prevent stacking
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // 3. Show the Custom SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: durationSeconds),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // Deep matte grey/black
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              // Subtle Neon Glow for the whole card
              BoxShadow(
                color: accentColor.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Row(
            children: [
              // A. Neon Status Bar (Left Side)
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(color: accentColor.withOpacity(0.6), blurRadius: 6, spreadRadius: 0)
                  ]
                ),
              ),
              const SizedBox(width: 16),

              // B. Icon
              Icon(icon, color: accentColor, size: 24),
              const SizedBox(width: 12),

              // C. Message
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // D. Optional Action Button
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onAction();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}