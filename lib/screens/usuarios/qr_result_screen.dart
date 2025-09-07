import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/historico_cupon_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class QrResultScreen extends StatelessWidget {
  final Map<String, dynamic> qrData;

  const QrResultScreen({super.key, required this.qrData});

  @override
  Widget build(BuildContext context) {
    final bool valido = qrData['valido'] == true;
    final fechaInicio = _formatearFecha(qrData['fechaActivacion']);
    final fechaFin = _formatearFecha(qrData['fechaVencimiento']);
    final numero = qrData['secuencial'] ?? '—';
    final version = qrData['version']?['nombre'] ?? '—';
    final activador = qrData['usuarioActivador']?['nombre'] ?? '—';
    final estado = qrData['valido'] == true ? 'activo' : 'inactivo';
    final esActivo = qrData['valido'];

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
                  'Cupón Nº $numero',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(height: 20),
                _infoTile(Icons.date_range, 'Inicio', fechaInicio),
                _infoTile(Icons.event, 'Fin', fechaFin),
                _infoTile(Icons.verified, 'Estado', estado),

                _infoTile(Icons.bookmark, 'Versión', version),
                const SizedBox(height: 12),

                // Estado visual
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: valido ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: valido ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        valido ? Icons.check_circle : Icons.cancel,
                        color: valido ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        qrData['message'] ??
                            (valido ? 'Cupón válido' : 'Cupón no válido'),
                        style: TextStyle(
                          color: valido ? Colors.green[800] : Colors.red[800],
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
                    onPressed: () async {
  if (esActivo) {
    // 🔵 Mostrar diálogo "Realizando registro…"
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Realizando registro…',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );

    try {
      final historicoService = HistoricoCuponService();
      final authService = AuthService();
      final usuario = await authService.getUser();

      final cuponId = qrData['_id'];
      final usuarioId = usuario?['_id'];

      await historicoService.registrarEscaneo({
        'cupon': cuponId,
        'usuario': usuarioId,
      });

      if (!context.mounted) return;
      Navigator.of(context).pop(); // 🔻 cerrar diálogo

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cupón registrado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true); // ✅ devolver éxito
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // 🔻 cerrar diálogo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar cupón: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } else {
    // coherente con el flujo de resultado
    Navigator.of(context).pop(false);
  }
},


                    style: ElevatedButton.styleFrom(
                      backgroundColor: esActivo
                          ? Colors.green[700]
                          : Colors.red[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      esActivo ? Icons.check_circle : Icons.arrow_back,
                      color: Colors.white,
                    ),
                    label: Text(
                      esActivo ? 'Registrar cupón' : 'Regresar',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              maxLines: 2,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}
