// utilities/constants.dart
import 'package:flutter/material.dart';
import 'package:enjoy/ui/palette.dart';

const TextStyle kLabelStyle = TextStyle(
  color: Palette.kTitle,
  fontFamily: 'OpenSans',
  fontSize: 16,
  fontWeight: FontWeight.w600,
);

const TextStyle kHintTextStyle = TextStyle(
  color: Palette.kMuted,
  fontFamily: 'OpenSans',
);

const BoxDecoration kBoxDecorationStyle = BoxDecoration(
  color: Palette.kField,
  borderRadius: BorderRadius.all(Radius.circular(10)),
  boxShadow: [
    BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
  ],
);
