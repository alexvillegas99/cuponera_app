import 'dart:async';

import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/clientes_admin_service.dart';
import 'package:enjoy/services/nueva_cuponera_admin_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';

class NuevaCuponeraAdminScreen extends StatefulWidget {
  const NuevaCuponeraAdminScreen({super.key});

  @override
  State<NuevaCuponeraAdminScreen> createState() => _NuevaCuponeraAdminScreenState();
}

class _NuevaCuponeraAdminScreenState extends State<NuevaCuponeraAdminScreen> {
  final _clienteSvc = ClientesAdminService();
  final _svc = NuevaCuponeraAdminService();
  final _auth = AuthService();

  // ── Paso actual (0 = cliente, 1 = versión, 2 = confirmar) ─────────
  int _paso = 0;

  // ── Búsqueda de cliente ───────────────────────────────────────────
  final _clienteCtrl = TextEditingController();
  List<Map<String, dynamic>> _clientes = [];
  bool _buscandoCliente = false;
  Map<String, dynamic>? _clienteSeleccionado;
  Timer? _timerCliente;

  // ── Búsqueda de versión ───────────────────────────────────────────
  final _versionCtrl = TextEditingController();
  List<Map<String, dynamic>> _versiones = [];
  bool _buscandoVersion = false;
  Map<String, dynamic>? _versionSeleccionada;
  Timer? _timerVersion;

  // ── Confirmación ──────────────────────────────────────────────────
  bool _creando = false;
  String? _errorGlobal;

  @override
  void initState() {
    super.initState();
    _cargarVersionesInicial();
  }

  @override
  void dispose() {
    _clienteCtrl.dispose();
    _versionCtrl.dispose();
    _timerCliente?.cancel();
    _timerVersion?.cancel();
    super.dispose();
  }

  // ── Carga inicial de versiones (todas las activas) ─────────────────
  Future<void> _cargarVersionesInicial() async {
    setState(() => _buscandoVersion = true);
    try {
      final data = await _svc.buscarVersiones('');
      if (mounted) setState(() { _versiones = data; _buscandoVersion = false; });
    } catch (_) {
      if (mounted) setState(() => _buscandoVersion = false);
    }
  }

