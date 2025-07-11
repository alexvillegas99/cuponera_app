import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class CuponesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> cupones;

  const CuponesScreen({super.key, required this.cupones});

  String formatearFecha(String fechaIso) {
    final fecha = DateTime.tryParse(fechaIso);
    if (fecha == null) return 'Fecha inválida';
    return DateFormat('dd/MM/yyyy hh:mm a', 'es').format(fecha);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: cupones.length,
        itemBuilder: (context, index) {
          final cupon = cupones[index];

          final secuencial = cupon['cupon']?['secuencial'] ?? 'N/A';
          final fechaInicio = cupon['cupon']?['fechaActivacion'] ?? '';
          final fechaFin = cupon['cupon']?['fechaVencimiento'] ?? '';
          final usuario = cupon['usuario']?['nombre'] ?? 'Desconocido';
          final fechaEscaneo = cupon['fechaEscaneo'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 130,
                  decoration: const BoxDecoration(
                    color: Color(0xFF398AE5),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.local_offer_outlined,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: Colors.grey[300],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cupón #$secuencial',
                          style: const TextStyle( 
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Válido del ${formatearFecha(fechaInicio)} al ${formatearFecha(fechaFin)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(usuario, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              // 👈 Esto fuerza al texto a ocupar el espacio restante sin desbordarse
                              child: Text(
                                'Escaneado el ${formatearFecha(fechaEscaneo)}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow
                                    .ellipsis, // opcional: corta si es demasiado largo
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: const Icon(Icons.check_circle, color: Colors.green),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/scanner'),
        backgroundColor: const Color(0xFF398AE5),
        child: const Icon(Icons.qr_code_scanner, size: 30, color: Colors.white),
      ),
    );
  }
}
