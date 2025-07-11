import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CuponesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> cupones;

  const CuponesScreen({super.key, required this.cupones});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: cupones.length,
        itemBuilder: (context, index) {
          final cupon = cupones[index];
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
              // Parte izquierda con ícono
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
              // Separador
              Container(
                width: 1,
                height: 110,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.grey[300],
              ),
              // Parte derecha con contenido
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
                        'Cupón ${cupon['numero']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF0D47A1),
                        ),
                      ),

                      const SizedBox(height: 6),
                      Text(
                        'Válido del ${cupon['fechaInicio']} al ${cupon['fechaFin']}',
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
                          Text(
                            cupon['usuario']?.toString() ?? 'Desconocido',
                            style: const TextStyle(fontSize: 12),
                          ),
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
                          Text(
                            'Escaneado el ${cupon['fechaEscaneo']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Estado
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
        onPressed: () {
          context.push('/scanner');
        },
        backgroundColor: const Color(0xFF398AE5),
        child: const Icon(Icons.qr_code_scanner, size: 30, color: Colors.white),
      ),
    );
  }
}
