import 'package:enjoy/services/clientes_admin_service.dart';
import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';

/// Pantalla en el menú admin que permite buscar clientes y activar /
/// desactivar su rol de promotor (mismo que la web, versión móvil).
class PromotoresAdminScreen extends StatefulWidget {
  const PromotoresAdminScreen({super.key});

  @override
  State<PromotoresAdminScreen> createState() => _PromotoresAdminScreenState();
}

class _PromotoresAdminScreenState extends State<PromotoresAdminScreen> {
  final _svc = ClientesAdminService();
  final _qCtrl = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  bool _cargando = false;
  Map<String, dynamic> _defaults = {'descuento': 20, 'comision': 20};

  @override
  void initState() {
    super.initState();
    _cargarDefaults();
    _buscar('');
  }

  Future<void> _cargarDefaults() async {
    try {
      _defaults = await _svc.promotorDefaults();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _buscar(String q) async {
    setState(() => _cargando = true);
    try {
      _items = await _svc.buscar(q);
    } catch (_) {
      _items = [];
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _abrirEditor(Map<String, dynamic> c) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.ec.surfaceMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditorPromotor(
        cliente: c,
        defaults: _defaults,
        svc: _svc,
      ),
    );
    // Refrescar la búsqueda al volver para mostrar cambios.
    _buscar(_qCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      appBar: const EnjoyAppBar(title: 'Promotores'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _qCtrl,
              style: EnjoyTheme.body(color: ec.text),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, email o cédula…',
                hintStyle: EnjoyTheme.body(color: ec.textMute),
                prefixIcon: Icon(Icons.search_rounded, color: ec.textMute),
                filled: true,
                fillColor: ec.glass,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ec.stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ec.stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ec.orange),
                ),
              ),
              onSubmitted: _buscar,
            ),
          ),
          Expanded(
            child: _cargando
                ? Center(child: CircularProgressIndicator(color: ec.orange))
                : _items.isEmpty
                    ? Center(
                        child: Text('Sin resultados',
                            style: EnjoyTheme.body(color: ec.textMute)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final c = _items[i];
                          final isPromotor = c['isPromotor'] == true;
                          final codigo = (c['codigoDescuento'] ?? '').toString();
                          final saldo = (c['saldoPromotor'] is num)
                              ? (c['saldoPromotor'] as num).toDouble()
                              : 0.0;
                          final nombre =
                              '${c['nombres'] ?? ''} ${c['apellidos'] ?? ''}'
                                  .trim();
                          return GestureDetector(
                            onTap: () => _abrirEditor(c),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: ec.glass,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isPromotor
                                      ? ec.orange.withValues(alpha: 0.5)
                                      : ec.stroke,
                                ),
                              ),
                              child: Row(
                                children: [
                                  IconBox(
                                    isPromotor
                                        ? Icons.verified_user_rounded
                                        : Icons.person_outline_rounded,
                                    accent: isPromotor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nombre.isEmpty ? '(sin nombre)' : nombre,
                                          style: EnjoyTheme.heading(
                                            size: 14,
                                            color: ec.text,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          (c['email'] ?? '').toString(),
                                          style: EnjoyTheme.body(
                                            size: 11.5,
                                            color: ec.textMute,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (isPromotor) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: ec.orange
                                                      .withValues(alpha: 0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  codigo.isEmpty ? '—' : codigo,
                                                  style: EnjoyTheme.body(
                                                    size: 11,
                                                    color: ec.orange,
                                                    weight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Saldo \$${saldo.toStringAsFixed(2)}',
                                                style: EnjoyTheme.body(
                                                  size: 11,
                                                  color: ec.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded,
                                      color: ec.textMute),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _EditorPromotor extends StatefulWidget {
  final Map<String, dynamic> cliente;
  final Map<String, dynamic> defaults;
  final ClientesAdminService svc;
  const _EditorPromotor({
    required this.cliente,
    required this.defaults,
    required this.svc,
  });

  @override
  State<_EditorPromotor> createState() => _EditorPromotorState();
}

class _EditorPromotorState extends State<_EditorPromotor> {
  final _codigoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _comCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _codigoCtrl.text = (widget.cliente['codigoDescuento'] ?? '').toString();
    final pd = widget.cliente['porcentajeDescuento'];
    final pc = widget.cliente['porcentajeComision'];
    if (pd is num) _descCtrl.text = pd.toString();
    if (pc is num) _comCtrl.text = pc.toString();
  }

  Future<void> _activar() async {
    final codigo = _codigoCtrl.text.trim().toUpperCase();
    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Definí un código.')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await widget.svc.activarPromotor(
        widget.cliente['_id'].toString(),
        codigo: codigo,
        porcentajeDescuento: int.tryParse(_descCtrl.text),
        porcentajeComision: int.tryParse(_comCtrl.text),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('400')
                ? 'Código en uso o inválido.'
                : 'No se pudo guardar.',
          ),
        ),
      );
    }
  }

  Future<void> _desactivar() async {
    setState(() => _guardando = true);
    try {
      await widget.svc.desactivarPromotor(widget.cliente['_id'].toString());
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo desactivar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final cliente = widget.cliente;
    final isPromotor = cliente['isPromotor'] == true;
    final dDef = widget.defaults['descuento'] ?? 20;
    final cDef = widget.defaults['comision'] ?? 20;
    final nombre =
        '${cliente['nombres'] ?? ''} ${cliente['apellidos'] ?? ''}'.trim();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: ec.strokeStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                nombre.isEmpty ? '(sin nombre)' : nombre,
                style: EnjoyTheme.heading(
                  size: 18, weight: FontWeight.w800, color: ec.text,
                ),
              ),
              Text(
                (cliente['email'] ?? '').toString(),
                style: EnjoyTheme.body(size: 12.5, color: ec.textMute),
              ),
              const SizedBox(height: 14),
              Text('Código (ej. ANA20) *',
                  style: EnjoyTheme.body(
                    size: 12.5, color: ec.textSoft, weight: FontWeight.w600,
                  )),
              const SizedBox(height: 4),
              TextField(
                controller: _codigoCtrl,
                textCapitalization: TextCapitalization.characters,
                style: EnjoyTheme.body(color: ec.text),
                decoration: InputDecoration(
                  hintText: 'ALEX20',
                  hintStyle: EnjoyTheme.body(color: ec.textMute),
                  filled: true,
                  fillColor: ec.glass,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ec.stroke),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('% Descuento',
                            style: EnjoyTheme.body(
                              size: 12.5, color: ec.textSoft,
                              weight: FontWeight.w600,
                            )),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _descCtrl,
                          keyboardType: TextInputType.number,
                          style: EnjoyTheme.body(color: ec.text),
                          decoration: InputDecoration(
                            hintText: 'Default: $dDef%',
                            hintStyle: EnjoyTheme.body(color: ec.textMute),
                            filled: true,
                            fillColor: ec.glass,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: ec.stroke),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('% Comisión',
                            style: EnjoyTheme.body(
                              size: 12.5, color: ec.textSoft,
                              weight: FontWeight.w600,
                            )),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _comCtrl,
                          keyboardType: TextInputType.number,
                          style: EnjoyTheme.body(color: ec.text),
                          decoration: InputDecoration(
                            hintText: 'Default: $cDef%',
                            hintStyle: EnjoyTheme.body(color: ec.textMute),
                            filled: true,
                            fillColor: ec.glass,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: ec.stroke),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (isPromotor)
                    Expanded(
                      child: EnjoyButton(
                        label: 'Desactivar',
                        icon: Icons.close_rounded,
                        variant: EnjoyButtonVariant.ghost,
                        onPressed: _guardando ? null : _desactivar,
                      ),
                    ),
                  if (isPromotor) const SizedBox(width: 8),
                  Expanded(
                    child: EnjoyButton(
                      label: _guardando
                          ? 'Guardando…'
                          : (isPromotor ? 'Guardar cambios' : 'Activar'),
                      icon: Icons.check_rounded,
                      onPressed: _guardando ? null : _activar,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
