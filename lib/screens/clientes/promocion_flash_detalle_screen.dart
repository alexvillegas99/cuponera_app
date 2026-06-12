import 'package:enjoy/services/promociones_flash_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'promociones_flash_screen.dart' show cuentaFlash;

class PromocionFlashDetalleScreen extends StatefulWidget {
  final String promocionId;
  const PromocionFlashDetalleScreen({super.key, required this.promocionId});

  @override
  State<PromocionFlashDetalleScreen> createState() =>
      _PromocionFlashDetalleScreenState();
}

class _PromocionFlashDetalleScreenState
    extends State<PromocionFlashDetalleScreen> {
  final _svc = PromocionesFlashService();
  Map<String, dynamic>? _p;
  bool _loading = true;
  bool _usando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final p = await _svc.detalle(widget.promocionId);
      if (mounted) {
        setState(() {
          _p = p;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _usar() async {
    setState(() => _usando = true);
    try {
      final res = await _svc.usar(widget.promocionId);
      final qr = res['qrData']?.toString();
      if (!mounted) return;
      setState(() => _usando = false);
      if (qr != null) _mostrarQr(qr);
    } catch (e) {
      if (!mounted) return;
      setState(() => _usando = false);
      final m = RegExp(r'"message":\s*"([^"]+)"').firstMatch(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m?.group(1) ?? 'No se pudo generar el canje'),
        backgroundColor: context.ec.red,
      ));
    }
  }

  void _mostrarQr(String qrData) {
    final ec = context.ec;
    showModalBottomSheet(
      context: context,
      backgroundColor: ec.surfaceMid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ec.strokeStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            Text('Muestra este código en el local',
                style: EnjoyTheme.heading(size: 17, color: ec.text)),
            const SizedBox(height: 6),
            Text('El staff lo escaneará para validar tu promoción.',
                textAlign: TextAlign.center,
                style: EnjoyTheme.body(size: 13, color: ec.textMute)),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: qrData,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 22),
            EnjoyButton(
              label: 'Listo',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final p = _p;

    return EnjoyScaffold(
      padding: EdgeInsets.zero,
      appBar: const EnjoyAppBar(title: 'Promoción'),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: ec.orange))
          : p == null
              ? Center(
                  child: Text('No se pudo cargar la promoción',
                      style: EnjoyTheme.body(color: ec.textMute)),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
                  children: [
                    // Imagen
                    SizedBox(
                      height: 240,
                      width: double.infinity,
                      child: (p['imagenUrl'] != null)
                          ? EnjoyImage(p['imagenUrl'].toString(),
                              fit: BoxFit.cover)
                          : Container(color: ec.glass),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (p['titulo'] ?? '').toString(),
                                  style: EnjoyTheme.heading(
                                      size: 22,
                                      weight: FontWeight.w800,
                                      color: ec.text),
                                ),
                              ),
                              if (p['canjeable'] == true)
                                Pill('Canjeable', variant: PillVariant.orange),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Builder(builder: (_) {
                            final (cuenta, proximamente) = cuentaFlash(p);
                            final color = proximamente ? ec.blue : ec.orangeSoft;
                            return Row(
                              children: [
                                Icon(
                                    proximamente
                                        ? Icons.upcoming_rounded
                                        : Icons.schedule_rounded,
                                    size: 15,
                                    color: color),
                                const SizedBox(width: 5),
                                Text(
                                  proximamente ? 'Próximamente · $cuenta' : cuenta,
                                  style: EnjoyTheme.body(size: 13, color: color),
                                ),
                              ],
                            );
                          }),
                          if ((p['descripcion'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              p['descripcion'].toString(),
                              style: EnjoyTheme.body(
                                  size: 14, height: 1.5, color: ec.textSoft),
                            ),
                          ],
                          if (p['precio'] != null) ...[
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('\$${p['precio']}',
                                    style: EnjoyTheme.heading(
                                        size: 24,
                                        weight: FontWeight.w800,
                                        color: ec.orange)),
                                if (p['precioAntes'] != null) ...[
                                  const SizedBox(width: 8),
                                  Text('\$${p['precioAntes']}',
                                      style: EnjoyTheme.body(
                                        size: 15,
                                        color: ec.textMute,
                                      ).copyWith(
                                        decoration:
                                            TextDecoration.lineThrough,
                                      )),
                                ],
                              ],
                            ),
                          ],
                          const SizedBox(height: 18),
                          GlassCard(
                            child: Row(
                              children: [
                                if ((p['localLogo'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: EnjoyImage(
                                          p['localLogo'].toString(),
                                          fit: BoxFit.cover),
                                    ),
                                  )
                                else
                                  const IconBox(Icons.storefront_rounded),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (p['localNombre'] ?? '').toString(),
                                        style: EnjoyTheme.heading(
                                            size: 15, color: ec.text),
                                      ),
                                      if ((p['localDireccion'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Text(
                                          p['localDireccion'].toString(),
                                          style: EnjoyTheme.body(
                                              size: 12, color: ec.textMute),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (p['canjeable'] == true)
                            Builder(builder: (_) {
                              final (_, proximamente) = cuentaFlash(p);
                              if (proximamente) {
                                return EnjoyButton(
                                  label: 'Disponible cuando empiece',
                                  icon: Icons.upcoming_rounded,
                                  variant: EnjoyButtonVariant.ghost,
                                  onPressed: null,
                                );
                              }
                              return EnjoyButton(
                                label: 'Usar promoción',
                                icon: Icons.qr_code_rounded,
                                loading: _usando,
                                onPressed: _usando ? null : _usar,
                              );
                            })
                          else
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: ec.glass,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: ec.stroke),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 18, color: ec.textMute),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Promoción informativa. Acércate al local para más detalles.',
                                      style: EnjoyTheme.body(
                                          size: 13, color: ec.textMute),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
