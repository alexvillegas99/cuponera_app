import 'package:enjoy/ui/palette.dart';
import 'package:flutter/material.dart';

/// Constructor de horario estandarizado por bloques (días + rango de hora).
/// Genera un texto uniforme tipo "Lun-Vie 12:00 a 14:00 · Sáb 10:00 a 14:00"
/// y lo entrega vía [onChanged].
class HorarioBuilder extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String> onChanged;
  const HorarioBuilder({super.key, this.initialValue, required this.onChanged});

  @override
  State<HorarioBuilder> createState() => _HorarioBuilderState();
}

class _Bloque {
  final Set<String> dias = {};
  String desde;
  String hasta;
  _Bloque({this.desde = '09:00', this.hasta = '18:00'});
}

const _dias = [
  ('lun', 'Lun'),
  ('mar', 'Mar'),
  ('mie', 'Mié'),
  ('jue', 'Jue'),
  ('vie', 'Vie'),
  ('sab', 'Sáb'),
  ('dom', 'Dom'),
];

class _HorarioBuilderState extends State<HorarioBuilder> {
  final List<_Bloque> _bloques = [_Bloque()];

  String get _preview => _generar();

  String _generar() {
    final orden = _dias.map((d) => d.$1).toList();
    final partes = <String>[];
    for (final b in _bloques) {
      if (b.dias.isEmpty) continue;
      final idxs = b.dias.map((d) => orden.indexOf(d)).where((i) => i >= 0).toList()
        ..sort();
      if (idxs.isEmpty) continue;
      // agrupar consecutivos
      final runs = <List<int>>[];
      var run = [idxs.first];
      for (var i = 1; i < idxs.length; i++) {
        if (idxs[i] == idxs[i - 1] + 1) {
          run.add(idxs[i]);
        } else {
          runs.add(run);
          run = [idxs[i]];
        }
      }
      runs.add(run);
      final diasTxt = runs
          .map((r) => r.length >= 2
              ? '${_dias[r.first].$2}-${_dias[r.last].$2}'
              : _dias[r.first].$2)
          .join(', ');
      partes.add('$diasTxt ${b.desde} a ${b.hasta}');
    }
    return partes.join(' · ');
  }

  void _emit() => widget.onChanged(_generar());

  Future<void> _pickHora(_Bloque b, bool desde) async {
    final actual = (desde ? b.desde : b.hasta).split(':');
    final res = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.tryParse(actual[0]) ?? 9, minute: int.tryParse(actual[1]) ?? 0),
    );
    if (res != null) {
      final hh = res.hour.toString().padLeft(2, '0');
      final mm = res.minute.toString().padLeft(2, '0');
      setState(() {
        if (desde) {
          b.desde = '$hh:$mm';
        } else {
          b.hasta = '$hh:$mm';
        }
      });
      _emit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _bloques.length; i++) _buildBloque(i),
        TextButton.icon(
          onPressed: () => setState(() => _bloques.add(_Bloque())),
          icon: const Icon(Icons.add, size: 16, color: Palette.kAccent),
          label: const Text('Agregar otro bloque',
              style: TextStyle(color: Palette.kAccent, fontSize: 12.5)),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
        ),
        if (_preview.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Palette.kField,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Palette.kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Así se verá:',
                    style: TextStyle(color: Palette.kMuted, fontSize: 11)),
                const SizedBox(height: 2),
                Text(_preview,
                    style: const TextStyle(
                        color: Palette.kTitle, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBloque(int i) {
    final b = _bloques[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Palette.kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _dias.map((d) {
              final sel = b.dias.contains(d.$1);
              return GestureDetector(
                onTap: () {
                  setState(() => sel ? b.dias.remove(d.$1) : b.dias.add(d.$1));
                  _emit();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? Palette.kAccent : Palette.kField,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? Palette.kAccent : Palette.kBorder),
                  ),
                  child: Text(d.$2,
                      style: TextStyle(
                          color: sel ? Colors.white : Palette.kMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _timeBox(b.desde, () => _pickHora(b, true)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('a', style: TextStyle(color: Palette.kMuted)),
              ),
              _timeBox(b.hasta, () => _pickHora(b, false)),
              const Spacer(),
              if (_bloques.length > 1)
                GestureDetector(
                  onTap: () {
                    setState(() => _bloques.removeAt(i));
                    _emit();
                  },
                  child: Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red.shade400),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeBox(String value, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Palette.kField,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Palette.kBorder),
          ),
          child: Text(value, style: const TextStyle(color: Palette.kTitle, fontSize: 13)),
        ),
      );
}
