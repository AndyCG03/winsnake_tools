import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class Configuracion {
  double velocidad;
  int apariencia;
  double opacidad;
  double tamano;
  bool inicioAutomatico;
  bool evitarSuspension;
  bool bloquearCursor;

  Configuracion({
    this.velocidad = 1.0,
    this.apariencia = 0,
    this.opacidad = 1.0,
    this.tamano = 1.0,
    this.inicioAutomatico = false,
    this.evitarSuspension = false,
    this.bloquearCursor = false,
  });

  Map<String, dynamic> toJson() => {
        'velocidad': velocidad,
        'apariencia': apariencia,
        'opacidad': opacidad,
        'tamano': tamano,
        'inicioAutomatico': inicioAutomatico,
        'evitarSuspension': evitarSuspension,
        'bloquearCursor': bloquearCursor,
      };

  factory Configuracion.fromJson(Map<String, dynamic> json) => Configuracion(
        velocidad: (json['velocidad'] as num?)?.toDouble() ?? 1.0,
        apariencia: json['apariencia'] as int? ?? 0,
        opacidad: (json['opacidad'] as num?)?.toDouble() ?? 1.0,
        tamano: (json['tamano'] as num?)?.toDouble() ?? 1.0,
        inicioAutomatico: json['inicioAutomatico'] as bool? ?? false,
        evitarSuspension: json['evitarSuspension'] as bool? ?? false,
        bloquearCursor: json['bloquearCursor'] as bool? ?? false,
      );
}

class Nota {
  String texto;
  double x;
  double y;

  Nota({required this.texto, this.x = 100, this.y = 100});

  Map<String, dynamic> toJson() => {'texto': texto, 'x': x, 'y': y};

  factory Nota.fromJson(Map<String, dynamic> json) => Nota(
        texto: json['texto'] as String? ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 100,
        y: (json['y'] as num?)?.toDouble() ?? 100,
      );
}

class StorageManager extends ChangeNotifier {
  static final StorageManager instance = StorageManager._();
  StorageManager._();

  File? _file;
  Map<String, dynamic> _data = {};

  Future<void> init() async {
    final dir = Directory(
        '${Platform.environment['APPDATA'] ?? '.'}${Platform.pathSeparator}bichito_widget');
    if (!await dir.exists()) await dir.create(recursive: true);
    _file = File('${dir.path}${Platform.pathSeparator}storage.json');
    if (await _file!.exists()) {
      final content = await _file!.readAsString();
      if (content.isNotEmpty) {
        _data = json.decode(content) as Map<String, dynamic>;
      }
    }
  }

  Future<void> _save() async {
    if (_file == null) return;
    await _file!.writeAsString(json.encode(_data));
  }

  List<String> get carpetas =>
      List<String>.from(_data['carpetas'] ?? []);

  Future<void> setCarpetas(List<String> list) async {
    _data['carpetas'] = list;
    await _save();
    notifyListeners();
  }

  List<String> get programas =>
      List<String>.from(_data['programas'] ?? []);

  Future<void> setProgramas(List<String> list) async {
    _data['programas'] = list;
    await _save();
    notifyListeners();
  }

  List<Nota> get notas {
    final list = _data['notas'] as List? ?? [];
    return list.map((e) => Nota.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> setNotas(List<Nota> list) async {
    _data['notas'] = list.map((e) => e.toJson()).toList();
    await _save();
    notifyListeners();
  }

  Configuracion get configuracion {
    final map = _data['configuracion'] as Map<String, dynamic>?;
    return map != null ? Configuracion.fromJson(map) : Configuracion();
  }

  Future<void> setConfiguracion(Configuracion cfg) async {
    _data['configuracion'] = cfg.toJson();
    await _save();
    notifyListeners();
  }

  Future<void> updateConfiguracion(void Function(Configuracion) update) async {
    final cfg = configuracion;
    update(cfg);
    await setConfiguracion(cfg);
  }
}
