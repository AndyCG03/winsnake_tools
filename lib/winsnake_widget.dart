import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'menu_widget.dart';
import 'opciones/nota_rapida.dart';
import 'opciones/temporizador.dart';
import 'storage.dart';
import 'winsnake_painter.dart';
import 'servicios/windows_services.dart';

const double _refW = 337.0;
const double _refH = 292.0;
const double _menuW = 330.0;
const double _menuH = 350.0;

enum WinSnakeEstado { caminando, detenido, asustado, saltando }

class WinSnakeWidget extends StatefulWidget {
  const WinSnakeWidget({super.key});

  @override
  State<WinSnakeWidget> createState() => _WinSnakeWidgetState();
}

class _WinSnakeWidgetState extends State<WinSnakeWidget> with WidgetsBindingObserver {
  double _posX = 0;
  double _posY = 0;
  bool _mirandoIzq = false;
  WinSnakeEstado _estado = WinSnakeEstado.caminando;
  Expresion _expresion = Expresion.normal;
  int _frame = 0;
  bool _menuAbierto = false;
  TemporizadorState? _temporizador;
  StreamSubscription<Duration>? _timerSub;
  Duration? _tiempoRestante;
  List<Nota> _notasData = [];
  Timer? _walkTimer;
  Timer? _animationTimer;
  Timer? _spontaneousTimer;
  Timer? _sleepTimer;

