import 'package:enjoy/ui/enjoy.dart';
import 'package:flutter/material.dart';

/// Pantalla dedicada a leer el contrato de cooperación a pantalla completa.
///
/// La gente antes se perdía el scroll interno (280 px dentro de otro scroll)
/// y no lograba habilitar el checkbox de aceptación. Acá le damos toda la
/// pantalla al texto y un botón fijo abajo que sólo se habilita cuando llegó
/// al final. Devuelve `true` si el usuario confirmó haber leído.
class ContratoLecturaScreen extends StatefulWidget {
  final String nombreLocal;

  const ContratoLecturaScreen({super.key, required this.nombreLocal});

  @override
  State<ContratoLecturaScreen> createState() => _ContratoLecturaScreenState();
}

class _ContratoLecturaScreenState extends State<ContratoLecturaScreen> {
  final _scroll = ScrollController();
  bool _llegoAlFinal = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Textos cortos en pantallas grandes pueden no scrollear — chequeamos
    // al primer frame si ya está "todo visible" y damos por leído.
    WidgetsBinding.instance.addPostFrameCallback((_) => _chequearYaVisible());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _chequearYaVisible() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.maxScrollExtent <= 0) {
      setState(() => _llegoAlFinal = true);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients || _llegoAlFinal) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 16) {
      setState(() => _llegoAlFinal = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    return EnjoyScaffold(
      appBar: const EnjoyAppBar(title: 'Contrato de cooperación'),
      body: SafeArea(
        child: Column(
          children: [
            // Barrita superior con el estado de lectura.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              color: ec.glass,
              child: Row(
                children: [
                  Icon(
                    _llegoAlFinal
                        ? Icons.check_circle
                        : Icons.menu_book_outlined,
                    color: _llegoAlFinal ? ec.green : ec.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _llegoAlFinal
                          ? 'Leíste el contrato completo.'
                          : 'Desplazate hasta el final para poder aceptar.',
                      style: EnjoyTheme.body(
                        size: 12.5,
                        color: _llegoAlFinal ? ec.green : ec.text,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: _ContratoContenido(nombreLocal: widget.nombreLocal),
                ),
              ),
            ),
            // CTA fija abajo — habilitada sólo tras llegar al final.
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: ec.surfaceMid,
                border: Border(top: BorderSide(color: ec.stroke)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: EnjoyButton(
                  label: _llegoAlFinal
                      ? 'He leído el contrato'
                      : 'Desplazate hasta el final',
                  icon: _llegoAlFinal
                      ? Icons.check_circle_outline
                      : Icons.arrow_downward,
                  onPressed:
                      _llegoAlFinal ? () => Navigator.of(context).pop(true) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContratoContenido extends StatelessWidget {
  final String nombreLocal;
  const _ContratoContenido({required this.nombreLocal});

  @override
  Widget build(BuildContext context) {
    final ec = context.ec;
    final nombre = nombreLocal.trim().isEmpty ? '__________' : nombreLocal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONTRATO DE COOPERACIÓN ENTRE MARCAS',
          textAlign: TextAlign.center,
          style: EnjoyTheme.heading(
            size: 16,
            weight: FontWeight.w800,
            color: ec.text,
          ),
        ),
        const SizedBox(height: 14),
        _p(context,
            'En la ciudad de Ambato, comparecen CLUB ENJOY (CONTRATADO) y $nombre (CONTRATANTE), libres y capaces para contratar.'),
        _h(context, 'CLÁUSULA PRIMERA: ANTECEDENTES'),
        _p(context,
            '1. CLUB ENJOY es una compañía ecuatoriana ubicada en Cevallos, Tungurahua.'),
        _p(context,
            '2. ENJOY es una plataforma de beneficios mediante promociones en consumo, operada vía app digital.'),
        _p(context,
            '3. Club Enjoy distribuye membresías temporales e impulsa las ventas de locales afiliados.'),
        _h(context, 'CLÁUSULA SEGUNDA: OBJETO'),
        _p(context,
            'Cooperación entre marcas, incorporando al local "$nombre" a la red de afiliados. No involucra relación laboral.'),
        _h(context, 'CLÁUSULA TERCERA: OBLIGACIONES DEL LOCAL'),
        _p(context, 'a) Honrar los Beneficios ofrecidos en la app a los Socios.'),
        _p(context, 'b) Mantenerlos activos durante todo el horario de atención.'),
        _p(context, 'c) Validar cada Beneficio solo vía escaneo de QR.'),
        _p(context, 'd) Designar y capacitar al personal responsable.'),
        _p(context, 'e) Entregar información veraz del establecimiento.'),
        _p(context,
            'f) Notificar con anticipación cambios en horarios, ubicación o cierre.'),
        _p(context, 'g) Cumplir con la normativa aplicable.'),
        _p(context, 'h) Atender los reclamos de los Socios.'),
        _p(context, 'i) Pagar a Club Enjoy el valor económico pactado.'),
        _p(context,
            'j) Abstenerse de usar marcas de Club Enjoy fuera de lo autorizado.'),
        _h(context, 'CLÁUSULA CUARTA: OBLIGACIONES DE CLUB ENJOY'),
        _p(context,
            'a) Incorporar al local y difundir sus beneficios entre suscriptores.'),
        _p(context, 'b) Acceso a la plataforma y panel del afiliado.'),
        _p(context, 'c) Reportes y estadísticas de canjes.'),
        _p(context, 'd) Soporte y capacitación.'),
        _p(context, 'e) Acciones de promoción y marketing del local.'),
        _p(context, 'f) Emitir comprobante de venta por la afiliación.'),
        _p(context, 'g) Tratar los datos personales conforme a Ley.'),
        _p(context, 'h) Notificar suspensiones o cambios de la plataforma.'),
        _h(context, 'CLÁUSULA QUINTA: EXCLUSIVIDAD'),
        _p(context,
            'El local no trabajará con otro aplicativo móvil de promociones similares.'),
        _h(context, 'CLÁUSULA SEXTA: CONFIDENCIALIDAD'),
        _p(context,
            'Las partes mantienen confidencialidad hasta 1 año después del contrato.'),
        _h(context, 'CLÁUSULA SÉPTIMA: PROTECCIÓN DE DATOS'),
        _p(context, 'Conforme a la Ley Orgánica de Protección de Datos del Ecuador.'),
        _h(context, 'CLÁUSULA OCTAVA: RESPONSABILIDAD'),
        _p(context,
            'Club Enjoy no responde por calidad de productos o servicios del local. El local es responsable de la higiene y presentación.'),
        _h(context, 'CLÁUSULA NOVENA: DISPOSICIONES GENERALES'),
        _p(context,
            'Toda modificación debe ser escrita y aceptada por ambas partes. (Art. 1561 del Código Civil.)'),
        _h(context, 'CLÁUSULA DÉCIMA: DURACIÓN Y RENOVACIÓN'),
        _p(context, 'Vigencia de un año, renovable por mutuo acuerdo.'),
        _h(context, 'CLÁUSULA DÉCIMA PRIMERA: TERMINACIÓN'),
        _p(context, 'Causas previstas en el Código Civil o por acuerdo escrito.'),
        _h(context, 'CLÁUSULA DÉCIMA SEGUNDA: CLÁUSULA PENAL'),
        _p(context, 'Multa económica por incumplimiento, pagadera de manera inmediata.'),
        _h(context, 'CLÁUSULA DÉCIMA TERCERA: MEDIACIÓN'),
        _p(context, 'Centro de mediación y arbitraje de Ambato.'),
        _h(context, 'CLÁUSULA DÉCIMA CUARTA: JURISDICCIÓN'),
        _p(context, 'Jueces competentes de Ambato, provincia de Tungurahua.'),
        const SizedBox(height: 14),
        Text(
          'Las partes aceptan todas las cláusulas del presente instrumento.',
          style: EnjoyTheme.body(
            size: 13.5,
            color: ec.text,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _h(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(
          t,
          style: EnjoyTheme.heading(
            size: 13.5,
            weight: FontWeight.w800,
            color: context.ec.text,
          ),
        ),
      );

  Widget _p(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t,
          style: EnjoyTheme.body(
            size: 13.5,
            color: context.ec.textSoft,
            height: 1.55,
          ),
        ),
      );
}
