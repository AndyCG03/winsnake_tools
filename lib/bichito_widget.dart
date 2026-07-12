import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'menu_widget.dart';
import 'opciones/nota_rapida.dart';
import 'opciones/temporizador.dart';
import 'storage.dart';
import 'bichito_painter.dart';
import 'servicios/windows_services.dart';

const double _bugW = 290.0;
const double _refH = 194.0; // altura de referencia (img 4) para alinear al pie
const double _menuW = 330.0;
const double _menuH = 310.0;

enum BichitoEstado { caminando, detenido, asustado, saltando }

class BichitoWidget extends StatefulWidget {
  const BichitoWidget({super.key});

  @override
  State<BichitoWidget> createState() => _BichitoWidgetState();
}

class _BichitoWidgetState extends State<BichitoWidget> with WidgetsBindingObserver {
  double _posX = 0;
  double _posY = 0;
  bool _mirandoIzq = false;
  BichitoEstado _estado = BichitoEstado.caminando;
  Expresion _expresion = Expresion.normal;
  int _frame = 0;
  bool _menuAbierto = false;
  TemporizadorState? _temporizador;
  final List<Widget> _notas = [];
  bool _ctrlDown = false;
  bool _shiftDown = false;

  Timer? _walkTimer;
  Timer? _animationTimer;
  Timer? _spontaneousTimer;

