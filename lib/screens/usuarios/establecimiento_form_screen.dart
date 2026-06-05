import 'package:enjoy/models/categoria.dart';
import 'package:enjoy/models/ciudad.dart';
import 'package:enjoy/services/categorias_service.dart';
import 'package:enjoy/services/ciudades_service.dart';
import 'package:enjoy/services/establecimientos_empresa_service.dart';
import 'package:enjoy/screens/usuarios/establecimiento_detalle_screen.dart'
    show SearchableChips;
import 'package:enjoy/ui/palette.dart';
import 'package:flutter/material.dart';

/// Pantalla de creación rápida de un establecimiento.
/// Solo recoge los campos mínimos exigidos por el schema (`nombre`, `email`,
/// `identificacion`) más ciudad y categoría sugeridas. El resto se completa
/// luego desde el detalle/edición en el panel web.
class EstablecimientoFormScreen extends StatefulWidget {
  const EstablecimientoFormScreen({super.key});

  @override
  State<EstablecimientoFormScreen> createState() =>
      _EstablecimientoFormScreenState();
}

class _EstablecimientoFormScreenState extends State<EstablecimientoFormScreen> {
  final _svc = EstablecimientosEmpresaService();
  final _ciudadesSvc = CiudadesService();
  final _categoriasSvc = CategoriasService();

  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _identificacion = TextEditingController();

  List<Ciudad> _ciudades = [];
  List<Categoria> _categorias = [];
  String? _ciudadId;
  final List<String> _selectedCategorias = [];

  bool _loadingRefs = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cargarReferencias();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _identificacion.dispose();
    super.dispose();
  }

  Future<void> _cargarReferencias() async {
    try {
      final ciudades = await _ciudadesSvc.getParaPromos();
      final categorias = await _categoriasSvc.getActivas();
      if (!mounted) return;
      setState(() {
        _ciudades = ciudades;
        _categorias = categorias;
        _loadingRefs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRefs = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'nombre': _nombre.text.trim(),
        'email': _email.text.trim().toLowerCase(),
        'identificacion': _identificacion.text.trim(),
        'rol': 'admin-local',
        'estado': false,
        if (_ciudadId != null) 'ciudades': [_ciudadId],
        if (_selectedCategorias.isNotEmpty) 'categorias': _selectedCategorias,
      };
      await _svc.crear(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Establecimiento creado. Se envió la clave por correo.'),
          backgroundColor: Palette.kAccent,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Palette.kTitle),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nuevo establecimiento',
          style: TextStyle(
            color: Palette.kTitle,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Palette.kSurface,
            border: Border(bottom: BorderSide(color: Palette.kBorder)),
          ),
        ),
      ),
      body: _loadingRefs
          ? const Center(
              child: CircularProgressIndicator(color: Palette.kAccent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const _SectionLabel(label: 'Datos básicos'),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _nombre,
                    label: 'Nombre del establecimiento',
                    icon: Icons.store_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _email,
                    label: 'Correo electrónico',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Requerido';
                      final emailRegex =
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                      if (!emailRegex.hasMatch(value)) return 'Email inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _identificacion,
                    label: 'Identificación (CI / RUC)',
                    icon: Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Requerido';
                      if (!RegExp(r'^\d{10}(\d{3})?$').hasMatch(value)) {
                        return 'CI (10 dígitos) o RUC (13 dígitos)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  const _SectionLabel(label: 'Ubicación y categoría'),
                  const SizedBox(height: 12),
                  _Dropdown(
                    label: 'Ciudad',
                    icon: Icons.location_on_outlined,
                    value: _ciudadId,
                    items: _ciudades
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.nombre),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _ciudadId = v),
                  ),
                  const SizedBox(height: 16),
                  const _SectionLabel(label: 'Categorías'),
                  const SizedBox(height: 12),
                  SearchableChips(
                    items: _categorias
                        .map((c) => (id: c.id, label: c.nombre))
                        .toList(),
                    selected: _selectedCategorias,
                    color: Palette.kAccent,
                    hint: 'Buscar categoría',
                    emptyText: 'No hay categorías disponibles',
                    onToggle: (id) => setState(() {
                      if (_selectedCategorias.contains(id)) {
                        _selectedCategorias.remove(id);
                      } else {
                        _selectedCategorias.add(id);
                      }
                    }),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Palette.kAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Palette.kAccent.withOpacity(0.25)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: Palette.kAccent),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Se creará como Inactivo. Un administrador deberá activarlo desde el panel web para que aparezca al cliente. Se envía clave temporal por correo.',
                            style: TextStyle(
                                color: Palette.kTitle, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Palette.kAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        disabledBackgroundColor:
                            Palette.kAccent.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Crear establecimiento',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Palette.kMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Palette.kTitle, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Palette.kMuted, size: 18),
        labelText: label,
        labelStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
        filled: true,
        fillColor: Palette.kSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Palette.kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Palette.kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Palette.kAccent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _Dropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      style: const TextStyle(color: Palette.kTitle, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Palette.kMuted, size: 18),
        labelText: label,
        labelStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
        filled: true,
        fillColor: Palette.kSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Palette.kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Palette.kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Palette.kAccent),
        ),
      ),
    );
  }
}

/// Campo tipo dropdown pero con buscador (abre un modal con lista filtrable).
/// Ideal para listas largas como categorías (150+).
class SearchablePickerField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<({String id, String label})> items;
  final ValueChanged<String?> onChanged;

  const SearchablePickerField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  String? get _selectedLabel {
    for (final i in items) {
      if (i.id == value) return i.label;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _PickerSheet(label: label, items: items, value: value),
    );
    if (selected != null) onChanged(selected == '__none__' ? null : selected);
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selectedLabel;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Palette.kMuted, size: 18),
          labelText: label,
          labelStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
          filled: true,
          fillColor: Palette.kSurface,
          suffixIcon: const Icon(Icons.search_rounded, color: Palette.kMuted, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Palette.kBorder),
          ),
        ),
        child: Text(
          sel ?? 'Seleccionar…',
          style: TextStyle(
            color: sel != null ? Palette.kTitle : Palette.kMuted,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  final String label;
  final List<({String id, String label})> items;
  final String? value;
  const _PickerSheet({required this.label, required this.items, required this.value});

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _q = '';

  String _norm(String s) {
    var r = s.toLowerCase();
    const from = 'áàäâéèëêíìïîóòöôúùüûñ';
    const to = 'aaaaeeeeiiiioooouuuun';
    for (var i = 0; i < from.length; i++) {
      r = r.replaceAll(from[i], to[i]);
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final q = _norm(_q.trim());
    final filtered = q.isEmpty
        ? widget.items
        : widget.items.where((i) => _norm(i.label).contains(q)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Palette.kBorder, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                style: const TextStyle(color: Palette.kTitle, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar ${widget.label.toLowerCase()}…',
                  hintStyle: const TextStyle(color: Palette.kMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Palette.kMuted),
                  filled: true,
                  fillColor: Palette.kField,
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Palette.kBorder)),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Sin resultados', style: TextStyle(color: Palette.kMuted)))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Palette.kBorder),
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        final sel = item.id == widget.value;
                        return ListTile(
                          title: Text(item.label, style: TextStyle(color: Palette.kTitle, fontSize: 14, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                          trailing: sel ? const Icon(Icons.check_rounded, color: Palette.kAccent, size: 20) : null,
                          onTap: () => Navigator.of(context).pop(item.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
