import 'dart:async';

import 'package:enjoy/services/auth_service.dart';
import 'package:enjoy/services/clientes_admin_service.dart';
import 'package:enjoy/services/nueva_cuponera_admin_service.dart';
import 'package:enjoy/ui/palette.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Expanded(child: Text('Cuponera asignada exitosamente')),
        ],
      ),
      backgroundColor: const Color(0xFF16A34A),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Indicador de pasos ─────────────────────────────────
          _StepIndicator(paso: _paso),
          const SizedBox(height: 24),

          // ── Error global ───────────────────────────────────────
          if (_errorGlobal != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_errorGlobal!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                  GestureDetector(
                    onTap: () => setState(() => _errorGlobal = null),
                    child: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
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
// INDICADOR DE PASOS
// ══════════════════════════════════════════════════════════════════════════════

class _StepIndicator extends StatelessWidget {
  final int paso;
  const _StepIndicator({required this.paso});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepDot(numero: 1, activo: paso >= 0, completo: paso > 0, label: 'Cliente'),
        _StepLine(activo: paso > 0),
        _StepDot(numero: 2, activo: paso >= 1, completo: paso > 1, label: 'Cuponera'),
        _StepLine(activo: paso > 1),
        _StepDot(numero: 3, activo: paso >= 2, completo: false, label: 'Confirmar'),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final int numero;
  final bool activo;
  final bool completo;
  final String label;
  const _StepDot({required this.numero, required this.activo, required this.completo, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = completo ? const Color(0xFF16A34A) : activo ? Palette.kAccent : Palette.kBorder;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: (activo || completo) ? color : Palette.kField,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: completo
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : Text('$numero', style: TextStyle(
                    color: activo ? Colors.white : Palette.kMuted,
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
            color: (activo || completo) ? color : Palette.kMuted,
            fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool activo;
  const _StepLine({required this.activo});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 2,
          color: activo ? Palette.kAccent : Palette.kBorder,
        ),
      ),
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
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: bloqueado ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Palette.kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: completado ? const Color(0xFF16A34A).withOpacity(0.4) : Palette.kBorder,
            width: completado ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: completado ? const Color(0xFF16A34A) : Palette.kAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: completado
                          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                          : Text(numero, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(titulo, style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Palette.kBorder),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          onChanged: onChanged,
          style: const TextStyle(color: Palette.kTitle, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Nombre, correo o cédula...',
            hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: Palette.kMuted, size: 20),
            suffixIcon: buscando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.kAccent)),
                  )
                : null,
            filled: true, fillColor: Palette.kField,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.kAccent, width: 1.5)),
          ),
        ),
        if (clientes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Palette.kField,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.kBorder),
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
                  borderRadius: BorderRadius.circular(i == 0
                      ? 12
                      : i == clientes.length - 1
                          ? 12
                          : 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      border: i < clientes.length - 1
                          ? const Border(bottom: BorderSide(color: Palette.kBorder))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Palette.kAccent.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                              style: const TextStyle(color: Palette.kAccent, fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nombre.isNotEmpty ? nombre : '—',
                                  style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w600, fontSize: 13),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(correo,
                                  style: const TextStyle(color: Palette.kMuted, fontSize: 11),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        if (cedula.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Palette.kField,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Palette.kBorder),
                            ),
                            child: Text(cedula, style: const TextStyle(color: Palette.kMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
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
                const Icon(Icons.info_outline_rounded, size: 14, color: Palette.kMuted),
                const SizedBox(width: 6),
                Text('No se encontraron clientes con "${ctrl.text}"',
                    style: const TextStyle(color: Palette.kMuted, fontSize: 12)),
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
    final correo = (cliente['email'] ?? cliente['correo'] ?? '—').toString();
    final cedula = (cliente['identificacion'] ?? '—').toString();
    final initial = nombreCliente.isNotEmpty ? nombreCliente[0].toUpperCase() : '?';

    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
          ),
          child: Center(
            child: Text(initial, style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w800, fontSize: 18)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombreCliente, style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 14)),
              Text(correo, style: const TextStyle(color: Palette.kMuted, fontSize: 11)),
              Text('CI: $cedula', style: const TextStyle(color: Palette.kMuted, fontSize: 11)),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onCambiar,
          icon: const Icon(Icons.edit_rounded, size: 14),
          label: const Text('Cambiar'),
          style: TextButton.styleFrom(foregroundColor: Palette.kAccent, padding: const EdgeInsets.symmetric(horizontal: 10)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          onChanged: onChanged,
          style: const TextStyle(color: Palette.kTitle, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre...',
            hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.confirmation_num_rounded, color: Palette.kMuted, size: 18),
            suffixIcon: buscando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.kAccent)),
                  )
                : null,
            filled: true, fillColor: Palette.kField,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Palette.kBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Palette.kAccent, width: 1.5)),
          ),
        ),
        if (buscando && versiones.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Palette.kAccent)),
          )
        else if (versiones.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...versiones.map((v) => _VersionCard(version: v, onSeleccionar: () => onSeleccionar(v))),
        ] else if (ctrl.text.isNotEmpty && !buscando)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Palette.kMuted),
                const SizedBox(width: 6),
                Text('No se encontraron versiones con "${ctrl.text}"',
                    style: const TextStyle(color: Palette.kMuted, fontSize: 12)),
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
    final nombre = (version['nombre'] ?? '—').toString();
    final precio = version['precio']?.toString();
    final ciudades = version['ciudadesDisponibles'];
    final ciudadesStr = ciudades is List ? ciudades.join(', ') : '';
    final descripcion = version['descripcion']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onSeleccionar,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Palette.kField,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.kBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: Palette.kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(child: Icon(Icons.confirmation_num_rounded, color: Palette.kAccent, size: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (ciudadesStr.isNotEmpty)
                      Text(ciudadesStr,
                          style: const TextStyle(color: Palette.kMuted, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (descripcion != null && descripcion.isNotEmpty)
                      Text(descripcion,
                          style: const TextStyle(color: Palette.kMuted, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (precio != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Palette.kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('\$$precio',
                      style: const TextStyle(color: Palette.kAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Palette.kMuted),
            ],
          ),
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
    final nombre = (version['nombre'] ?? '—').toString();
    final precio = version['precio']?.toString();
    final ciudades = version['ciudadesDisponibles'];
    final ciudadesStr = ciudades is List ? ciudades.join(', ') : '';

    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
          ),
          child: const Center(child: Icon(Icons.confirmation_num_rounded, color: Color(0xFF16A34A), size: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre, style: const TextStyle(color: Palette.kTitle, fontWeight: FontWeight.w700, fontSize: 14)),
              if (ciudadesStr.isNotEmpty)
                Text(ciudadesStr, style: const TextStyle(color: Palette.kMuted, fontSize: 11)),
              if (precio != null)
                Text('\$$precio', style: const TextStyle(color: Palette.kAccent, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onCambiar,
          icon: const Icon(Icons.edit_rounded, size: 14),
          label: const Text('Cambiar'),
          style: TextButton.styleFrom(foregroundColor: Palette.kAccent, padding: const EdgeInsets.symmetric(horizontal: 10)),
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
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Palette.kAccent.withOpacity(0.08), Palette.kAccent.withOpacity(0.02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.kAccent.withOpacity(0.25)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Palette.kAccent.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.confirmation_num_rounded, color: Palette.kAccent, size: 18),
                    const SizedBox(width: 8),
                    const Text('Nueva cuponera', style: TextStyle(color: Palette.kAccent, fontWeight: FontWeight.w800, fontSize: 14)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('ACTIVO', style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
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
              child: OutlinedButton.icon(
                onPressed: creando ? null : onReiniciar,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reiniciar'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Palette.kBorder),
                  foregroundColor: Palette.kMuted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: creando ? null : onConfirmar,
                icon: creando
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(creando ? 'Asignando...' : 'Confirmar asignación',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.kAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Palette.kMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Palette.kMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Palette.kTitle, fontSize: 12, fontWeight: FontWeight.w600),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: List.generate(
          20,
          (_) => Expanded(
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: Palette.kBorder,
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
    return Row(
      children: [
        const Icon(Icons.lock_outline_rounded, size: 14, color: Palette.kMuted),
        const SizedBox(width: 8),
        Text(texto, style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
      ],
    );
  }
}
