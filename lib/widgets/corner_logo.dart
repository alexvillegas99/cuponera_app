import 'package:flutter/material.dart';

class CornerLogo extends StatelessWidget {
  final String url;
  const CornerLogo({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.9),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: Colors.white,
            child: Icon(
              Icons.store_mall_directory_outlined,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}
