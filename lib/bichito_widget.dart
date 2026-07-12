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
const double _bugH = 170.0;
const double _menuW = 320.0;
const double _totalMenuH = 390.0;

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
  bool _evitarSuspension = false;
  bool _bloquearCursor = false;
  bool _detenidoPorMouse = false;
  bool _arrastrando = false;
  Offset? _pointerDownPos;
  bool _dragActivo = false;

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
    _posY = _screenTop + _screenHeight - 100;
    _mirandoIzq = true;
    await _actualizarPosicionVentana();
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciarCaminata());
  }

  Future<void> _cargarConfiguracion() async {
    final cfg = StorageManager.instance.configuracion;
    _velocidad = cfg.velocidad;
    _opacidadGlobal = cfg.opacidad;
    _evitarSuspension = cfg.evitarSuspension;
    _bloquearCursor = cfg.bloquearCursor;
    if (_evitarSuspension) WindowsServices.setAvoidSleep(true);
    if (_bloquearCursor) _aplicarBloqueoCursor();
  }

  void _iniciarCaminata() {
    _walkTimer?.cancel();
    final interval = (20 / _velocidad.clamp(0.3, 5.0)).round();
    _walkTimer = Timer.periodic(Duration(milliseconds: interval), (_) {
      if (_menuAbierto || _estado != BichitoEstado.caminando || _arrastrando || _detenidoPorMouse) return;
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
      if (_menuAbierto || _estado != BichitoEstado.caminando || !mounted) return;
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
    if (_detenidoPorMouse) return;
    final paso = _velocidad;
    double nuevaX = _posX + (_mirandoIzq ? -paso : paso);
    final leftBound = _screenLeft + _bugW / 2;
    final rightBound = _screenLeft + _screenWidth - _bugW / 2;

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
      if (_menuAbierto) {
        await windowManager.setPosition(Offset(_posX - _menuW / 2, _posY - _totalMenuH));
        await windowManager.setSize(const Size(_menuW, _totalMenuH));
      } else {
        await windowManager.setPosition(Offset(_posX - _bugW / 2, _posY - _bugH));
        await windowManager.setSize(const Size(_bugW, _bugH));
      }
    } catch (_) {}
  }

  void _onTapBichito() {
    _walkTimer?.cancel();
    setState(() {
      _menuAbierto = !_menuAbierto;
      _estado = _menuAbierto ? BichitoEstado.detenido : BichitoEstado.caminando;
      _expresion = _menuAbierto ? Expresion.esperando : Expresion.normal;
    });
    if (!_menuAbierto && !_detenidoPorMouse) _iniciarCaminata();
    _actualizarPosicionVentana();
  }

  void _cerrarMenu() {
    if (_menuAbierto) _onTapBichito();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownPos = event.position;
    _dragActivo = false;
    _walkTimer?.cancel();
    setState(() {
      _estado = BichitoEstado.detenido;
      _expresion = Expresion.esperando;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointerDownPos == null) return;
    if (!_dragActivo) {
      final totalDx = (event.position.dx - _pointerDownPos!.dx).abs();
      final totalDy = (event.position.dy - _pointerDownPos!.dy).abs();
      if (totalDx < 5 && totalDy < 5) return;
      _dragActivo = true;
      setState(() => _arrastrando = true);
    }
    _posX += event.delta.dx;
    _posY += event.delta.dy;
    _posX = _posX.clamp(_screenLeft + _bugW / 2, _screenLeft + _screenWidth - _bugW / 2);
    _posY = _posY.clamp(_screenTop + _bugH, _screenTop + _screenHeight);
    _actualizarPosicionVentana();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_dragActivo) {
      _onTapBichito();
    }
    _arrastrando = false;
    _dragActivo = false;
    _pointerDownPos = null;
  }

  void _aplicarBloqueoCursor() {
    if (_bloquearCursor) {
      WindowsServices.lockCursor(_posX.toInt() - 100, _posY.toInt() - 100, 200, 200);
    } else {
      WindowsServices.unlockCursor();
    }
  }

  void _toggleEvitarSuspension() async {
    final nuevo = !_evitarSuspension;
    WindowsServices.setAvoidSleep(nuevo);
    await StorageManager.instance.updateConfiguracion((cfg) => cfg.evitarSuspension = nuevo);
    setState(() => _evitarSuspension = nuevo);
  }

  void _toggleBloquearCursor() async {
    final nuevo = !_bloquearCursor;
    if (nuevo) _aplicarBloqueoCursor();
    else WindowsServices.unlockCursor();
    await StorageManager.instance.updateConfiguracion((cfg) => cfg.bloquearCursor = nuevo);
    setState(() => _bloquearCursor = nuevo);
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
    if (_detenidoPorMouse || _menuAbierto || _expresion == Expresion.esperando || _expresion == Expresion.alerta) {
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
      if (_ctrlDown && _shiftDown && key.toLowerCase() == 'l') {
        if (_bloquearCursor) _toggleBloquearCursor();
      }
    } else if (type == 'keyup') {
      if (key == 'Control') _ctrlDown = false;
      if (key == 'Shift') _shiftDown = false;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _opacidadGlobal,
      child: Stack(
        children: [
          if (_menuAbierto)
            Positioned(
              left: 0,
              top: 0,
              width: _menuW,
              child: MenuWidget(
                onCerrar: _cerrarMenu,
                evitarSuspensionActivo: _evitarSuspension,
                onToggleEvitarSuspension: _toggleEvitarSuspension,
                onAbrirCarpeta: () => _abrirOpcionCarpeta(context),
                onAbrirPrograma: () => _abrirOpcionPrograma(context),
                onTemporizador: _iniciarTemporizador,
                bloquearCursorActivo: _bloquearCursor,
                onToggleBloquearCursor: _toggleBloquearCursor,
                onNota: () => _abrirOpcionNota(context),
                onConfiguracion: _abrirConfiguracion,
                onSalir: _salir,
              ),
            ),
          Positioned(
            left: _menuAbierto ? _menuW / 2 - _bugW / 2 : 0,
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
                if (_detenidoPorMouse && !_menuAbierto && !_arrastrando) {
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
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                child: SizedBox(
            width: _bugW,
            height: _bugH,
            child: Transform.flip(
                    flipX: _mirandoIzq,
                      child: FittedBox(
                      fit: BoxFit.none,
                      alignment: Alignment.bottomCenter,
                      child: Transform.scale(
                        scale: 0.85,
                        child: Image.asset(_imagenActual),
                      ),
                    ),
                  ),
                ),
              ),
             ),
            ),
          if (!_menuAbierto && _evitarSuspension)
            const Positioned(
              left: _bugW - 20,
              top: 0,
              child: Text('⚡', style: TextStyle(fontSize: 14, color: Colors.black87)),
            ),
          if (!_menuAbierto && _temporizador != null && _temporizador!.activo)
            Positioned(
              left: 0,
              top: _bugH + 2,
              child: StreamBuilder<Duration>(
                stream: _temporizador!.stream,
                initialData: _temporizador!.restante,
                builder: (ctx, snap) {
                  final t = snap.data!;
                  final secs = t.inSeconds;
                  final m = (secs ~/ 60).toString().padLeft(2, '0');
                  final s = (secs % 60).toString().padLeft(2, '0');
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('$m:$s', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  );
                },
              ),
            ),
          ..._notas,
        ],
      ),
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
            child: const Text('+ Agregar carpeta', style: TextStyle(color: Colors.blue)),
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
            child: const Text('+ Agregar programa', style: TextStyle(color: Colors.blue)),
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
  late bool _inicioAutomatico;

  @override
  void initState() {
    super.initState();
    final cfg = StorageManager.instance.configuracion;
    _velocidad = cfg.velocidad;
    _opacidad = cfg.opacidad;
    _inicioAutomatico = cfg.inicioAutomatico;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configuracion'),
      content: SizedBox(
        width: 300,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text('Velocidad del bichito'),
            Slider(value: _velocidad, min: 0.3, max: 3.0, divisions: 27,
              label: _velocidad.toStringAsFixed(1), onChanged: (v) => setState(() => _velocidad = v)),
            const Divider(),
            const Text('Opacidad'),
            Slider(value: _opacidad, min: 0.2, max: 1.0, divisions: 8,
              label: (_opacidad * 100).round().toString(), onChanged: (v) => setState(() => _opacidad = v)),
            const Divider(),
            CheckboxListTile(
              title: const Text('Iniciar con Windows'), value: _inicioAutomatico,
              onChanged: (v) { final val = v ?? false; setState(() => _inicioAutomatico = val); WindowsServices.setAutoStart(val); },
            ),
            const Divider(),
            const Text('Carpetas guardadas:'), ..._buildCarpetasList(),
            const Divider(),
            const Text('Programas guardados:'), ..._buildProgramasList(),
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
      velocidad: _velocidad, apariencia: 0, opacidad: _opacidad,
      inicioAutomatico: _inicioAutomatico,
      evitarSuspension: StorageManager.instance.configuracion.evitarSuspension,
      bloquearCursor: StorageManager.instance.configuracion.bloquearCursor,
    ));
    widget.estado.setState(() {
      widget.estado._velocidad = _velocidad;
      widget.estado._opacidadGlobal = _opacidad;
    });
    widget.estado._iniciarCaminata();
    Navigator.pop(context);
  }
}
