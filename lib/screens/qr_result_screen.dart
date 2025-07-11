import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class QrResultScreen extends StatelessWidget {
  final Map<String, dynamic> qrData;

  const QrResultScreen({super.key, required this.qrData});

  bool get esValido {
    final hoy = DateTime.now();
    final fechaFin = DateTime.tryParse(qrData['fechaFin'] ?? '');
    if (fechaFin == null) return false;
    return hoy.isBefore(fechaFin.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFF4F1DE)),
        title: const Text(
          'Resultado del QR',
          style: TextStyle(color: Color(0xFFF4F1DE)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_2, size: 60, color: Color(0xFF398AE5)),
                const SizedBox(height: 12),
                Text(
                  'Cupón Nº ${qrData['numero']}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(height: 20),
                _infoTile(Icons.date_range, 'Inicio', qrData['fechaInicio']),
                _infoTile(Icons.event, 'Fin', qrData['fechaFin']),
                const SizedBox(height: 12),

                // Estado
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: esValido ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: esValido ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        esValido ? Icons.check_circle : Icons.cancel,
                        color: esValido ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        esValido ? 'Cupón válido' : 'Cupón vencido',
                        style: TextStyle(
                          color: esValido ? Colors.green[800] : Colors.red[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Botón para invalidar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: lógica para invalidar cupón
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cupón invalidado'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      context.go('/home');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    label: const Text(
                      'Invalidar cupón',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF398AE5), size: 20),
          const SizedBox(width: 10),
          Text(
            "$label:",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D1B2A),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
