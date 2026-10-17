import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winsnake_tools/main.dart';
import 'package:winsnake_tools/opciones/temporizador.dart';
import 'package:winsnake_tools/storage.dart';
import 'package:winsnake_tools/traduccion.dart';

void main() {
  testWidgets('App renders WinSnakeApp and WinSnakeWidget', (tester) async {
    await tester.pumpWidget(const WinSnakeApp());
    expect(find.byType(WinSnakeApp), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  test('Translations resolve Spanish and English keys properly', () {
    expect(t('evitar_suspension', 'es'), 'Evitar suspensión');
    expect(t('evitar_suspension', 'en'), 'Prevent sleep');
    expect(t('tiempo_terminado', 'es'), '¡Tiempo!');
    expect(t('tiempo_terminado', 'en'), 'Time up!');
    expect(t('serpiente', 'es'), 'Serpiente');
    expect(t('serpiente', 'en'), 'Snake');
    expect(t('clave_inexistente', 'es'), 'clave_inexistente');
  });

  test('Configuracion and NotaItem serialize and deserialize accurately', () {
    final cfg = Configuracion(
      velocidad: 1.5,
      opacidad: 0.8,
      tamano: 0.4,
      inicioAutomatico: true,
      evitarSuspension: true,
      animal: 'Capybara',
      autoCerrarNotas: false,
      idioma: 'en',
    );
    final restored = Configuracion.fromJson(cfg.toJson());
    expect(restored.velocidad, 1.5);
    expect(restored.opacidad, 0.8);
    expect(restored.tamano, 0.4);
    expect(restored.inicioAutomatico, true);
    expect(restored.evitarSuspension, true);
    expect(restored.animal, 'Capybara');
    expect(restored.autoCerrarNotas, false);
    expect(restored.idioma, 'en');

    final nota = Nota(id: '123', texto: 'Hola mundo', colorValue: 0xFFFFCDD2);
    final restoredNota = Nota.fromJson(nota.toJson());
    expect(restoredNota.id, '123');
    expect(restoredNota.texto, 'Hola mundo');
    expect(restoredNota.colorValue, 0xFFFFCDD2);
  });

  testWidgets('TemporizadorDialog renders quick presets and slider', (tester) async {
    int? selectedMinutes;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TemporizadorDialog(
            onIniciar: (m) => selectedMinutes = m,
            idioma: 'es',
          ),
        ),
      ),
    );
    expect(find.text('25m'), findsOneWidget);
    await tester.tap(find.text('25m'));
    await tester.pump();
    expect(find.text('25'), findsOneWidget);
    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();
    expect(selectedMinutes, 25);
  });
}
