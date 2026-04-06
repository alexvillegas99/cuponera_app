import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../ui/palette.dart';
import '../../services/configuracion_service.dart';
import '../../services/solicitud_cuponera_service.dart';

class ComprarCuponeraScreen extends StatefulWidget {
  final String clienteId;
  final String nombreCliente;
  final String emailCliente;
  final String? telefonoCliente;

  const ComprarCuponeraScreen({
    super.key,
    required this.clienteId,
    required this.nombreCliente,
    required this.emailCliente,
    this.telefonoCliente,
  });

  @override
  State<ComprarCuponeraScreen> createState() => _ComprarCuponeraScreenState();
}

class _ComprarCuponeraScreenState extends State<ComprarCuponeraScreen> {
  bool _loading = true;
  bool _submitting = false;

  List<Map<String, dynamic>> _cuponeras = [];
  List<Map<String, dynamic>> _cuentas = [];
  String _instrucciones = '';

  int? _selectedCuponera;
  File? _comprobante;
  final _montoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchConfigs();
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchConfigs() async {
    final configs = await ConfiguracionService.obtenerTodas();
    if (!mounted) return;

    List<Map<String, dynamic>> cuponeras = [];
    List<Map<String, dynamic>> cuentas = [];
    String instrucciones = '';

    try {
      final cuponerasRaw = configs['cuponeras_disponibles'] ?? '[]';
      cuponeras = List<Map<String, dynamic>>.from(json.decode(cuponerasRaw));
    } catch (_) {}

    try {
      final cuentasRaw = configs['cuentas_bancarias'] ?? '[]';
      cuentas = List<Map<String, dynamic>>.from(json.decode(cuentasRaw));
    } catch (_) {}

    instrucciones = configs['transferencia_instrucciones'] ?? '';

    setState(() {
      _cuponeras = cuponeras;
      _cuentas = cuentas;
      _instrucciones = instrucciones;
      _loading = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 70);
    if (picked != null && mounted) {
      setState(() => _comprobante = File(picked.path));
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Seleccionar imagen',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Palette.kTitle,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Palette.kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: Palette.kAccent),
                ),
                title: const Text('Galeria'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Palette.kAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Palette.kAccent),
                ),
                title: const Text('Camara'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedCuponera == null) {
      _showSnack('Selecciona una cuponera');
      return;
    }
    if (_comprobante == null) {
      _showSnack('Sube tu comprobante de pago');
      return;
    }
    if (_montoCtrl.text.trim().isEmpty) {
      _showSnack('Ingresa el monto transferido');
      return;
    }

    setState(() => _submitting = true);

    String? base64Image;
    try {
      final bytes = await _comprobante!.readAsBytes();
      base64Image = base64Encode(bytes);
    } catch (_) {
      _showSnack('Error al procesar la imagen');
      setState(() => _submitting = false);
      return;
    }

    final cuponera = _cuponeras[_selectedCuponera!];
    final dto = {
      'cliente': widget.clienteId,
      'nombreCliente': widget.nombreCliente,
      'emailCliente': widget.emailCliente,
      'telefonoCliente': widget.telefonoCliente ?? '',
      'cuponeraNombre': cuponera['nombre'] ?? '',
      'cuponeraPrecio': cuponera['precio'] ?? '',
      'montoTransferido': _montoCtrl.text.trim(),
      'observaciones': _obsCtrl.text.trim(),
      'comprobanteBase64': base64Image,
    };

    final ok = await SolicitudCuponeraService.enviar(dto);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud enviada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      _showSnack('Error al enviar la solicitud. Intenta de nuevo.');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ─── Build helpers ──────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Palette.kAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Palette.kAccent, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Palette.kTitle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child, bool selected = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: selected
            ? Border.all(color: Palette.kAccent, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Palette.kMuted),
      filled: true,
      fillColor: Palette.kBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.kAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ─── Sections ───────────────────────────────────────────────

  Widget _buildCuponerasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.card_giftcard, 'Selecciona tu cuponera'),
        const SizedBox(height: 12),
        if (_cuponeras.isEmpty)
          const Text('No hay cuponeras disponibles.', style: TextStyle(color: Palette.kMuted))
        else
          ..._cuponeras.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;
            final selected = _selectedCuponera == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedCuponera = i),
                child: _card(
                  selected: selected,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: selected
                                ? Palette.kAccent.withOpacity(0.15)
                                : Palette.kBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.local_activity,
                            color: selected ? Palette.kAccent : Palette.kMuted,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['nombre']?.toString() ?? 'Cuponera',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: selected ? Palette.kTitle : Palette.kSub,
                                ),
                              ),
                              if (c['descripcion'] != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  c['descripcion'].toString(),
                                  style: const TextStyle(color: Palette.kMuted, fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          '\$${c['precio'] ?? '0'}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: selected ? Palette.kAccent : Palette.kTitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCuentasSection() {
    if (_cuentas.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.account_balance, 'Datos de transferencia'),
        const SizedBox(height: 12),
        ..._cuentas.map((cuenta) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cuenta['banco']?.toString() ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Palette.kTitle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _cuentaRow('Tipo', cuenta['tipo']?.toString() ?? ''),
                    _cuentaRow('Titular', cuenta['titular']?.toString() ?? ''),
                    _cuentaRow('CI', cuenta['ci']?.toString() ?? ''),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Numero de cuenta',
                                style: TextStyle(color: Palette.kMuted, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cuenta['numero']?.toString() ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Palette.kTitle,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final numero = cuenta['numero']?.toString() ?? '';
                            Clipboard.setData(ClipboardData(text: numero));
                            _showSnack('Numero de cuenta copiado');
                          },
                          icon: const Icon(Icons.copy, color: Palette.kAccent, size: 20),
                          tooltip: 'Copiar numero',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _cuentaRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Palette.kMuted, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Palette.kTitle, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruccionesSection() {
    if (_instrucciones.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.info_outline, 'Instrucciones'),
        const SizedBox(height: 12),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _instrucciones,
              style: const TextStyle(color: Palette.kTitle, fontSize: 14, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComprobanteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.upload_file, 'Sube tu comprobante'),
        const SizedBox(height: 12),
        if (_comprobante != null) ...[
          Stack(
            children: [
              _card(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _comprobante!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _comprobante = null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        GestureDetector(
          onTap: _showImageSourceSheet,
          child: _card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Palette.kAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: Palette.kAccent, size: 28),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _comprobante == null ? 'Toca para subir comprobante' : 'Cambiar imagen',
                    style: const TextStyle(
                      color: Palette.kMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.edit_note, 'Detalles del pago'),
        const SizedBox(height: 12),
        TextField(
          controller: _montoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDecoration('Monto transferido'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _obsCtrl,
          maxLines: 3,
          decoration: _inputDecoration('Observaciones (opcional)'),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Palette.kAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Palette.kAccent.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Enviar solicitud',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.kBg,
      appBar: AppBar(
        backgroundColor: Palette.kPrimary,
        foregroundColor: Colors.white,
        title: const Text(
          'Comprar Cuponera',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Palette.kAccent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCuponerasSection(),
                  const SizedBox(height: 24),
                  _buildCuentasSection(),
                  if (_cuentas.isNotEmpty) const SizedBox(height: 24),
                  _buildInstruccionesSection(),
                  if (_instrucciones.isNotEmpty) const SizedBox(height: 24),
                  _buildComprobanteSection(),
                  const SizedBox(height: 24),
                  _buildFormFields(),
                  const SizedBox(height: 28),
                  _buildSubmitButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
