import 'package:flutter/material.dart';
import 'package:enjoy/ui/enjoy_colors.dart';

/// ---------- D I Á L O G O  (AlertDialog) ----------
Future<void> showBrandedDialog(
  BuildContext context, {
  required String title,
  required String message,
  String primaryText = 'OK',
  VoidCallback? onPrimary,
  String? secondaryText,
  VoidCallback? onSecondary,
  IconData icon = Icons.info_outline,
}) {
  return showDialog(
    context: context,
    barrierDismissible: secondaryText != null, // cierra tocando fuera si hay cancelar
    builder: (_) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: context.ec.surfaceTop,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: context.ec.stroke),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header icon con gradiente
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [context.ec.secondaryDeep, context.ec.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.ec.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.ec.textSoft, height: 1.35),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (secondaryText != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.ec.text,
                          side: BorderSide(color: context.ec.stroke),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          onSecondary?.call();
                        },
                        child: Text(secondaryText),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: context.ec.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onPrimary?.call();
                      },
                      child: Text(primaryText, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// ---------- B O T T O M   S H E E T  (sheet genérico) ----------
Future<T?> showBrandedBottomSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext ctx) builder,
  double? maxWidth,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: context.ec.surfaceTop,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      side: BorderSide(color: context.ec.stroke),
    ),
    builder: (ctx) {
      final insets = MediaQuery.of(ctx).viewInsets;
      final content = builder(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: insets.bottom),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth ?? 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44, height: 4,
                    decoration: BoxDecoration(
                      color: context.ec.stroke,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  content,
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
