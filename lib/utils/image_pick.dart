import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:enjoy/ui/palette.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Selecciona una imagen de la galería, la recorta (aspecto libre) y devuelve
/// el data URL base64 (`data:image/jpeg;base64,...`) o null si se cancela.
Future<String?> pickAndCropImage() async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 90,
  );
  if (file == null) return null;

  final cropped = await ImageCropper().cropImage(
    sourcePath: file.path,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Recortar',
        toolbarColor: Palette.kTitle,
        toolbarWidgetColor: Colors.white,
        lockAspectRatio: false,
        hideBottomControls: false,
      ),
      IOSUiSettings(
        title: 'Recortar',
        aspectRatioLockEnabled: false,
        resetAspectRatioEnabled: true,
      ),
    ],
  );
  if (cropped == null) return null;

  final path = cropped.path;
  final bytes = await File(path).readAsBytes();
  final mime = path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

/// Decodifica los bytes de un data URL base64 para previsualizar con Image.memory.
/// Devuelve null si la cadena no es un data URL válido.
Uint8List? bytesFromDataUrl(String? dataUrl) {
  if (dataUrl == null) return null;
  final idx = dataUrl.indexOf('base64,');
  if (idx < 0) return null;
  try {
    return base64Decode(dataUrl.substring(idx + 7));
  } catch (_) {
    return null;
  }
}
