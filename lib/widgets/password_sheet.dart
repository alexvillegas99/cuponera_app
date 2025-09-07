import 'package:flutter/material.dart';
import 'package:enjoy/ui/palette.dart';
import 'branded_modal.dart';

Future<String?> showNewPasswordSheet(BuildContext context) {
  final pass1 = TextEditingController();
  final pass2 = TextEditingController();
  bool show1 = false, show2 = false;
  String? error;

  InputDecoration _pillDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Palette.kMuted),
        prefixIcon: const Icon(Icons.lock_outline, color: Palette.kMuted),
        filled: true,
        fillColor: Palette.kField,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Palette.kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Palette.kAccent, width: 1.2),
        ),
      );

  return showBrandedBottomSheet<String>(
    context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setS) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  height: 40, width: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Palette.kPrimary, Palette.kAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.key_rounded, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Nueva contraseña',
                    style: TextStyle(
                      color: Palette.kTitle,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, color: Palette.kMuted),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Text('Escribe tu nueva contraseña', style: TextStyle(color: Palette.kSub)),
            const SizedBox(height: 8),
            TextField(
              controller: pass1,
              obscureText: !show1,
              obscuringCharacter: '•',
              enableSuggestions: false,
              autocorrect: false,
              decoration: _pillDec('Mínimo 6 caracteres').copyWith(
                suffixIcon: IconButton(
                  onPressed: () => setS(() => show1 = !show1),
                  icon: Icon(show1 ? Icons.visibility_off : Icons.visibility, color: Palette.kMuted),
                ),
              ),
            ),
            const SizedBox(height: 12),

            const Text('Repite tu contraseña', style: TextStyle(color: Palette.kSub)),
            const SizedBox(height: 8),
            TextField(
              controller: pass2,
              obscureText: !show2,
              obscuringCharacter: '•',
              enableSuggestions: false,
              autocorrect: false,
              decoration: _pillDec('Debe coincidir').copyWith(
                suffixIcon: IconButton(
                  onPressed: () => setS(() => show2 = !show2),
                  icon: Icon(show2 ? Icons.visibility_off : Icons.visibility, color: Palette.kMuted),
                ),
              ),
            ),

            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: Colors.redAccent)),
            ],

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity, height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Palette.kPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  final p1 = pass1.text.trim();
                  final p2 = pass2.text.trim();
                  if (p1.length < 6) {
                    setS(() => error = 'Usa al menos 6 caracteres.');
                    return;
                  }
                  if (p1 != p2) {
                    setS(() => error = 'Las contraseñas no coinciden.');
                    return;
                  }
                  Navigator.pop(ctx, p1);
                },
                child: const Text('Actualizar contraseña', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      );
    },
  );
}