  double _screenLeft = 0;
  double _screenTop = 0;
  double _screenWidth = 1920;
  double _screenHeight = 1080;
  double _screenBottom = 1080; // bottom edge of visible area (excl. taskbar)
  double _velocidad = 0.8;
  double _opacidadGlobal = 1.0;
  double _tamano = 0.5;
  bool _evitarSuspension = false;
  String _animal = 'serpiente';
  bool _detenidoPorMouse = false;
  bool _girando = false;
  bool _durmiendo = false;
  int _sleepFrame = 0;
  int _lastTurnMs = 0;
  static const Map<String, Size> _serpienteSizes = {
    '1.png': Size(291, 139),
    '2.png': Size(337, 139),
    '3.png': Size(306, 139),
    '4.png': Size(261, 194),
    '5.png': Size(260, 292),
    '6.png': Size(279, 169),
    '7.png': Size(262, 204),
    '8.png': Size(260, 144),
    '9.png': Size(260, 170),
  };
  static const Map<String, Size> _capibaraSizes = {
    '1.png': Size(258, 176),
    '2.png': Size(258, 174),
    '3.png': Size(250, 176),
    '4.png': Size(214, 230),
    '5.png': Size(224, 204),
    '6.png': Size(230, 200),
    '7.png': Size(274, 152),
    '8.png': Size(312, 176),
    '9.png': Size(294, 182),
  };
  Map<String, Size> get _currentSizes {
    switch (_animal) {
      case 'Capybara': return _capibaraSizes;
      default: return _serpienteSizes;
    }
  }
  String get _imagenNombre {
    if (_menuAbierto) return '5.png';
    if (_durmiendo) return '${7 + _sleepFrame}.png';
    if (_girando) return '6.png';
    if (_detenidoPorMouse || _expresion == Expresion.esperando || _expresion == Expresion.alerta) {
      return '4.png';
    }
    return '${_frame + 1}.png';
  }
  String get _imagenActual => 'assets/img/$_animal/$_imagenNombre';
  Size get _curImgSize => _currentSizes[_imagenNombre]!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      final w = WindowsServices.getScreenWidth().toDouble();
      final h = WindowsServices.getScreenHeight().toDouble();
      _screenWidth = w;
      _screenHeight = h;
      _screenBottom = h - 50;
      _posX = w * 0.7;
      _posY = _screenBottom;
      _actualizarPosicionVentana();
    } catch (_) {}
    _obtenerDimensionesPantalla();
    _cargarConfiguracion();
    _iniciarAnimacion();
    _iniciarAccionesEspontaneas();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _walkTimer?.cancel();
    _animationTimer?.cancel();
    _spontaneousTimer?.cancel();
    _temporizador?.cancel();
    _timerSub?.cancel();
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
    } catch (_) {
      _screenLeft = 0;
      _screenTop = 0;
    }
    _screenBottom = _screenTop + _screenHeight;
    if (_screenTop == 0 && _screenHeight >= 700) {
      try {
        final fullH = WindowsServices.getScreenHeight().toDouble();
        if (_screenHeight == fullH) _screenBottom = _screenTop + fullH - 50;
      } catch (_) {}
    }
    _posX = _screenLeft + _screenWidth * 0.7;
    _posY = _screenBottom;
    _mirandoIzq = true;
    await _actualizarPosicionVentana();
    await _cargarNotas();
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciarCaminata());
  }

  Future<void> _cargarNotas() async {
    final notas = await NotaService.cargarNotas();
    if (mounted) {
      final ids = <String>{};
      final unicas = <Nota>[];
      for (final n in notas) {
        if (ids.add(n.id)) unicas.add(n);
      }
      setState(() => _notasData = unicas);
    }
  }

  Future<void> _cargarConfiguracion() async {
    final cfg = StorageManager.instance.configuracion;
    _velocidad = cfg.velocidad;
    _opacidadGlobal = cfg.opacidad;
    _tamano = cfg.tamano;
    _evitarSuspension = cfg.evitarSuspension;
    _animal = cfg.animal;
    if (_evitarSuspension) WindowsServices.setAvoidSleep(true);
    await _actualizarPosicionVentana();
  }

  void _iniciarCaminata() {
    _walkTimer?.cancel();
    if (_durmiendo) return;
    final interval = (20 / _velocidad.clamp(0.3, 5.0)).round();
    _walkTimer = Timer.periodic(Duration(milliseconds: interval), (_) {
      if (_menuAbierto || _durmiendo || _estado != WinSnakeEstado.caminando || _detenidoPorMouse) return;
      _moverSnake();
    });
  }

  void _iniciarAnimacion() {
    _animationTimer?.cancel();
    _animationTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if ((_estado == WinSnakeEstado.caminando || _estado == WinSnakeEstado.saltando) && !_durmiendo && mounted) {
        setState(() => _frame = (_frame + 1) % 3);
      }
    });
  }

  void _iniciarAccionesEspontaneas() {
    _spontaneousTimer?.cancel();
    _spontaneousTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_menuAbierto || _girando || _durmiendo || _estado != WinSnakeEstado.caminando || !mounted) return;
      final rng = Random().nextInt(100);
      if (rng < 5) {
        setState(() => _expresion = Expresion.esperando);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && !_menuAbierto) setState(() => _expresion = Expresion.normal);
        });
      } else if (rng < 10) {
        setState(() => _estado = WinSnakeEstado.saltando);
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _estado = WinSnakeEstado.caminando);
        });
      } else if (rng < 15) {
        setState(() => _estado = WinSnakeEstado.asustado);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _estado = WinSnakeEstado.caminando);
        });
      }
    });
  }

  void _moverSnake() {
    if (_detenidoPorMouse || _girando) return;
    final paso = _velocidad;
    double nuevaX = _posX + (_mirandoIzq ? -paso : paso);
    final contW = _refW * _tamano;
    final leftBound = _screenLeft + contW / 2;
    final rightBound = _screenLeft + _screenWidth - contW / 2;

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
      final contW = (_refW * _tamano + 0.5).ceilToDouble();
      final contH = (_refH * _tamano + 0.5).ceilToDouble();
      _posY = _posY.clamp(_screenTop + contH, _screenBottom);
      if (_menuAbierto) {
        const gap = 20.0;
        final totalH = _menuH + gap + contH;
        await windowManager.setBounds(Rect.fromLTWH(_posX - _menuW / 2, _posY - totalH, _menuW, totalH));
      } else {
        await windowManager.setBounds(Rect.fromLTWH(_posX - contW / 2, _posY - contH, contW, contH));
      }
    } catch (_) {}
  }

  void _onTapSnake() {
    _walkTimer?.cancel();
    final abriendo = !_menuAbierto;
    setState(() {
      _menuAbierto = abriendo;
      _girando = false;
      if (abriendo) {
        _estado = WinSnakeEstado.detenido;
        _expresion = Expresion.esperando;
      } else if (!_durmiendo) {
        _estado = WinSnakeEstado.caminando;
        _expresion = Expresion.normal;
      }
    });
    if (!abriendo && !_detenidoPorMouse && !_durmiendo) _iniciarCaminata();
    _actualizarPosicionVentana();
  }

  void _cerrarMenu() {
    if (_menuAbierto) _onTapSnake();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_menuAbierto) return;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_menuAbierto) {
      _onTapSnake();
      return;
    }
    _onTapSnake();
  }

  void _toggleEvitarSuspension() async {
    final nuevo = !_evitarSuspension;
    WindowsServices.setAvoidSleep(nuevo);
    await StorageManager.instance.updateConfiguracion((cfg) => cfg.evitarSuspension = nuevo);
    setState(() => _evitarSuspension = nuevo);
  }

  void _toggleDormir() {
    final nuevo = !_durmiendo;
    _sleepTimer?.cancel();
    if (nuevo) {
      _walkTimer?.cancel();
      _spontaneousTimer?.cancel();
      _sleepFrame = 0;
      _sleepTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        if (mounted) setState(() => _sleepFrame = (_sleepFrame + 1) % 3);
      });
    } else {
      if (!_menuAbierto && !_detenidoPorMouse) _iniciarCaminata();
      _iniciarAccionesEspontaneas();
    }
    setState(() => _durmiendo = nuevo);
    _actualizarPosicionVentana();
  }

  void _iniciarTemporizador() {
    showDialog(
      context: context,
      builder: (ctx) => TemporizadorDialog(onIniciar: (minutos) {
        setState(() {
          _temporizador?.cancel();
          _temporizador = TemporizadorState(
            minutos: minutos,
            onTerminar: () {
              setState(() {
                _tiempoRestante = null;
                _expresion = Expresion.alerta;
              });
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) setState(() => _expresion = Expresion.normal);
              });
            },
          );
          _temporizador!.iniciar();
          _timerSub?.cancel();
          _timerSub = _temporizador!.stream.listen((d) {
            if (mounted) setState(() => _tiempoRestante = d);
          });
        });
      }),
    );
  }

  Future<void> _abrirConfiguracion() async {
    await showDialog(context: context, builder: (ctx) => _ConfigDialog(estado: this));
  }

  void _salir() {
    _walkTimer?.cancel();
    _animationTimer?.cancel();
    _spontaneousTimer?.cancel();
    _sleepTimer?.cancel();
    _temporizador?.cancel();
    _timerSub?.cancel();
    WindowsServices.cleanup();
    windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
    final s = _curImgSize;
    final contW = (_refW * _tamano).ceilToDouble();
    final contH = (_refH * _tamano).ceilToDouble();
    final imgW = s.width * _tamano;
    final imgH = s.height * _tamano;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_menuAbierto) ...[
          SizedBox(
            height: _menuH,
            child: MenuWidget(
              onCerrar: _cerrarMenu,
              evitarSuspensionActivo: _evitarSuspension,
              onToggleEvitarSuspension: _toggleEvitarSuspension,
              durmiendoActivo: _durmiendo,
              onToggleDormir: _toggleDormir,
              onAbrirCarpeta: () => _abrirOpcionCarpeta(context),
              onAbrirPrograma: () => _abrirOpcionPrograma(context),
              onTemporizador: _iniciarTemporizador,
              onNota: () => _abrirOpcionNota(context),
              onConfiguracion: _abrirConfiguracion,
              onSalir: _salir,
            ),
          ),
          const SizedBox(height: 20),
        ],
        Opacity(
          opacity: _opacidadGlobal,
          child: Listener(
            onPointerDown: (_) {},
            child: SizedBox(
              width: _menuAbierto ? _menuW : contW,
              height: contH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Timer countdown
                  if (_tiempoRestante != null && _tiempoRestante!.inSeconds > 0 && !_menuAbierto)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_tiempoRestante!.inMinutes}:${(_tiempoRestante!.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                  // Notes
                  ..._notasData.map((n) => NotaWidget(
                    key: ValueKey(n.id),
                    nota: n,
                    onCerrar: () async {
                      await NotaService.eliminarNota(n.id);
                      _cargarNotas();
                    },
                    onMover: (nota) async {
                      await NotaService.actualizarNota(nota);
                      _cargarNotas();
                    },
                  )),
                  Positioned(
                    left: _menuAbierto ? (_menuW - imgW) / 2 : (contW - imgW) / 2,
                    bottom: 0,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onHover: (_) {
                        if (_estado == WinSnakeEstado.caminando && !_detenidoPorMouse && !_menuAbierto) {
                          setState(() {
                            _estado = WinSnakeEstado.detenido;
                            _expresion = Expresion.esperando;
                            _detenidoPorMouse = true;
                          });
                          _walkTimer?.cancel();
                        }
                      },
                      onExit: (_) {
                        if (_detenidoPorMouse && !_menuAbierto) {
                          setState(() {
                            _estado = WinSnakeEstado.caminando;
                            _expresion = Expresion.normal;
                            _detenidoPorMouse = false;
                          });
                          _iniciarCaminata();
                        }
                      },
                      child: Listener(
                        onPointerDown: _onPointerDown,
                        onPointerUp: _onPointerUp,
                        child: Transform.flip(
                          flipX: _mirandoIzq,
                          child: Image.asset(_imagenActual, width: imgW, height: imgH),
                        ),
                      ),
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
          TextButton(onPressed: () async {
            final t = ctl.text.trim();
            if (t.isNotEmpty) {
              await NotaService.guardarNota(t);
              await _cargarNotas();
              if (ctx.mounted) Navigator.pop(ctx);
            } else {
              Navigator.pop(ctx);
            }
          }, child: const Text('Guardar')),
        ],
      ),
    );
  }
}

class _ConfigDialog extends StatefulWidget {
  final _WinSnakeWidgetState estado;
  const _ConfigDialog({required this.estado});

  @override
  State<_ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends State<_ConfigDialog> {
  late double _velocidad;
  late double _opacidad;
  late double _tamano;
  late bool _inicioAutomatico;
  late String _animal;

  @override
  void initState() {
    super.initState();
    final cfg = StorageManager.instance.configuracion;
    _velocidad = cfg.velocidad;
    _opacidad = cfg.opacidad;
    _tamano = cfg.tamano;
    _inicioAutomatico = cfg.inicioAutomatico;
    _animal = cfg.animal;
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
            const Text('Mascota'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'serpiente', label: Text('Serpiente')),
                  ButtonSegment(value: 'Capybara', label: Text('Capybara')),
                ],
                selected: {_animal},
                onSelectionChanged: (v) => setState(() => _animal = v.first),
              ),
            ),
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
      animal: _animal,
    ));
    widget.estado.setState(() {
      widget.estado._velocidad = _velocidad;
      widget.estado._opacidadGlobal = _opacidad;
      widget.estado._tamano = _tamano;
      widget.estado._animal = _animal;
    });
    widget.estado._iniciarCaminata();
    Navigator.pop(context);
  }
}
