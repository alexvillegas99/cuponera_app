import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'image_pick.dart';

/// Argumentos para el isolate de compresión.
class _CompressArgs {
  final Uint8List bytes;
  final int maxDim;
  final int targetBytes;
  final int minQuality;
  const _CompressArgs(
    this.bytes,
    this.maxDim,
    this.targetBytes,
    this.minQuality,
  );
}

/// Algoritmo de compresión (corre en isolate):
/// 1. Decodifica y corrige orientación EXIF.
/// 2. Reescala el lado mayor a [maxDim] px (sin agrandar).
/// 3. Codifica JPEG bajando calidad 85 → piso hasta quedar bajo el objetivo.
/// 4. Si aún supera, reduce dimensión un 20% más y reintenta.
Uint8List _compressIsolate(_CompressArgs a) {
  img.Image? im = img.decodeImage(a.bytes);
  if (im == null) return a.bytes;
  im = img.bakeOrientation(im);

  final longest = im.width > im.height ? im.width : im.height;
  if (longest > a.maxDim) {
    im = im.width >= im.height
        ? img.copyResize(im, width: a.maxDim)
        : img.copyResize(im, height: a.maxDim);
  }

  int q = 85;
  Uint8List out = img.encodeJpg(im, quality: q);
  while (out.length > a.targetBytes && q > a.minQuality) {
    q -= 7;
    out = img.encodeJpg(im, quality: q);
  }

  // Último recurso: bajar resolución una vez más.
  if (out.length > a.targetBytes && im.width > 800) {
    im = img.copyResize(im, width: (im.width * 0.8).round());
    out = img.encodeJpg(im, quality: a.minQuality + 5);
  }
  return out;
}

/// Comprime [bytes] a JPEG por debajo de [targetKB] (default 900 KB ≈ <1 MB),
/// limitando el lado mayor a [maxDim] px. Devuelve los bytes JPEG.
Future<Uint8List> compressImageBytes(
  Uint8List bytes, {
  int maxDim = 1440,
  int targetKB = 900,
  int minQuality = 55,
}) {
  return compute(
    _compressIsolate,
    _CompressArgs(bytes, maxDim, targetKB * 1024, minQuality),
  );
}

/// Igual que [compressImageBytes] pero devuelve un data URL listo para subir.
Future<String> compressToJpegDataUrl(
  Uint8List bytes, {
  int maxDim = 1440,
  int targetKB = 900,
}) async {
  final out = await compressImageBytes(bytes, maxDim: maxDim, targetKB: targetKB);
  return 'data:image/jpeg;base64,${base64Encode(out)}';
}

/// Selecciona + recorta (reusa [pickAndCropImage]) y comprime a <1 MB.
/// Devuelve un data URL JPEG o null si se cancela.
Future<String?> pickCropAndCompress({int maxDim = 1440, int targetKB = 900}) async {
  final dataUrl = await pickAndCropImage();
  if (dataUrl == null) return null;
  final bytes = bytesFromDataUrl(dataUrl);
  if (bytes == null) return null;
  return compressToJpegDataUrl(bytes, maxDim: maxDim, targetKB: targetKB);
}