  // ── Búsqueda de cliente con debounce ──────────────────────────────
  void _onClienteChanged(String q) {
    _timerCliente?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _clientes = []; _buscandoCliente = false; });
      return;
    }
    setState(() => _buscandoCliente = true);
    _timerCliente = Timer(const Duration(milliseconds: 400), () async {
      try {
        final data = await _clienteSvc.buscar(q.trim());
        if (mounted) setState(() { _clientes = data; _buscandoCliente = false; });
      } catch (_) {
        if (mounted) setState(() => _buscandoCliente = false);
      }
    });
  }

  // ── Búsqueda de versión con debounce ──────────────────────────────
  void _onVersionChanged(String q) {
    _timerVersion?.cancel();
    setState(() => _buscandoVersion = true);
    _timerVersion = Timer(const Duration(milliseconds: 300), () async {
      try {
        final data = await _svc.buscarVersiones(q.trim());
        if (mounted) setState(() { _versiones = data; _buscandoVersion = false; });
      } catch (_) {
        if (mounted) setState(() => _buscandoVersion = false);
      }
    });
  }

  void _seleccionarCliente(Map<String, dynamic> c) {
    setState(() {
      _clienteSeleccionado = c;
      _clienteCtrl.text = _nombreCliente(c);
      _clientes = [];
      _paso = 1;
    });
  }

  void _seleccionarVersion(Map<String, dynamic> v) {
    setState(() {
      _versionSeleccionada = v;
      _versionCtrl.text = (v['nombre'] ?? '').toString();
      _versiones = [];
      _paso = 2;
    });
  }

  void _resetCliente() {
    setState(() {
      _clienteSeleccionado = null;
      _clienteCtrl.clear();
      _clientes = [];
      _paso = 0;
    });
  }

  void _resetVersion() {
    setState(() {
      _versionSeleccionada = null;
      _versionCtrl.clear();
      _paso = 1;
      _cargarVersionesInicial();
    });
  }

  Future<void> _confirmar() async {
    final user = await _auth.getUser();
    final activadorId = user?['_id']?.toString() ?? '';
    final clienteId = (_clienteSeleccionado?['_id'] ?? '').toString();
    final versionId = (_versionSeleccionada?['_id'] ?? '').toString();

    if (clienteId.isEmpty || versionId.isEmpty || activadorId.isEmpty) return;

    setState(() { _creando = true; _errorGlobal = null; });
    try {
      await _svc.crearCupon(
        versionId: versionId,
        clienteId: clienteId,
        usuarioActivadorId: activadorId,
      );
      if (mounted) {
        _mostrarExito();
        _reiniciar();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorGlobal = _mensajeError(e);
          _creando = false;
        });
      }
    }
  }

  void _reiniciar() {
    setState(() {
      _clienteSeleccionado = null;
      _versionSeleccionada = null;
      _clienteCtrl.clear();
      _versionCtrl.clear();
      _clientes = [];
      _paso = 0;
      _creando = false;
      _errorGlobal = null;
    });
    _cargarVersionesInicial();
  }

  void _mostrarExito() {
    final ec = context.ec;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Expanded(child: Text('Cuponera asignada exitosamente')),
        ],
      ),
      backgroundColor: ec.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  String _mensajeError(Object e) {
    final s = e.toString();
    if (s.contains('message')) {
      final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(s);
      if (match != null) return match.group(1)!;
    }
    return 'No se pudo asignar la cuponera. Intenta de nuevo.';
  }

  String _nombreCliente(Map<String, dynamic> c) {
    final n = (c['nombres'] ?? c['nombre'] ?? '').toString().trim();
    final a = (c['apellidos'] ?? '').toString().trim();
    return [n, a].where((s) => s.isNotEmpty).join(' ');
  }

  String _formatFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ══════════════════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Indicador de pasos ─────────────────────────────────
          Steps(count: 3, current: _paso + 1),
          const SizedBox(height: 12),
          _StepLabels(paso: _paso),
          const SizedBox(height: 22),

          // ── Error global ───────────────────────────────────────
          if (_errorGlobal != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: ec.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ec.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: ec.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_errorGlobal!, style: EnjoyTheme.body(size: 13, color: ec.red))),
                  GestureDetector(
                    onTap: () => setState(() => _errorGlobal = null),
                    child: Icon(Icons.close_rounded, size: 16, color: ec.red),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── PASO 1: Buscar cliente ─────────────────────────────
          _SectionCard(
            numero: '1',
            titulo: 'Buscar cliente',
            completado: _clienteSeleccionado != null,
            child: _clienteSeleccionado != null
                ? _ClienteSeleccionadoCard(
                    cliente: _clienteSeleccionado!,
                    nombreCliente: _nombreCliente(_clienteSeleccionado!),
                    onCambiar: _resetCliente,
                  )
                : _BusquedaCliente(
                    ctrl: _clienteCtrl,
                    buscando: _buscandoCliente,
                    clientes: _clientes,
                    onChanged: _onClienteChanged,
                    onSeleccionar: _seleccionarCliente,
                    nombreCliente: _nombreCliente,
                  ),
          ),

          const SizedBox(height: 16),

          // ── PASO 2: Buscar versión de cuponera ─────────────────
          _SectionCard(
            numero: '2',
            titulo: 'Seleccionar cuponera',
            completado: _versionSeleccionada != null,
            bloqueado: _clienteSeleccionado == null,
            child: _versionSeleccionada != null
                ? _VersionSeleccionadaCard(
                    version: _versionSeleccionada!,
                    onCambiar: _resetVersion,
                  )
                : _clienteSeleccionado == null
                    ? const _BloqueoHint(texto: 'Primero selecciona un cliente')
                    : _BusquedaVersion(
                        ctrl: _versionCtrl,
                        buscando: _buscandoVersion,
                        versiones: _versiones,
                        onChanged: _onVersionChanged,
                        onSeleccionar: _seleccionarVersion,
                      ),
          ),

          const SizedBox(height: 16),

          // ── PASO 3: Preview y confirmación ─────────────────────
          _SectionCard(
            numero: '3',
            titulo: 'Confirmar asignación',
            completado: false,
            bloqueado: _clienteSeleccionado == null || _versionSeleccionada == null,
            child: _clienteSeleccionado == null || _versionSeleccionada == null
                ? const _BloqueoHint(texto: 'Completa los pasos anteriores')
                : _ConfirmacionPanel(
                    cliente: _clienteSeleccionado!,
                    version: _versionSeleccionada!,
                    nombreCliente: _nombreCliente(_clienteSeleccionado!),
                    fechaHoy: _formatFecha(DateTime.now()),
                    creando: _creando,
                    onConfirmar: _confirmar,
                    onReiniciar: _reiniciar,
                  ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ETIQUETAS DE PASOS (bajo la barra Steps)
// ══════════════════════════════════════════════════════════════════════════════

class _StepLabels extends StatelessWidget {
  final int paso;
  const _StepLabels({required this.paso});

  @override
  Widget build(BuildContext context) {
    const labels = ['Cliente', 'Cuponera', 'Confirmar'];
    return Row(
      children: List.generate(labels.length, (i) {
        final activo = i <= paso;
        final ec = context.ec;
        return Expanded(
          child: Text(
            labels[i],
            textAlign: i == 0
                ? TextAlign.start
                : i == labels.length - 1
                    ? TextAlign.end
                    : TextAlign.center,
            style: EnjoyTheme.body(
              size: 11,
              weight: FontWeight.w600,
              color: activo ? ec.orangeSoft : ec.textMute,
            ),
          ),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD DE SECCIÓN
// ══════════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String numero;
  final String titulo;
  final bool completado;
  final bool bloqueado;
  final Widget child;

  const _SectionCard({
    required this.numero,
    required this.titulo,
    required this.completado,
    this.bloqueado = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: bloqueado ? 0.5 : 1.0,
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderColor: completado ? ec.green.withValues(alpha: 0.4) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      gradient: completado ? ec.greenGradient : ec.accentGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: completado
                          ? Icon(Icons.check_rounded, size: 14, color: ec.isDark ? const Color(0xFF06210F) : Colors.white)
                          : Text(numero, style: EnjoyTheme.heading(size: 12, weight: FontWeight.w800, color: ec.onAccent)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(titulo, style: EnjoyTheme.heading(size: 15, color: ec.text)),
                ],
              ),
            ),
            const EnjoyDivider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BÚSQUEDA DE CLIENTE
// ══════════════════════════════════════════════════════════════════════════════

class _BusquedaCliente extends StatelessWidget {
  final TextEditingController ctrl;
  final bool buscando;
  final List<Map<String, dynamic>> clientes;
  final void Function(String) onChanged;
  final void Function(Map<String, dynamic>) onSeleccionar;
  final String Function(Map<String, dynamic>) nombreCliente;

  const _BusquedaCliente({
    required this.ctrl,
    required this.buscando,
    required this.clientes,
    required this.onChanged,
    required this.onSeleccionar,
    required this.nombreCliente,
  });

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          onChanged: onChanged,
          cursorColor: ec.orange,
          style: EnjoyTheme.body(size: 14, color: ec.text),
          decoration: InputDecoration(
            hintText: 'Nombre, correo o cédula...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: buscando
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ec.orange)),
                  )
                : null,
          ),
        ),
        if (clientes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: ec.glass,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: ec.stroke),
            ),
            child: Column(
              children: clientes.asMap().entries.map((entry) {
                final i = entry.key;
                final c = entry.value;
                final nombre = nombreCliente(c);
                final correo = (c['email'] ?? c['correo'] ?? '').toString();
                final cedula = (c['identificacion'] ?? '').toString();
                return InkWell(
                  onTap: () => onSeleccionar(c),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      border: i < clientes.length - 1
                          ? Border(bottom: BorderSide(color: ec.stroke))
                          : null,
                    ),
                    child: Row(
                      children: [
                        EnjoyAvatar(nombre.isNotEmpty ? nombre : '?', size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nombre.isNotEmpty ? nombre : '—',
                                  style: EnjoyTheme.heading(size: 13, weight: FontWeight.w600, color: ec.text),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(correo,
                                  style: EnjoyTheme.body(size: 11, color: ec.textMute),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        if (cedula.isNotEmpty) Pill(cedula, dense: true),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ] else if (ctrl.text.isNotEmpty && !buscando)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: ec.textMute),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('No se encontraron clientes con "${ctrl.text}"',
                      style: EnjoyTheme.body(size: 12, color: ec.textMute)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Cliente seleccionado ─────────────────────────────────────────────────────

class _ClienteSeleccionadoCard extends StatelessWidget {
  final Map<String, dynamic> cliente;
  final String nombreCliente;
  final VoidCallback onCambiar;

  const _ClienteSeleccionadoCard({
    required this.cliente,
    required this.nombreCliente,
    required this.onCambiar,
  });

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final correo = (cliente['email'] ?? cliente['correo'] ?? '—').toString();
    final cedula = (cliente['identificacion'] ?? '—').toString();

    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: ec.green.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: ec.green.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              nombreCliente.isNotEmpty ? nombreCliente[0].toUpperCase() : '?',
              style: EnjoyTheme.heading(size: 18, weight: FontWeight.w800, color: ec.green),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombreCliente, style: EnjoyTheme.heading(size: 14, color: ec.text)),
              Text(correo, style: EnjoyTheme.body(size: 11, color: ec.textMute)),
              Text('CI: $cedula', style: EnjoyTheme.body(size: 11, color: ec.textMute)),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onCambiar,
          icon: const Icon(Icons.edit_rounded, size: 14),
          label: const Text('Cambiar'),
          style: TextButton.styleFrom(foregroundColor: ec.orangeSoft, padding: const EdgeInsets.symmetric(horizontal: 10)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BÚSQUEDA DE VERSIÓN DE CUPONERA
// ══════════════════════════════════════════════════════════════════════════════

class _BusquedaVersion extends StatelessWidget {
  final TextEditingController ctrl;
  final bool buscando;
  final List<Map<String, dynamic>> versiones;
  final void Function(String) onChanged;
  final void Function(Map<String, dynamic>) onSeleccionar;

  const _BusquedaVersion({
    required this.ctrl,
    required this.buscando,
    required this.versiones,
    required this.onChanged,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          onChanged: onChanged,
          cursorColor: ec.orange,
          style: EnjoyTheme.body(size: 14, color: ec.text),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre...',
            prefixIcon: const Icon(Icons.confirmation_num_rounded, size: 20),
            suffixIcon: buscando
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ec.orange)),
                  )
                : null,
          ),
        ),
        if (buscando && versiones.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: ec.orange)),
          )
        else if (versiones.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...versiones.map((v) => _VersionCard(version: v, onSeleccionar: () => onSeleccionar(v))),
        ] else if (ctrl.text.isNotEmpty && !buscando)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: ec.textMute),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('No se encontraron versiones con "${ctrl.text}"',
                      style: EnjoyTheme.body(size: 12, color: ec.textMute)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _VersionCard extends StatelessWidget {
  final Map<String, dynamic> version;
  final VoidCallback onSeleccionar;

  const _VersionCard({required this.version, required this.onSeleccionar});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final nombre = (version['nombre'] ?? '—').toString();
    final precio = version['precio']?.toString();
    final ciudades = version['ciudadesDisponibles'];
    final ciudadesStr = ciudades is List ? ciudades.join(', ') : '';
    final descripcion = version['descripcion']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: onSeleccionar,
        padding: const EdgeInsets.all(14),
        blur: false,
        child: Row(
          children: [
            IconBox(Icons.confirmation_num_rounded, size: 42, radius: 11),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre,
                      style: EnjoyTheme.heading(size: 13, weight: FontWeight.w700, color: ec.text),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (ciudadesStr.isNotEmpty)
                    Text(ciudadesStr,
                        style: EnjoyTheme.body(size: 11, color: ec.textMute),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (descripcion != null && descripcion.isNotEmpty)
                    Text(descripcion,
                        style: EnjoyTheme.body(size: 11, color: ec.textMute),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (precio != null) ...[
              const SizedBox(width: 8),
              Pill('\$$precio', variant: PillVariant.orange, dense: true),
            ],
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: ec.textMute),
          ],
        ),
      ),
    );
  }
}

// ── Versión seleccionada ─────────────────────────────────────────────────────

class _VersionSeleccionadaCard extends StatelessWidget {
  final Map<String, dynamic> version;
  final VoidCallback onCambiar;

  const _VersionSeleccionadaCard({required this.version, required this.onCambiar});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final nombre = (version['nombre'] ?? '—').toString();
    final precio = version['precio']?.toString();
    final ciudades = version['ciudadesDisponibles'];
    final ciudadesStr = ciudades is List ? ciudades.join(', ') : '';

    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: ec.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: ec.green.withValues(alpha: 0.3)),
          ),
          child: Center(child: Icon(Icons.confirmation_num_rounded, color: ec.green, size: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre, style: EnjoyTheme.heading(size: 14, color: ec.text)),
              if (ciudadesStr.isNotEmpty)
                Text(ciudadesStr, style: EnjoyTheme.body(size: 11, color: ec.textMute)),
              if (precio != null)
                Text('\$$precio', style: EnjoyTheme.body(size: 12, weight: FontWeight.w600, color: ec.orangeSoft)),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onCambiar,
          icon: const Icon(Icons.edit_rounded, size: 14),
          label: const Text('Cambiar'),
          style: TextButton.styleFrom(foregroundColor: ec.orangeSoft, padding: const EdgeInsets.symmetric(horizontal: 10)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PANEL DE CONFIRMACIÓN
// ══════════════════════════════════════════════════════════════════════════════

class _ConfirmacionPanel extends StatelessWidget {
  final Map<String, dynamic> cliente;
  final Map<String, dynamic> version;
  final String nombreCliente;
  final String fechaHoy;
  final bool creando;
  final VoidCallback onConfirmar;
  final VoidCallback onReiniciar;

  const _ConfirmacionPanel({
    required this.cliente,
    required this.version,
    required this.nombreCliente,
    required this.fechaHoy,
    required this.creando,
    required this.onConfirmar,
    required this.onReiniciar,
  });

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final correo = (cliente['email'] ?? cliente['correo'] ?? '—').toString();
    final cedula = (cliente['identificacion'] ?? '—').toString();
    final vNombre = (version['nombre'] ?? '—').toString();
    final precio = version['precio']?.toString();
    final ciudades = version['ciudadesDisponibles'];
    final ciudadesStr = ciudades is List ? ciudades.join(', ') : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview card estilo ticket
        GlassCard(
          accent: true,
          blur: false,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: ec.orange.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.confirmation_num_rounded, color: ec.orangeSoft, size: 18),
                    const SizedBox(width: 8),
                    Text('Nueva cuponera', style: EnjoyTheme.heading(size: 14, weight: FontWeight.w800, color: ec.orangeSoft)),
                    const Spacer(),
                    Pill('ACTIVO', variant: PillVariant.green, dense: true),
                  ],
                ),
              ),
              // Cuerpo
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _PreviewRow(icon: Icons.person_rounded, label: 'Cliente', value: nombreCliente),
                    _PreviewRow(icon: Icons.email_rounded, label: 'Correo', value: correo),
                    _PreviewRow(icon: Icons.badge_rounded, label: 'Cédula', value: cedula),
                    const _PreviewDivider(),
                    _PreviewRow(icon: Icons.label_rounded, label: 'Cuponera', value: vNombre),
                    if (precio != null)
                      _PreviewRow(icon: Icons.attach_money_rounded, label: 'Precio', value: '\$$precio'),
                    _PreviewRow(icon: Icons.location_city_rounded, label: 'Ciudades', value: ciudadesStr),
                    const _PreviewDivider(),
                    _PreviewRow(icon: Icons.calendar_today_rounded, label: 'Fecha activación', value: fechaHoy),
                    _PreviewRow(icon: Icons.qr_code_scanner_rounded, label: 'Escaneos', value: '0 de los disponibles'),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Botones
        Row(
          children: [
            Expanded(
              child: EnjoyButton(
                label: 'Reiniciar',
                icon: Icons.refresh_rounded,
                variant: EnjoyButtonVariant.ghost,
                onPressed: creando ? null : onReiniciar,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: EnjoyButton(
                label: creando ? 'Asignando...' : 'Confirmar asignación',
                icon: creando ? null : Icons.check_circle_rounded,
                loading: creando,
                onPressed: creando ? null : onConfirmar,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _PreviewRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: ec.textMute),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(label, style: EnjoyTheme.body(size: 12, color: ec.textMute)),
          ),
          Expanded(
            child: Text(value,
                style: EnjoyTheme.body(size: 12, weight: FontWeight.w600, color: ec.text),
                maxLines: 2),
          ),
        ],
      ),
    );
  }
}

class _PreviewDivider extends StatelessWidget {
  const _PreviewDivider();

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: List.generate(
          20,
          (_) => Expanded(
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: ec.stroke,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════════════════

class _BloqueoHint extends StatelessWidget {
  final String texto;
  const _BloqueoHint({required this.texto});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return Row(
      children: [
        Icon(Icons.lock_outline_rounded, size: 14, color: ec.textMute),
        const SizedBox(width: 8),
        Text(texto, style: EnjoyTheme.body(size: 13, color: ec.textMute)),
      ],
    );
  }
}
