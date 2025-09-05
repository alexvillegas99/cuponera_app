// utilities/constants.dart
import 'package:flutter/material.dart';

const TextStyle kLabelStyle = TextStyle(
  color: Colors.white,
  fontFamily: 'OpenSans',
  fontSize: 16,
  fontWeight: FontWeight.w600,
);

const TextStyle kHintTextStyle = TextStyle(
  color: Colors.white70,
  fontFamily: 'OpenSans',
);

const BoxDecoration kBoxDecorationStyle = BoxDecoration(
  color: Color(0x33000000),
  borderRadius: BorderRadius.all(Radius.circular(10)),
  boxShadow: [
    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
  ],
);
