// lib/screens/clientes/cuponeras_screen_light.dart
import 'dart:convert';

import 'package:enjoy/mappers/cuponera.dart';
import 'package:enjoy/screens/clientes/detalle_cupon.dart';
import 'package:enjoy/screens/clientes/comprar_cuponera_screen.dart';
import 'package:enjoy/screens/clientes/mis_solicitudes_screen.dart';
import 'package:enjoy/screens/clientes/regalo_reveal_screen.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:enjoy/services/cupones_service.dart';
import 'package:enjoy/services/core/api_exception.dart';
import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/versiones_service.dart';
import 'mapa_version_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/configuracion_service.dart';

class CuponerasScreenLight extends StatefulWidget {
  final List<Cuponera> cuponeras;
  final Future<void> Function()? onAddCuponera;

  const CuponerasScreenLight({
    super.key,
    required this.cuponeras,
    this.onAddCuponera,
  });

  @override
  State<CuponerasScreenLight> createState() => _CuponerasScreenLightState();
}

class _CuponerasScreenLightState extends State<CuponerasScreenLight> {
  final _cuponSvc = CuponesService();
  final _auth = AuthService();

  late List<Cuponera> _items;
  bool _reloading = false;
  String _whatsappNumero = '+593999999999';
  String _whatsappMensaje = 'Hola, quiero adquirir una membresía.';

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.cuponeras);
    _cargarConfigWhatsApp();
  }

  Future<void> _abrirRegalo(BuildContext context, Cuponera c) async {
    final me = await _auth.getUser();
    final clienteId = me?['_id']?.toString();
    if (clienteId == null || !context.mounted) return;
    final revelado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegaloRevealScreen(
          cuponId: c.id,
          clienteId: clienteId,
          cuponeraNombre: c.nombre,
          regaloDe: c.regaloDe,
          regaloMensaje: c.regaloMensaje,
        ),
      ),
    );
    if (revelado == true && mounted) {
      await _reloadFromServer();
    }
  }

  Future<void> _verMapa(BuildContext context, Cuponera c) async {
    final versionId = c.versionId;
    if (versionId == null || versionId.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final locales = await VersionesService.listarLocales(versionId);
      if (!context.mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MapaVersionScreen(
            versionNombre: c.nombre,
            locales: locales,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar el mapa.')),
      );
    }
  }

  Future<void> _cargarConfigWhatsApp() async {
    final configs = await ConfiguracionService.obtenerTodas();
    if (mounted) {
      setState(() {
        _whatsappNumero = configs['whatsapp_numero'] ?? _whatsappNumero;
        _whatsappMensaje = configs['whatsapp_mensaje'] ?? _whatsappMensaje;
      });
    }
  }

  Future<void> _reloadFromServer() async {
    setState(() => _reloading = true);
    try {
      final me = await _auth.getUser();
      final clienteId = me?['_id']?.toString();
      if (clienteId != null) {
        final fresh = await _cuponSvc.listarPorClientePaginado(
          clienteId,
          soloActivas: true,
          force: true,
        );
        if (!mounted) return;
        setState(() => _items = fresh);
      }
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  // ─────────────────────────── Escaneo + asignación
  Future<void> _scanAndLink(BuildContext context) async {
    final code = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScanPage()),
    );
    if (code == null || code.trim().isEmpty) return;

    final cuponId = _extractCuponId(code.trim());
    if (cuponId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código no válido para membresía.')),
      );
      return;
    }

    final me = await _auth.getUser();
    final clienteId = me?['_id']?.toString();
    if (clienteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión.')),
      );
      return;
    }

    Map<String, dynamic> raw;
    try {
      raw = await _cuponSvc.findByIdRaw(cuponId);
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al consultar el cupón.')),
      );
      return;
    }

    final dynamic local = raw['cliente'];
    final yaAsignadoA =
        (local is Map && local['_id'] != null)
            ? local['_id'].toString()
            : (local?.toString());

    if (yaAsignadoA == null || yaAsignadoA.isEmpty) {
      final ok = await _confirmAssignSheet(
        context,
        title: 'Asignar membresía',
        message: '¿Deseas ligar esta membresía a tu cuenta?',
        confirmLabel: 'Sí, asignar',
        cancelLabel: 'Cancelar',
      );
      if (ok != true) return;

      try {
        await _cuponSvc.asignarACliente(clienteId, cuponId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Membresía asignada correctamente!')),
        );
        await _reloadFromServer();
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo asignar.')),
        );
      }
    } else if (yaAsignadoA == clienteId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta membresía ya está ligada a tu cuenta.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La membresía ya está ligada a otro cliente.'),
        ),
      );
    }
  }

  String? _extractCuponId(String raw) {
    final reHex24 = RegExp(r'^[0-9a-fA-F]{24}$');
    if (reHex24.hasMatch(raw)) return raw;

    try {
      final uri = Uri.parse(raw);
      final id =
          uri.queryParameters['cuponId'] ?? uri.queryParameters['cupon'];
      if (id != null && reHex24.hasMatch(id)) return id;
    } catch (_) {}

    try {
      final obj = jsonDecode(raw);
      if (obj is Map) {
        final id =
            (obj['cuponId'] ?? obj['id'] ?? obj['cupon'])?.toString();
        if (id != null && reHex24.hasMatch(id)) return id;
      }
    } catch (_) {}

    return null;
  }

  // ─────────────────────────── Confirm sheet
  Future<bool?> _confirmAssignSheet(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Asignar',
    String cancelLabel = 'Cancelar',
    Map<String, dynamic>? cuponRaw,
  }) {
    final ec = context.ec;
    final ver = cuponRaw?['version'];
    final String versionNombre =
        (ver is Map && ver['nombre'] != null) ? ver['nombre'].toString() : '—';
    final String versionDescripcion =
        (ver is Map && ver['descripcion'] != null)
            ? ver['descripcion'].toString()
            : '';
    final int? sec =
        (cuponRaw?['secuencial'] is num)
            ? (cuponRaw!['secuencial'] as num).toInt()
            : null;

    String fmtSec(int? n) =>
        n == null ? 'Nº —' : 'Nº ${n.toString().padLeft(3, '0')}';

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ec.surfaceMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
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
            const SizedBox(height: 18),
            Row(
              children: [
                IconBox(Icons.qr_code_2_rounded, accent: true, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: EnjoyTheme.heading(size: 18, weight: FontWeight.w800, color: ec.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: EnjoyTheme.body(size: 14, color: ec.textMute),
            ),
            if (cuponRaw != null) ...[
              const SizedBox(height: 14),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBox(Icons.layers_rounded, size: 26, radius: 7, iconSize: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Versión: $versionNombre',
                            style: EnjoyTheme.body(size: 13, weight: FontWeight.w600, color: ec.text),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: ec.accentGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            fmtSec(sec),
                            style: EnjoyTheme.heading(size: 12, weight: FontWeight.w800, color: ec.onAccent),
                          ),
                        ),
                      ],
                    ),
                    if (versionDescripcion.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        versionDescripcion,
                        style: EnjoyTheme.body(size: 13, color: ec.textMute),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: EnjoyButton(
                    label: cancelLabel,
                    variant: EnjoyButtonVariant.ghost,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: EnjoyButton(
                    label: confirmLabel,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(String phone, {String? message}) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final text = Uri.encodeComponent(
      message ?? 'Hola, quiero adquirir una membresía.',
    );
    final nativeUrl = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$text');
    final webUrl = Uri.parse('https://wa.me/$cleanPhone?text=$text');

    if (await canLaunchUrl(nativeUrl)) {
      await launchUrl(nativeUrl);
    } else {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _showAdquirirSheet(BuildContext context) {
    final ec = context.ec;
    showModalBottomSheet(
      context: context,
      backgroundColor: ec.surfaceMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
              const SizedBox(height: 18),
              Row(
                children: [
                  IconBox(Icons.shopping_bag_rounded, accent: true, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adquirir Membresía',
                          style: EnjoyTheme.heading(size: 18, weight: FontWeight.w800, color: ec.text),
                        ),
                        Text(
                          'Elige cómo quieres adquirir tu membresía',
                          style: EnjoyTheme.body(size: 13, color: ec.textMute),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _AdquirirOptionCard(
                      icon: Icons.chat_rounded,
                      title: 'WhatsApp',
                      subtitle: 'Escribir por chat',
                      onTap: () {
                        Navigator.pop(context);
                        _openWhatsApp(
                          _whatsappNumero,
                          message: _whatsappMensaje,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AdquirirOptionCard(
                      icon: Icons.credit_card_rounded,
                      title: 'Compra directa',
                      subtitle: 'Transferencia bancaria',
                      onTap: () async {
                        Navigator.pop(context);
                        final me = await _auth.getUser();
                        if (me == null || !mounted) return;
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComprarCuponeraScreen(
                              clienteId: me['_id']?.toString() ?? '',
                              nombreCliente:
                                  '${me['nombres'] ?? ''} ${me['apellidos'] ?? ''}'
                                      .trim(),
                              emailCliente: me['email']?.toString() ?? '',
                              telefonoCliente: me['telefono']?.toString(),
                            ),
                          ),
                        );
                        if (result == true && mounted) {
                          _reloadFromServer();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: EdgeInsets.zero,
                child: TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final me = await _auth.getUser();
                    if (me == null || !mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MisSolicitudesScreen(
                          clienteId: me['_id']?.toString() ?? '',
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.receipt_long_rounded,
                    size: 18,
                    color: ec.orangeSoft,
                  ),
                  label: Text(
                    'Ver mis solicitudes',
                    style: EnjoyTheme.body(size: 14, weight: FontWeight.w600, color: ec.orangeSoft),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Barra CTA inferior
  Widget _buildBottomCta(BuildContext context) {
    final ec = context.ec;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 16),
          child: GestureDetector(
            onTap: () => _showAdquirirSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: ec.accentGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: ec.orange.withValues(alpha: .45),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: ec.onAccent, size: 20),
                  const SizedBox(width: 9),
                  Text(
                    'Adquirir Membresía',
                    style: EnjoyTheme.heading(size: 14, weight: FontWeight.w700, color: ec.onAccent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    if (_items.isEmpty) {
      return Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconBox(Icons.local_activity_rounded, accent: true, size: 72, radius: 20, iconSize: 36),
                  const SizedBox(height: 18),
                  Text(
                    'Sin membresías activas',
                    style: EnjoyTheme.heading(size: 17, weight: FontWeight.w800, color: ec.text),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Adquiere una membresía para disfrutar descuentos en los mejores locales.',
                    style: EnjoyTheme.body(size: 13, height: 1.5, color: ec.textMute),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: _reloadFromServer,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Actualizar'),
                    style: TextButton.styleFrom(
                      foregroundColor: ec.orangeSoft,
                      textStyle: EnjoyTheme.body(size: 14, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomCta(context),
        ],
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: ec.orange,
          backgroundColor: ec.surfaceMid,
          onRefresh: _reloadFromServer,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              88 + MediaQuery.of(context).padding.bottom,
            ),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) {
              final c = _items[i];
              if (c.esRegaloPendiente) {
                return _GiftPendingCard(
                  c: c,
                  onTap: () => _abrirRegalo(context, c),
                );
              }
              return _CuponeraTicketCard(
                c: c,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CuponDetalleScreen(cuponId: c.id),
                  ),
                ),
                onMapTap: c.versionId != null
                    ? () => _verMapa(context, c)
                    : null,
              );
            },
          ),
        ),
        _buildBottomCta(context),
        if (_reloading)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Pill('Actualizando…', icon: Icons.refresh_rounded),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Ticket card
// ══════════════════════════════════════════════════════════════════
class _CuponeraTicketCard extends StatelessWidget {
  final Cuponera c;
  final VoidCallback onTap;
  final VoidCallback? onMapTap;

  const _CuponeraTicketCard({
    required this.c,
    required this.onTap,
    this.onMapTap,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _secFmt(String s) {
    final n = int.tryParse(s);
    final pretty = n != null ? n.toString().padLeft(3, '0') : s;
    return 'Nº $pretty';
  }

  int? _diasRestantes(DateTime? expira) {
    if (expira == null) return null;
    final now = DateTime.now();
    if (expira.isBefore(now)) return 0;
    final base = DateTime(now.year, now.month, now.day);
    return expira.difference(base).inDays;
  }

  double? _lifeProgress(DateTime emitida, DateTime? expira) {
    if (expira == null) return null;
    final total = expira.difference(emitida).inSeconds;
    if (total <= 0) return 1;
    final elapsed = DateTime.now().difference(emitida).inSeconds;
    return (elapsed / total).clamp(0, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final dias = _diasRestantes(c.expiraEl);
    final vencida = c.expiraEl != null && c.expiraEl!.isBefore(DateTime.now());
    final porExpirar = !vencida && dias != null && dias <= 7;

    final statusLabel =
        vencida ? 'Vencida' : (porExpirar ? 'Por expirar' : 'Activa');
    final statusVariant =
        vencida ? PillVariant.red : (porExpirar ? PillVariant.orange : PillVariant.green);

    final String? lastUse = c.scans.isNotEmpty
        ? _fmt(
            (List.of(c.scans)..sort((a, b) => b.fecha.compareTo(a.fecha)))
                .first
                .fecha,
          )
        : (c.lastScanAt != null ? _fmt(c.lastScanAt!) : null);

    final count = c.scans.isNotEmpty ? c.scans.length : c.totalEscaneos;
    final progress = _lifeProgress(c.emitidaEl, c.expiraEl);
    final progressColor =
        vencida ? ec.red : (porExpirar ? ec.yellow : ec.orange);

    return GlassCard(
      padding: EdgeInsets.zero,
      radius: 20,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // ── Header gradiente ──
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              decoration: BoxDecoration(gradient: ec.accentGradient),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: ec.onAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.local_activity_rounded,
                      color: ec.onAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EnjoyTheme.heading(size: 16, weight: FontWeight.w800, color: ec.onAccent),
                        ),
                        const SizedBox(height: 3),
                        // Secuencial pill (+ badge de regalo si aplica)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ec.onAccent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _secFmt(c.secuencial),
                                style: EnjoyTheme.body(size: 11, weight: FontWeight.w700, color: ec.onAccent),
                              ),
                            ),
                            if (c.esRegalo)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: ec.onAccent.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  c.regaloDe != null && c.regaloDe!.trim().isNotEmpty
                                      ? '🎁 Regalo de ${c.regaloDe}'
                                      : '🎁 Regalo',
                                  style: EnjoyTheme.body(size: 11, weight: FontWeight.w700, color: ec.onAccent),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  Pill(statusLabel, variant: statusVariant, dot: true, dense: true),
                ],
              ),
            ),

            // ── Divisor tipo ticket ──
            SizedBox(
              height: 20,
              child: Stack(
                children: [
                  Positioned.fill(child: _DashedDivider(color: ec.stroke)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: ec.bgBottom,
                        shape: BoxShape.circle,
                        border: Border.all(color: ec.stroke),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: ec.bgBottom,
                        shape: BoxShape.circle,
                        border: Border.all(color: ec.stroke),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Descripción
                  if (c.descripcion.trim().isNotEmpty) ...[
                    Text(
                      c.descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: EnjoyTheme.body(size: 13, height: 1.5, color: ec.textMute),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Stats row
                  Row(
                    children: [
                      Pill(
                        '$count ${count == 1 ? "escaneo" : "escaneos"}',
                        icon: Icons.qr_code_scanner_rounded,
                        variant: PillVariant.orange,
                        dense: true,
                      ),
                      if (lastUse != null) ...[
                        const SizedBox(width: 8),
                        Pill(
                          'Último: $lastUse',
                          icon: Icons.history_rounded,
                          dense: true,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Fechas
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    radius: 12,
                    blur: false,
                    child: Row(
                      children: [
                        _dateItem(
                          context,
                          icon: Icons.event_available_rounded,
                          label: 'Emitida',
                          value: _fmt(c.emitidaEl),
                          color: ec.green,
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: ec.stroke,
                        ),
                        _dateItem(
                          context,
                          icon: Icons.event_busy_rounded,
                          label: 'Expira',
                          value: c.expiraEl != null
                              ? _fmt(c.expiraEl!)
                              : 'Sin límite',
                          color: vencida
                              ? ec.red
                              : (porExpirar ? ec.yellow : ec.textMute),
                        ),
                      ],
                    ),
                  ),

                  // Barra de progreso
                  if (progress != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 8,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: ec.glassStrong,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Inicio',
                          style: EnjoyTheme.body(size: 11, color: ec.textMute),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: progressColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            dias == null
                                ? 'Sin límite'
                                : (vencida
                                    ? 'Vencida'
                                    : 'Restan $dias días'),
                            style: EnjoyTheme.body(size: 11, weight: FontWeight.w600, color: progressColor),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Botón mapa
                  if (onMapTap != null) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: onMapTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: ec.orange.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ec.orange.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_rounded,
                              size: 16,
                              color: ec.orangeSoft,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Ver locales en el mapa',
                              style: EnjoyTheme.body(size: 13, weight: FontWeight.w600, color: ec.orangeSoft),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final ec = context.ec;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: EnjoyTheme.body(size: 11, weight: FontWeight.w600, color: color),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: EnjoyTheme.heading(size: 13, weight: FontWeight.w700, color: ec.text),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Tarjeta de regalo pendiente de abrir
// ══════════════════════════════════════════════════════════════════
class _GiftPendingCard extends StatelessWidget {
  final Cuponera c;
  final VoidCallback onTap;

  const _GiftPendingCard({required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: 20,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(gradient: ec.accentGradient),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: ec.onAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: ec.onAccent,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ec.onAccent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '🎁 Regalo sin abrir',
                        style: EnjoyTheme.body(size: 11, weight: FontWeight.w800, color: ec.onAccent),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.regaloDe != null && c.regaloDe!.trim().isNotEmpty
                          ? 'Tienes un regalo de ${c.regaloDe}'
                          : 'Tienes un regalo',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: EnjoyTheme.heading(size: 16, weight: FontWeight.w800, color: ec.onAccent),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Toca para abrirlo',
                      style: EnjoyTheme.body(size: 13, color: ec.onAccent.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ec.onAccent, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Divisor punteado (estilo ticket)
// ══════════════════════════════════════════════════════════════════
class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  _DashedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 6.0, dashSpace = 6.0;
    double startX = 28;
    final endX = size.width - 28;
    final y = size.height / 2;
    while (startX < endX) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + dashWidth, y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════
// Página de escáner QR
// ══════════════════════════════════════════════════════════════════
class _QrScanPage extends StatefulWidget {
  const _QrScanPage();

  @override
  State<_QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<_QrScanPage> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_handled) return;
    final codes = cap.barcodes;
    if (codes.isEmpty) return;
    final raw = codes.first.rawValue ?? '';
    if (raw.isEmpty) return;
    _handled = true;
    Navigator.pop(context, raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear membresía'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            fit: BoxFit.cover,
          ),
          // Marco de escaneo
          const Center(child: ScanFrame(size: 240)),
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white54,
                  size: 28,
                ),
                SizedBox(height: 8),
                Text(
                  'Apunta al código QR de tu membresía',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Opción de adquisición
// ══════════════════════════════════════════════════════════════════
class _AdquirirOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdquirirOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return GlassCard(
      onTap: onTap,
      radius: 16,
      child: Column(
        children: [
          IconBox(icon, accent: true, size: 44, radius: 12, iconSize: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: EnjoyTheme.heading(size: 14, weight: FontWeight.w700, color: ec.text),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: EnjoyTheme.body(size: 12, color: ec.textMute),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
