// Smoke test del Design System "Premium Dark + Glow".
//
// El antiguo test referenciaba `MyApp` (clase inexistente; la app usa
// `RootApp` y requiere Firebase/dotenv para arrancar). Lo reemplazamos por
// una verificación ligera de que el tema y los widgets base renderizan.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy/ui/enjoy.dart';

void main() {
  testWidgets('EnjoyTheme + widgets base renderizan (dark)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EnjoyTheme.dark(),
        home: const EnjoyScaffold(
          body: Column(
            children: [
              Pill('Activa', variant: PillVariant.green),
              EnjoyButton(label: 'Continuar'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Activa'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('EnjoyTheme claro también construye',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EnjoyTheme.light(),
        home: const EnjoyScaffold(body: Text('Hola')),
      ),
    );
    expect(find.text('Hola'), findsOneWidget);
  });
}
