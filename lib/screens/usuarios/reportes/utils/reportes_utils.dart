import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:share_plus/share_plus.dart';

String fmtN(num? n) {
  if (n == null) return '0';
  return NumberFormat('#,###', 'es_EC').format(n);
}

String fmtMoney(num? n) {
  if (n == null) return '\$0.00';
  return '\$${NumberFormat('#,##0.00', 'es_EC').format(n)}';
}

String fmtPct(num? n, {int digits = 1}) {
  if (n == null) return '0%';
  return '${(n * 100).toStringAsFixed(digits)}%';
}

String haceDiasISO(int dias) {
  final d = DateTime.now().subtract(Duration(days: dias));
  return DateFormat('yyyy-MM-dd').format(d);
}

String hoyISO() => DateFormat('yyyy-MM-dd').format(DateTime.now());

String _csvEscape(dynamic v) {
  if (v == null) return '';
  final s = v.toString().replaceAll('"', '""');
  if (RegExp(r'[",\n;]').hasMatch(s)) return '"$s"';
  return s;
}

/// Genera CSV y lo comparte (Share sheet del sistema).
Future<void> shareCsv(
  String filename,
  List<Map<String, dynamic>> rows,
  List<({String key, String label})> cols,
) async {
  if (rows.isEmpty) return;
  final head = cols.map((c) => _csvEscape(c.label)).join(',');
  final body = rows
      .map((r) => cols.map((c) => _csvEscape(r[c.key])).join(','))
      .join('\n');
  final csv = '﻿$head\n$body';

  // Guardamos a archivo temporal y compartimos
  try {
    final dir = await pp.getTemporaryDirectory();
    final f = File('${dir.path}/$filename.csv');
    await f.writeAsBytes(
      Uint8List.fromList(csv.codeUnits),
      flush: true,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(f.path)],
        subject: filename,
      ),
    );
  } catch (_) {
    // Fallback: compartir solo texto
    await SharePlus.instance.share(ShareParams(text: csv, subject: filename));
  }
}
