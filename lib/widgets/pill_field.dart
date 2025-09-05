// lib/widgets/pill_field.dart
import 'package:flutter/material.dart';

class PillField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const PillField({
    super.key,
    required this.hint,
    required this.controller,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final Color pill = const Color(0xFFD9E6FF);
    final Color hintColor = const Color(0xFF6B7280);
    final Color textColor = const Color(0xFF111827);

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: pill,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: hintColor),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              validator: validator,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: hintColor),
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              style: TextStyle(color: textColor),
            ),
          ),
          if (onToggleObscure != null)
            IconButton(
              icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: hintColor),
              onPressed: onToggleObscure,
            ),
        ],
      ),
    );
  }
}
