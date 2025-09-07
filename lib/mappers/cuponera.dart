// lib/mappers/cuponera.dart
import 'package:flutter/foundation.dart';

class ScanRecord {
  final DateTime fecha;
  final String local;
  final String ciudad;
  final String usuario;

  ScanRecord({
    required this.fecha,
    required this.local,
    required this.ciudad,
    required this.usuario,
  });

  factory ScanRecord.fromJson(Map<String, dynamic> j) {
    // Soporta tanto "fecha" como "fechaEscaneo"
    final rawFecha = j['fecha'] ?? j['fechaEscaneo'];
    final parsed = DateTime.tryParse(rawFecha?.toString() ?? '');
    return ScanRecord(
      fecha: parsed ?? DateTime.now(),
      local: (j['local'] ?? '') as String,
      ciudad: (j['ciudad'] ?? '') as String,
      usuario: (j['usuario'] ?? '') as String,
    );
  }
}

class Cuponera {
  final String id;
  final String nombre;
  final String descripcion;
  final String codigo;        // lo usas arriba, también como qrData
  final DateTime emitidaEl;
  final DateTime? expiraEl;
  final String qrData;
  final int totalEscaneos;
  final DateTime? lastScanAt; // soporta ultimoScaneo/lastScanAt
  final List<ScanRecord> scans;
  final String secuencial;

  Cuponera({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.codigo,
    required this.emitidaEl,
    required this.expiraEl,
    required this.qrData,
    required this.totalEscaneos,
    required this.lastScanAt,
    required this.scans,
    required this.secuencial,

  });

  factory Cuponera.fromJson(Map<String, dynamic> j) {
    final id = (j['_id'] ?? j['id'] ?? '').toString();
    final emitida = DateTime.tryParse(j['emitidaEl']?.toString() ?? '');
    final expira = j['expiraEl'] != null
        ? DateTime.tryParse(j['expiraEl'].toString())
        : null;

    // Soporta "ultimoScaneo" (tu respuesta actual) o "lastScanAt" (si cambias luego)
    final lastScanRaw = j['ultimoScaneo'] ?? j['lastScanAt'];
    final lastScanAt = lastScanRaw != null
        ? DateTime.tryParse(lastScanRaw.toString())
        : null;

    // Si no mandas historial todavía, ‘scans’ llegará vacío y no pasa nada
    final scansList = (j['scans'] as List?) ?? const [];
    final scans = scansList
        .whereType<Map<String, dynamic>>()
        .map(ScanRecord.fromJson)
        .toList();
        final secuencial = (j['secuencial']  ?? '').toString();

    return Cuponera(
      id: id,
      nombre: (j['nombre'] ?? '') as String,
      descripcion: (j['descripcion'] ?? '') as String,
      codigo: (j['codigo'] ?? id) as String,
      emitidaEl: emitida ?? DateTime.now(),
      expiraEl: expira,
      qrData: (j['qrData'] ?? (j['codigo'] ?? id)).toString(),
      totalEscaneos: (j['totalEscaneos'] is num) ? (j['totalEscaneos'] as num).toInt() : 0,
      lastScanAt: lastScanAt,
      scans: scans,
      secuencial:secuencial
    );
  }
}