  double _screenLeft = 0;
  double _screenTop = 0;
  double _screenWidth = 1920;
  double _screenHeight = 1080;
  double _velocidad = 0.8;
  double _opacidadGlobal = 1.0;
  double _tamano = 0.5;
  bool _evitarSuspension = false;
  bool _detenidoPorMouse = false;
  bool _girando = false;
  int _lastTurnMs = 0;
  static const Map<String, Size> _imageSizes = {
    'assets/img/1.png': Size(291, 139),
    'assets/img/2.png': Size(337, 139),
    'assets/img/3.png': Size(306, 139),
    'assets/img/4.png': Size(261, 194),
    'assets/img/5.png': Size(239, 268),
    'assets/img/6.png': Size(279, 169),
  };
  Size get _curImgSize => _imageSizes[_imagenActual]!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _obtenerDimensionesPantalla();
    _cargarConfiguracion();
    _iniciarAnimacion();
    _iniciarAccionesEspontaneas();
    SystemChannels.keyEvent.setMessageHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _walkTimer?.cancel();
    _animationTimer?.cancel();
    _spontaneousTimer?.cancel();
    _temporizador?.cancel();
    SystemChannels.keyEvent.setMessageHandler(null);
    super.dispose();
  }

  Future<void> _obtenerDimensionesPantalla() async {
    try {
      _screenWidth = WindowsServices.getScreenWidth().toDouble();
      _screenHeight = WindowsServices.getScreenHeight().toDouble();
    } catch (_) {}
    try {
      final primary = await screenRetriever.getPrimaryDisplay();
      if (primary.visiblePosition != null && primary.visibleSize != null) {
        _screenLeft = primary.visiblePosition!.dx;
        _screenTop = primary.visiblePosition!.dy;
        _screenWidth = primary.visibleSize!.width;
        _screenHeight = primary.visibleSize!.height;
      } else {
        _screenLeft = 0;
        _screenTop = 0;
        _screenWidth = primary.size.width;
        _screenHeight = primary.size.height;
      }
    } catch (_) {}
    _posX = _screenLeft + _screenWidth * 0.7;
    _posY = _screenTop + _screenHeight;
    _mirandoIzq = true;
    await _actualizarPosicionVentana();
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciarCaminata());
  }

  Future<void> _cargarConfiguracion() async {
    final cfg = StorageManager.instance.configuracion;
    _velocidad = cfg.velocidad;
    _opacidadGlobal = cfg.opacidad;
    _tamano = cfg.tamano;
    _evitarSuspension = cfg.evitarSuspension;
    if (_evitarSuspension) WindowsServices.setAvoidSleep(true);
  }

  void _iniciarCaminata() {
    _walkTimer?.cancel();
    final interval = (20 / _velocidad.clamp(0.3, 5.0)).round();
    _walkTimer = Timer.periodic(Duration(milliseconds: interval), (_) {
      if (_menuAbierto || _estado != BichitoEstado.caminando || _detenidoPorMouse) return;
      _moverBichito();
    });
  }

  void _iniciarAnimacion() {
    _animationTimer?.cancel();
    _animationTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if ((_estado == BichitoEstado.caminando || _estado == BichitoEstado.saltando) && mounted) {
        setState(() => _frame = (_frame + 1) % 3);
      }
    });
  }

  void _iniciarAccionesEspontaneas() {
    _spontaneousTimer?.cancel();
    _spontaneousTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_menuAbierto || _girando || _estado != BichitoEstado.caminando || !mounted) return;
      final rng = Random().nextInt(100);
      if (rng < 5) {
        setState(() => _expresion = Expresion.esperando);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && !_menuAbierto) setState(() => _expresion = Expresion.normal);
        });
      } else if (rng < 10) {
        setState(() => _estado = BichitoEstado.saltando);
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _estado = BichitoEstado.caminando);
        });
      } else if (rng < 15) {
        setState(() => _estado = BichitoEstado.asustado);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _estado = BichitoEstado.caminando);
        });
      }
    });
  }

  void _moverBichito() {
    if (_detenidoPorMouse || _girando) return;
    final paso = _velocidad;
    double nuevaX = _posX + (_mirandoIzq ? -paso : paso);
    final leftBound = _screenLeft + _bugW / 2;
    final rightBound = _screenLeft + _screenWidth - _bugW / 2;

    // Mostrar 6.png ANTES de llegar a la esquina (sprite de anticipo de giro)
    final margen = paso * 6;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_mirandoIzq && _posX - leftBound < margen && now - _lastTurnMs > 800) {
      _walkTimer?.cancel();
      _walkTimer = null;
      _lastTurnMs = now;
      setState(() => _girando = true);
      _actualizarPosicionVentana();
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() => _girando = false);
        if (!_detenidoPorMouse && !_menuAbierto) _iniciarCaminata();
      });
      return;
    }
    if (!_mirandoIzq && rightBound - _posX < margen && now - _lastTurnMs > 800) {
      _walkTimer?.cancel();
      _walkTimer = null;
      _lastTurnMs = now;
      setState(() => _girando = true);
      _actualizarPosicionVentana();
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() => _girando = false);
        if (!_detenidoPorMouse && !_menuAbierto) _iniciarCaminata();
      });
      return;
    }

    if (nuevaX <= leftBound) {
      nuevaX = leftBound;
      _mirandoIzq = false;
    } else if (nuevaX >= rightBound) {
      nuevaX = rightBound;
      _mirandoIzq = true;
    }
    _posX = nuevaX;
    _actualizarPosicionVentana();
  }

  Future<void> _actualizarPosicionVentana() async {
    try {
      final s = _curImgSize;
      final scale = 0.85 * _tamano;
      final scaledW = s.width * scale;
      final scaledH = _menuAbierto ? s.height * scale : _refH * scale;
      if (_menuAbierto) {
        final totalH = _menuH + scaledH;
        await windowManager.setBounds(Rect.fromLTWH(_posX - _menuW / 2, _posY - totalH, _menuW, totalH));
      } else {
        await windowManager.setBounds(Rect.fromLTWH(_posX - scaledW / 2, _posY - scaledH, scaledW, scaledH));
      }
    } catch (_) {}
  }

  void _onTapBichito() {
    _walkTimer?.cancel();
    final abriendo = !_menuAbierto;
    setState(() {
      _menuAbierto = abriendo;
      _girando = false;
      if (abriendo) {
        _estado = BichitoEstado.detenido;
        _expresion = Expresion.esperando;
      } else {
        _estado = BichitoEstado.caminando;
        _expresion = Expresion.normal;
      }
    });
    if (!abriendo && !_detenidoPorMouse) _iniciarCaminata();
    _actualizarPosicionVentana();
  }

  void _cerrarMenu() {
    if (_menuAbierto) _onTapBichito();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_menuAbierto) return;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_menuAbierto) {
      _onTapBichito();
      return;
    }
    _onTapBichito();
  }

  void _toggleEvitarSuspension() async {
    final nuevo = !_evitarSuspension;
    WindowsServices.setAvoidSleep(nuevo);
    await StorageManager.instance.updateConfiguracion((cfg) => cfg.evitarSuspension = nuevo);
    setState(() => _evitarSuspension = nuevo);
  }

  void _iniciarTemporizador() {
    showDialog(
      context: context,
      builder: (ctx) => TemporizadorDialog(onIniciar: (minutos) {
        setState(() {
          _temporizador = TemporizadorState(
            minutos: minutos,
            onTerminar: () {
              setState(() => _expresion = Expresion.alerta);
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) setState(() => _expresion = Expresion.normal);
              });
            },
          );
          _temporizador!.iniciar();
        });
      }),
    );
  }

  Future<void> _abrirConfiguracion() async {
    await showDialog(context: context, builder: (ctx) => _ConfigDialog(estado: this));
  }

  String get _imagenActual {
    if (_menuAbierto) return 'assets/img/5.png';
    if (_girando) return 'assets/img/6.png';
    if (_detenidoPorMouse || _expresion == Expresion.esperando || _expresion == Expresion.alerta) {
      return 'assets/img/4.png';
    }
    return 'assets/img/${_frame + 1}.png';
  }

  void _salir() {
    _walkTimer?.cancel();
    _animationTimer?.cancel();
    _spontaneousTimer?.cancel();
    _temporizador?.cancel();
    WindowsServices.cleanup();
    windowManager.close();
  }

  Future<dynamic> _handleKeyEvent(dynamic message) async {
    final map = message as Map<String, dynamic>;
    final key = map['key'] as String? ?? '';
    final type = map['type'] as String? ?? '';
    if (type == 'keydown') {
      if (key == 'Control') _ctrlDown = true;
      if (key == 'Shift') _shiftDown = true;
    } else if (type == 'keyup') {
      if (key == 'Control') _ctrlDown = false;
      if (key == 'Shift') _shiftDown = false;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = _curImgSize;
    final scale = 0.85 * _tamano;
    final scaledW = s.width * scale;
    final scaledH = _refH * scale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Menú arriba (solo visible cuando está abierto)
        if (_menuAbierto)
          SizedBox(
            width: _menuW,
            child: MenuWidget(
              onCerrar: _cerrarMenu,
              evitarSuspensionActivo: _evitarSuspension,
              onToggleEvitarSuspension: _toggleEvitarSuspension,
              onAbrirCarpeta: () => _abrirOpcionCarpeta(context),
              onAbrirPrograma: () => _abrirOpcionPrograma(context),
              onTemporizador: _iniciarTemporizador,
              onNota: () => _abrirOpcionNota(context),
              onConfiguracion: _abrirConfiguracion,
              onSalir: _salir,
            ),
          ),
        // Serpiente abajo (siempre visible)
        Opacity(
          opacity: _opacidadGlobal,
          child: SizedBox(
            width: _menuAbierto ? _menuW : scaledW,
            height: scaledH,
            child: Stack(
              children: [
                Positioned(
                  left: _menuAbierto ? (_menuW - scaledW) / 2 : 0,
                  bottom: 0,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onHover: (_) {
                      if (_estado == BichitoEstado.caminando && !_detenidoPorMouse && !_menuAbierto) {
                        setState(() {
                          _estado = BichitoEstado.detenido;
                          _expresion = Expresion.esperando;
                          _detenidoPorMouse = true;
                        });
                        _walkTimer?.cancel();
                      }
                    },
                    onExit: (_) {
                      if (_detenidoPorMouse && !_menuAbierto) {
                        setState(() {
                          _estado = BichitoEstado.caminando;
                          _expresion = Expresion.normal;
                          _detenidoPorMouse = false;
                        });
                        _iniciarCaminata();
                      }
                    },
                    child: Listener(
                      onPointerDown: _onPointerDown,
                      onPointerUp: _onPointerUp,
                      child: SizedBox(
                        width: scaledW,
                        height: scaledH,
                        child: Transform.flip(
                          flipX: _mirandoIzq,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Image.asset(_imagenActual),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ],
    );
  }

  // --- Dialog methods (same as before) ---
  void _abrirOpcionCarpeta(BuildContext context) {
    final carpetas = StorageManager.instance.carpetas;
    if (carpetas.isEmpty) {
      _mostrarDialogoAgregarCarpeta(context, (String path) {
        StorageManager.instance.setCarpetas([...StorageManager.instance.carpetas, path]);
      });
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Abrir carpeta'),
        children: [
          ...carpetas.map((c) => SimpleDialogOption(
            onPressed: () { WindowsServices.openFolder(c); Navigator.pop(ctx); },
            child: Text(c),
          )),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _mostrarDialogoAgregarCarpeta(context, (String path) {
                StorageManager.instance.setCarpetas([...StorageManager.instance.carpetas, path]);
              });
            },
            child: Text('+ Agregar carpeta', style: TextStyle(color: Theme.of(ctx).colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoAgregarCarpeta(BuildContext context, void Function(String) onAgregar) {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar carpeta'),
        content: TextField(controller: ctl, decoration: const InputDecoration(hintText: 'Ruta de la carpeta')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () {
            final p = ctl.text.trim();
            if (p.isNotEmpty) onAgregar(p);
            Navigator.pop(ctx);
          }, child: const Text('Agregar')),
        ],
      ),
    );
  }

  void _abrirOpcionPrograma(BuildContext context) {
    final programas = StorageManager.instance.programas;
    if (programas.isEmpty) { _mostrarDialogoAgregarPrograma(context); return; }
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Abrir programa'),
        children: [
          ...programas.map((p) => SimpleDialogOption(
            onPressed: () { WindowsServices.openProgram(p); Navigator.pop(ctx); },
            child: Text(p.split('\\').last),
          )),
          SimpleDialogOption(
            onPressed: () { Navigator.pop(ctx); _mostrarDialogoAgregarPrograma(context); },
            child: Text('+ Agregar programa', style: TextStyle(color: Theme.of(ctx).colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoAgregarPrograma(BuildContext context) {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar programa'),
        content: TextField(controller: ctl, decoration: const InputDecoration(hintText: 'Ruta del .exe')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () async {
            final p = ctl.text.trim();
            if (p.isNotEmpty) {
              await StorageManager.instance.setProgramas([...StorageManager.instance.programas, p]);
            }
            Navigator.pop(ctx);
          }, child: const Text('Agregar')),
        ],
      ),
    );
  }

  void _abrirOpcionNota(BuildContext context) {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nota rapida'),
        content: TextField(controller: ctl, maxLines: 3, decoration: const InputDecoration(hintText: 'Escribe tu nota aqui...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () {
            final t = ctl.text.trim();
            if (t.isNotEmpty) {
              NotaService.guardarNota(t);
              setState(() {
                _notas.add(NotaWidget(texto: t, onCerrar: () => setState(() => _notas.clear())));
              });
            }
            Navigator.pop(ctx);
          }, child: const Text('Guardar')),
        ],
      ),
    );
  }
}

class _ConfigDialog extends StatefulWidget {
  final _BichitoWidgetState estado;
  const _ConfigDialog({required this.estado});

  @override
  State<_ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends State<_ConfigDialog> {
  late double _velocidad;
  late double _opacidad;
  late double _tamano;
  late bool _inicioAutomatico;

  @override
  void initState() {
    super.initState();
    final cfg = StorageManager.instance.configuracion;
    _velocidad = cfg.velocidad;
    _opacidad = cfg.opacidad;
    _tamano = cfg.tamano;
    _inicioAutomatico = cfg.inicioAutomatico;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configuración'),
      content: SizedBox(
        width: 320,
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            const Text('Velocidad'),
            Slider(value: _velocidad, min: 0.3, max: 3.0, divisions: 27,
              label: _velocidad.toStringAsFixed(1), onChanged: (v) => setState(() => _velocidad = v)),
            const Divider(),
            const Text('Opacidad'),
            Slider(value: _opacidad, min: 0.2, max: 1.0, divisions: 8,
              label: (_opacidad * 100).round().toString(), onChanged: (v) => setState(() => _opacidad = v)),
            const Divider(),
            const Text('Tamaño'),
            Slider(value: _tamano, min: 0.4, max: 2.0, divisions: 16,
              label: '${(_tamano * 100).round()}%', onChanged: (v) => setState(() => _tamano = v)),
            const Divider(),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Iniciar con Windows'),
              value: _inicioAutomatico,
              onChanged: (v) {
                final val = v ?? false;
                setState(() => _inicioAutomatico = val);
                WindowsServices.setAutoStart(val);
              },
            ),
            const Divider(),
            const Text('Carpetas guardadas:'),
            ..._buildCarpetasList(),
            const Divider(),
            const Text('Programas guardados:'),
            ..._buildProgramasList(),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }

  List<Widget> _buildCarpetasList() {
    final list = StorageManager.instance.carpetas;
    if (list.isEmpty) return [const Text('  (ninguna)', style: TextStyle(color: Colors.grey))];
    return list.map((c) => ListTile(dense: true, title: Text(c, style: const TextStyle(fontSize: 12)),
      trailing: IconButton(icon: const Icon(Icons.delete, size: 16),
        onPressed: () { StorageManager.instance.setCarpetas(list.where((x) => x != c).toList()); setState(() {}); }),
    )).toList();
  }

  List<Widget> _buildProgramasList() {
    final list = StorageManager.instance.programas;
    if (list.isEmpty) return [const Text('  (ninguna)', style: TextStyle(color: Colors.grey))];
    return list.map((p) => ListTile(dense: true, title: Text(p.split('\\').last, style: const TextStyle(fontSize: 12)),
      subtitle: Text(p, style: const TextStyle(fontSize: 10)),
      trailing: IconButton(icon: const Icon(Icons.delete, size: 16),
        onPressed: () { StorageManager.instance.setProgramas(list.where((x) => x != p).toList()); setState(() {}); }),
    )).toList();
  }

  void _guardar() {
    StorageManager.instance.setConfiguracion(Configuracion(
      velocidad: _velocidad,
      apariencia: 0,
      opacidad: _opacidad,
      tamano: _tamano,
      inicioAutomatico: _inicioAutomatico,
      evitarSuspension: StorageManager.instance.configuracion.evitarSuspension,
    ));
    widget.estado.setState(() {
      widget.estado._velocidad = _velocidad;
      widget.estado._opacidadGlobal = _opacidad;
      widget.estado._tamano = _tamano;
    });
    widget.estado._iniciarCaminata();
    Navigator.pop(context);
  }
}
