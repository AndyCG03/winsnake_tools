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
import 'servicios/windows_services.dart';
import 'traduccion.dart';

enum Expresion { normal, durmiendo, esperando, alerta }

const double _refW = 337.0;
const double _refH = 292.0;
const double _menuW = 330.0;
const double _menuH = 350.0;
const double _notaCardH = 80.0;

enum WinSnakeEstado { caminando, detenido, asustado, saltando }

class WinSnakeWidget extends StatefulWidget {
  const WinSnakeWidget({super.key});

  @override
  State<WinSnakeWidget> createState() => _WinSnakeWidgetState();
}

class _WinSnakeWidgetState extends State<WinSnakeWidget> with WidgetsBindingObserver {
  double _posX = 0;
  double _posY = 0;
  bool _mirandoIzq = true;
  WinSnakeEstado _estado = WinSnakeEstado.caminando;
  Expresion _expresion = Expresion.normal;
  int _frame = 0;
  bool _menuAbierto = false;
  TemporizadorState? _temporizador;
  StreamSubscription<Duration>? _timerSub;
  Duration? _tiempoRestante;
  bool _alertaTiempoActiva = false;
  List<Nota> _notasData = [];
  int _notaPagina = -1;
  Timer? _walkTimer;
  Timer? _animationTimer;
  Timer? _spontaneousTimer;
  Timer? _sleepTimer;
  Timer? _autoCerrarTimer;
  Timer? _metricsDebounce;
  bool _autoCerrarNotas = false;
  String _idioma = 'es';
  bool _initialRefreshDone = false;

  double _screenLeft = 0;
  double _screenTop = 0;
  double _screenWidth = 1920;
  double _screenHeight = 1080;
  double _screenBottom = 1080; // bottom edge of visible area (excl. taskbar)
  double _velocidad = 0.8;
  double _opacidadGlobal = 1.0;
  double _tamano = 0.5;
  bool _evitarSuspension = false;
  double _walkStep = 0.8;
  double _lastCommitX = 0;
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
      case 'Capybara':
        return _capibaraSizes;
      default:
        return _serpienteSizes;
    }
  }

  String get _imagenNombre {
    if (_menuAbierto || _estado == WinSnakeEstado.saltando) return '5.png';
    if (_durmiendo) return '${7 + _sleepFrame}.png';
    if (_girando) return '6.png';
    if (_detenidoPorMouse ||
        _estado == WinSnakeEstado.asustado ||
        _expresion == Expresion.esperando ||
        _expresion == Expresion.alerta) {
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
    _cargarConfiguracionSync();
    _cargarNotasSync();
    try {
      final w = WindowsServices.getScreenWidth().toDouble();
      final h = WindowsServices.getScreenHeight().toDouble();
      _screenWidth = w;
      _screenHeight = h;
      _screenBottom = h - 50;
      _posX = w * 0.7;
      _posY = _screenBottom;
      _lastCommitX = _posX;
    } catch (_) {}
    _obtenerDimensionesPantalla();
    _iniciarAnimacion();
    _iniciarAccionesEspontaneas();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheImages();
  }

  @override
  void didChangeMetrics() {
    _metricsDebounce?.cancel();
    _metricsDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _obtenerDimensionesPantalla(resetPositionX: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _walkTimer?.cancel();
    _animationTimer?.cancel();
    _spontaneousTimer?.cancel();
    _sleepTimer?.cancel();
    _temporizador?.cancel();
    _timerSub?.cancel();
    _autoCerrarTimer?.cancel();
    _metricsDebounce?.cancel();
    super.dispose();
  }

  void _cargarConfiguracionSync() {
    final cfg = StorageManager.instance.configuracion;
    _velocidad = cfg.velocidad;
    _opacidadGlobal = cfg.opacidad;
    _tamano = cfg.tamano;
    _evitarSuspension = cfg.evitarSuspension;
    _animal = cfg.animal;
    _autoCerrarNotas = cfg.autoCerrarNotas;
    _idioma = cfg.idioma;
    if (_evitarSuspension) WindowsServices.setAvoidSleep(true);
  }

  void _cargarNotasSync() {
    final notas = StorageManager.instance.notas;
    final ids = <String>{};
    final unicas = <Nota>[];
    for (final n in notas) {
      if (ids.add(n.id)) unicas.add(n);
    }
    _notasData = unicas;
    if (_notaPagina >= _notasData.length) {
      _notaPagina = -1;
    }
  }

  Future<void> _obtenerDimensionesPantalla({bool resetPositionX = true}) async {
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
    final contW = (_refW * _tamano + 0.5).ceilToDouble();
    if (resetPositionX) {
      _posX = _screenLeft + _screenWidth * 0.7;
      _mirandoIzq = true;
    } else {
      final leftBound = _screenLeft + contW / 2;
      final rightBound = _screenLeft + _screenWidth - contW / 2;
      _posX = _posX.clamp(leftBound, rightBound);
    }
    _posY = _screenBottom;
    _lastCommitX = _posX;
    final needsRefresh = !_initialRefreshDone;
    _initialRefreshDone = true;
    await _actualizarPosicionVentana(forceRefresh: needsRefresh);
    if (!mounted) return;
    setState(() {});
    if (!_menuAbierto && !_durmiendo && !_detenidoPorMouse) {
      _iniciarCaminata();
    }
  }

  Future<void> _precacheImages() async {
    for (int i = 1; i <= 9; i++) {
      if (!mounted) return;
      final asset = AssetImage('assets/img/$_animal/$i.png');
      try {
        await precacheImage(asset, context);
      } catch (_) {}
    }
  }

  Future<void> _cargarNotas() async {
    final notas = await NotaService.cargarNotas();
    if (mounted) {
      final ids = <String>{};
      final unicas = <Nota>[];
      for (final n in notas) {
        if (ids.add(n.id)) unicas.add(n);
      }
      setState(() {
        _notasData = unicas;
        if (_notaPagina >= _notasData.length) {
          _notaPagina = _notasData.isEmpty ? -1 : _notasData.length - 1;
        }
      });
      await _actualizarPosicionVentana();
      if (unicas.isEmpty && _detenidoPorMouse && !_menuAbierto && !_durmiendo) {
        setState(() {
          _estado = WinSnakeEstado.caminando;
          _expresion = Expresion.normal;
          _detenidoPorMouse = false;
        });
        _iniciarCaminata();
      }
    }
  }

  void _iniciarCaminata() {
    _walkTimer?.cancel();
    if (_durmiendo) return;
    final rawInterval = 20.0 / _velocidad.clamp(0.3, 5.0);
    final intervalMs = rawInterval.clamp(16.0, 66.0).round();
    _walkStep = _velocidad * (intervalMs / rawInterval);
    _walkTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
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
      if (_menuAbierto || _girando || _durmiendo || _detenidoPorMouse || _estado != WinSnakeEstado.caminando || !mounted) return;
      final rng = Random().nextInt(100);
      if (rng < 5) {
        setState(() => _expresion = Expresion.esperando);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && !_menuAbierto && !_durmiendo && !_alertaTiempoActiva) {
            setState(() => _expresion = Expresion.normal);
          }
        });
      } else if (rng < 10) {
        setState(() => _estado = WinSnakeEstado.saltando);
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted && !_menuAbierto && !_durmiendo && !_detenidoPorMouse) {
            setState(() => _estado = WinSnakeEstado.caminando);
          }
        });
      } else if (rng < 15) {
        setState(() => _estado = WinSnakeEstado.asustado);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_menuAbierto && !_durmiendo && !_detenidoPorMouse) {
            setState(() => _estado = WinSnakeEstado.caminando);
          }
        });
      }
    });
  }

  void _moverSnake() {
    if (_detenidoPorMouse || _girando) return;
    final paso = _walkStep;
    double nuevaX = _posX + (_mirandoIzq ? -paso : paso);
    final contW = (_refW * _tamano + 0.5).ceilToDouble();
    final leftBound = _screenLeft + contW / 2;
    final rightBound = _screenLeft + _screenWidth - contW / 2;

    final margen = paso * 6;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_mirandoIzq && _posX - leftBound < margen && now - _lastTurnMs > 800) {
      _lastTurnMs = now;
      _lastCommitX = _posX;
      setState(() => _girando = true);
      _actualizarPosicionVentana();
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() => _girando = false);
      });
      return;
    }
    if (!_mirandoIzq && rightBound - _posX < margen && now - _lastTurnMs > 800) {
      _lastTurnMs = now;
      _lastCommitX = _posX;
      setState(() => _girando = true);
      _actualizarPosicionVentana();
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() => _girando = false);
      });
      return;
    }

    if (nuevaX <= leftBound) {
      nuevaX = leftBound;
      setState(() => _mirandoIzq = false);
    } else if (nuevaX >= rightBound) {
      nuevaX = rightBound;
      setState(() => _mirandoIzq = true);
    }
    _posX = nuevaX;
    if ((_posX - _lastCommitX).abs() >= 1.0) {
      _lastCommitX = _posX;
      _actualizarPosicionVentana();
    }
  }

  Future<void> _actualizarPosicionVentana({bool forceRefresh = false}) async {
    try {
      final contW = (_refW * _tamano + 0.5).ceilToDouble();
      final contH = (_refH * _tamano + 0.5).ceilToDouble();
      const gap = 20.0;
      final mostrarNota = !_menuAbierto && _notasData.isNotEmpty && _notaPagina >= 0;
      final notaH = mostrarNota ? _notaCardH : 0.0;
      final baseH = contH + notaH;
      final totalH = _menuAbierto ? _menuH + gap + baseH : baseH;
      _posY = _posY.clamp(_screenTop + contH, _screenBottom);
      final w = _menuAbierto ? _menuW : contW;
      final left = _posX - w / 2;
      final top = _posY - totalH;
      if (forceRefresh) {
        await windowManager.setBounds(Rect.fromLTWH(left, top, w + 1, totalH));
      }
      await windowManager.setBounds(Rect.fromLTWH(left, top, w, totalH));
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
        _expresion = _alertaTiempoActiva ? Expresion.alerta : Expresion.normal;
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

  void _detenerTemporizador() {
    _temporizador?.cancel();
    _timerSub?.cancel();
    _temporizador = null;
    _tiempoRestante = null;
    _alertaTiempoActiva = false;
    if (mounted) {
      setState(() {
        if (!_menuAbierto && !_durmiendo) {
          _expresion = Expresion.normal;
        }
      });
    }
  }

  void _toggleNotaCard() {
    if (_notasData.isEmpty) return;
    if (_menuAbierto) return;
    _autoCerrarTimer?.cancel();
    final abriendo = _notaPagina < 0;
    setState(() {
      _notaPagina = abriendo ? 0 : -1;
    });
    _actualizarPosicionVentana();
    if (abriendo && _autoCerrarNotas) {
      _autoCerrarTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _notaPagina = -1);
          _actualizarPosicionVentana();
        }
      });
    }
  }

  Widget _buildNotaCard(BuildContext context) {
    final nota = _notasData[_notaPagina];
    return MouseRegion(
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
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(nota.colorValue),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.note, size: 14, color: Colors.grey),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    _autoCerrarTimer?.cancel();
                    await NotaService.eliminarNota(nota.id);
                    await _cargarNotas();
                    if (_notasData.isEmpty) {
                      _notaPagina = -1;
                    } else if (_notaPagina >= _notasData.length) {
                      _notaPagina = _notasData.length - 1;
                    }
                    if (mounted) {
                      setState(() {});
                      _actualizarPosicionVentana();
                    }
                  },
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              nota.texto,
              style: const TextStyle(fontSize: 12, color: Colors.black, decoration: TextDecoration.none, shadows: []),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (_notasData.length > 1) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _notaPagina > 0
                        ? () {
                            setState(() => _notaPagina--);
                            _autoCerrarTimer?.cancel();
                            if (_autoCerrarNotas) {
                              _autoCerrarTimer = Timer(const Duration(seconds: 5), () {
                                if (mounted) {
                                  setState(() => _notaPagina = -1);
                                  _actualizarPosicionVentana();
                                }
                              });
                            }
                          }
                        : null,
                    child: Icon(
                      Icons.chevron_left,
                      size: 18,
                      color: _notaPagina > 0 ? Colors.grey : Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_notaPagina + 1}/${_notasData.length}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey, decoration: TextDecoration.none, shadows: []),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _notaPagina < _notasData.length - 1
                        ? () {
                            setState(() => _notaPagina++);
                            _autoCerrarTimer?.cancel();
                            if (_autoCerrarNotas) {
                              _autoCerrarTimer = Timer(const Duration(seconds: 5), () {
                                if (mounted) {
                                  setState(() => _notaPagina = -1);
                                  _actualizarPosicionVentana();
                                }
                              });
                            }
                          }
                        : null,
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: _notaPagina < _notasData.length - 1 ? Colors.grey : Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _iniciarTemporizador() {
    showDialog(
      context: context,
      builder: (ctx) => TemporizadorDialog(
        onIniciar: (minutos) {
          setState(() {
            _temporizador?.cancel();
            _alertaTiempoActiva = false;
            _temporizador = TemporizadorState(
              minutos: minutos,
              onTerminar: () {
                WindowsServices.playAlertSound();
                if (!mounted) return;
                setState(() {
                  _tiempoRestante = null;
                  _alertaTiempoActiva = true;
                  _expresion = Expresion.alerta;
                });
                Future.delayed(const Duration(seconds: 4), () {
                  if (mounted) {
                    setState(() {
                      _alertaTiempoActiva = false;
                      if (!_menuAbierto && !_durmiendo) {
                        _expresion = Expresion.normal;
                      }
                    });
                  }
                });
              },
            );
            _temporizador!.iniciar();
            _timerSub?.cancel();
            _timerSub = _temporizador!.stream.listen((d) {
              if (mounted) setState(() => _tiempoRestante = d);
            });
          });
        },
        idioma: _idioma,
      ),
    );
  }

  Future<void> _abrirConfiguracion() async {
    await showGeneralDialog(
      context: context,
      pageBuilder: (ctx, animation, secondaryAnimation) => Align(
        alignment: Alignment.topCenter,
        child: _ConfigDialog(estado: this),
      ),
    );
  }

  void _salir() {
    _walkTimer?.cancel();
    _animationTimer?.cancel();
    _spontaneousTimer?.cancel();
    _sleepTimer?.cancel();
    _autoCerrarTimer?.cancel();
    _metricsDebounce?.cancel();
    _temporizador?.cancel();
    _timerSub?.cancel();
    WindowsServices.cleanup();
    windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
    final s = _curImgSize;
    final contW = (_refW * _tamano + 0.5).ceilToDouble();
    final contH = (_refH * _tamano + 0.5).ceilToDouble();
    final imgW = s.width * _tamano;
    final imgH = s.height * _tamano;
    const gap = 20.0;
    final mostrarNota = !_menuAbierto && _notasData.isNotEmpty && _notaPagina >= 0;
    final notaH = mostrarNota ? _notaCardH : 0.0;
    final totalH = _menuAbierto ? _menuH + gap + contH : contH + notaH;
    final tieneTemporizadorActivo = _tiempoRestante != null && _tiempoRestante!.inSeconds > 0;
    final mostrarBadges = !_menuAbierto && (tieneTemporizadorActivo || _alertaTiempoActiva || _notasData.isNotEmpty);

    return SizedBox(
      width: _menuAbierto ? _menuW : contW,
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_menuAbierto)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
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
                idioma: _idioma,
              ),
            ),
          if (mostrarNota)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _notaCardH,
              child: ClipRect(
                child: SizedBox(
                  height: _notaCardH,
                  child: _buildNotaCard(context),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: contH,
            child: Opacity(
              opacity: _opacidadGlobal,
              child: Listener(
                onPointerDown: (_) {},
                child: SizedBox(
                  width: _menuAbierto ? _menuW : contW,
                  height: contH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (mostrarBadges)
                        Positioned(
                          top: 2,
                          left: 0,
                          right: 0,
                          child: MouseRegion(
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (tieneTemporizadorActivo)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF222222),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${_tiempoRestante!.inMinutes}:${(_tiempoRestante!.inSeconds % 60).toString().padLeft(2, '0')}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            decoration: TextDecoration.none,
                                            shadows: [],
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        GestureDetector(
                                          onTap: _detenerTemporizador,
                                          child: const Icon(Icons.stop, size: 10, color: Colors.redAccent),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (_alertaTiempoActiva)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      t('tiempo_terminado', _idioma),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.none,
                                        shadows: [],
                                      ),
                                    ),
                                  ),
                                if ((tieneTemporizadorActivo || _alertaTiempoActiva) && _notasData.isNotEmpty)
                                  const SizedBox(width: 4),
                                if (_notasData.isNotEmpty)
                                  GestureDetector(
                                    onTap: _toggleNotaCard,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF444444),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.note, size: 9, color: Colors.white),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${_notasData.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              decoration: TextDecoration.none,
                                              shadows: [],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
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
                              child: Image.asset(
                                _imagenActual,
                                width: imgW,
                                height: imgH,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Dialog methods ---
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
        title: Text(t('abrir_carpeta', _idioma)),
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
            child: Text(t('mas', _idioma), style: TextStyle(color: Theme.of(ctx).colorScheme.primary)),
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
        title: Text(t('agregar_carpeta', _idioma)),
        content: TextField(controller: ctl, decoration: InputDecoration(hintText: t('ruta_carpeta', _idioma))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancelar', _idioma))),
          TextButton(onPressed: () {
            final p = ctl.text.trim();
            if (p.isNotEmpty) onAgregar(p);
            Navigator.pop(ctx);
          }, child: Text(t('agregar', _idioma))),
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
        title: Text(t('abrir_programa', _idioma)),
        children: [
          ...programas.map((p) => SimpleDialogOption(
            onPressed: () { WindowsServices.openProgram(p); Navigator.pop(ctx); },
            child: Text(p.split('\\').last),
          )),
          SimpleDialogOption(
            onPressed: () { Navigator.pop(ctx); _mostrarDialogoAgregarPrograma(context); },
            child: Text(t('mas_programa', _idioma), style: TextStyle(color: Theme.of(ctx).colorScheme.primary)),
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
        title: Text(t('agregar_programa', _idioma)),
        content: TextField(controller: ctl, decoration: InputDecoration(hintText: t('ruta_exe', _idioma))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancelar', _idioma))),
          TextButton(onPressed: () async {
            final p = ctl.text.trim();
            if (p.isNotEmpty) {
              await StorageManager.instance.setProgramas([...StorageManager.instance.programas, p]);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: Text(t('agregar', _idioma))),
        ],
      ),
    );
  }

  void _abrirOpcionNota(BuildContext context) {
    final ctl = TextEditingController();
    int selectedColor = 0xFFFFF9C4;
    const colores = [0xFFFFF9C4, 0xFFFFCDD2, 0xFFC8E6C9, 0xFFBBDEFB, 0xFFFFF8E1, 0xFFE1BEE7, 0xFFB2EBF2, 0xFFD7CCC8];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          title: Text(t('nota_rapida', _idioma), style: const TextStyle(fontSize: 14)),
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: ctl, maxLines: 3, maxLength: 100, maxLengthEnforcement: MaxLengthEnforcement.enforced, decoration: InputDecoration(
                hintText: t('escribe', _idioma),
                isDense: true,
                contentPadding: const EdgeInsets.all(8),
              )),
              const SizedBox(height: 8),
              Wrap(
                spacing: 3,
                children: colores.map((c) => GestureDetector(
                  onTap: () => setDialogState(() => selectedColor = c),
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(color: selectedColor == c ? Colors.black : Colors.grey, width: selectedColor == c ? 2 : 1),
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancelar', _idioma))),
            TextButton(onPressed: () async {
              final txt = ctl.text.trim();
              if (txt.isNotEmpty) {
                await NotaService.guardarNota(txt, colorValue: selectedColor);
                await _cargarNotas();
                if (ctx.mounted) Navigator.pop(ctx);
              } else {
                Navigator.pop(ctx);
              }
            }, child: Text(t('guardar', _idioma))),
          ],
        ),
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
  late bool _autoCerrarNotas;
  late String _idioma;
  List<String> _mascotas = [];

  @override
  void initState() {
    super.initState();
    final cfg = StorageManager.instance.configuracion;
    _velocidad = cfg.velocidad;
    _opacidad = cfg.opacidad;
    _tamano = cfg.tamano;
    _inicioAutomatico = WindowsServices.isAutoStartEnabled() || cfg.inicioAutomatico;
    _animal = cfg.animal;
    _autoCerrarNotas = cfg.autoCerrarNotas;
    _idioma = cfg.idioma;
    _cargarMascotas();
  }

  Future<void> _cargarMascotas() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final mascotas = manifest
          .listAssets()
          .where((k) => k.startsWith('assets/img/'))
          .map((k) => k.split('/'))
          .where((parts) => parts.length >= 4)
          .map((parts) => parts[2])
          .toSet()
          .toList()
        ..sort();
      if (mounted) {
        setState(() => _mascotas = mascotas.isNotEmpty ? mascotas : ['Capybara', 'serpiente']);
      }
    } catch (_) {
      if (mounted) setState(() => _mascotas = ['Capybara', 'serpiente']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          width: _menuW,
          height: _menuH,
          decoration: BoxDecoration(
            color: Theme.of(context).dialogTheme.backgroundColor ?? Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Text(t('configuracion', _idioma), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    Text(t('velocidad', _idioma)),
                    Slider(
                      value: _velocidad,
                      min: 0.3,
                      max: 3.0,
                      divisions: 27,
                      label: _velocidad.toStringAsFixed(1),
                      onChanged: (v) => setState(() => _velocidad = v),
                    ),
                    const Divider(),
                    Text(t('opacidad', _idioma)),
                    Slider(
                      value: _opacidad,
                      min: 0.2,
                      max: 1.0,
                      divisions: 8,
                      label: (_opacidad * 100).round().toString(),
                      onChanged: (v) => setState(() => _opacidad = v),
                    ),
                    const Divider(),
                    Text(t('tamano', _idioma)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SegmentedButton<double>(
                        segments: [
                          ButtonSegment(value: 0.4, label: Text(t('pequeno', _idioma))),
                          ButtonSegment(value: 0.5, label: Text(t('normal', _idioma))),
                        ],
                        selected: {_tamano},
                        onSelectionChanged: (v) => setState(() => _tamano = v.first),
                      ),
                    ),
                    const Divider(),
                    Text(t('mascota', _idioma)),
                    if (_mascotas.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(t('cargando_mascotas', _idioma), style: const TextStyle(color: Colors.grey)),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: SegmentedButton<String>(
                          segments: _mascotas.map((m) => ButtonSegment(value: m, label: Text(t(m, _idioma)))).toList(),
                          selected: {_animal},
                          onSelectionChanged: (v) => setState(() => _animal = v.first),
                        ),
                      ),
                    const Divider(),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('iniciar_windows', _idioma)),
                      value: _inicioAutomatico,
                      onChanged: (v) => setState(() => _inicioAutomatico = v ?? false),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('cerrar_nota_auto', _idioma)),
                      subtitle: Text(t('se_cierra_sola', _idioma)),
                      value: _autoCerrarNotas,
                      onChanged: (v) => setState(() => _autoCerrarNotas = v ?? false),
                    ),
                    const Divider(),
                    Text(t('idioma', _idioma)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'es', label: Text('Español')),
                          ButtonSegment(value: 'en', label: Text('English')),
                        ],
                        selected: {_idioma},
                        onSelectionChanged: (v) => setState(() => _idioma = v.first),
                      ),
                    ),
                    const Divider(),
                    Text(t('carpetas_guardadas', _idioma)),
                    ..._buildCarpetasList(),
                    const Divider(),
                    Text(t('programas_guardados', _idioma)),
                    ..._buildProgramasList(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(t('cancelar', _idioma))),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _guardar, child: Text(t('guardar', _idioma))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCarpetasList() {
    final list = StorageManager.instance.carpetas;
    if (list.isEmpty) return [Text(t('ninguna', _idioma), style: const TextStyle(color: Colors.grey))];
    return list.map((c) => ListTile(dense: true, title: Text(c, style: const TextStyle(fontSize: 12)),
      trailing: IconButton(icon: const Icon(Icons.delete, size: 16),
        onPressed: () { StorageManager.instance.setCarpetas(list.where((x) => x != c).toList()); setState(() {}); }),
    )).toList();
  }

  List<Widget> _buildProgramasList() {
    final list = StorageManager.instance.programas;
    if (list.isEmpty) return [Text(t('ninguna', _idioma), style: const TextStyle(color: Colors.grey))];
    return list.map((p) => ListTile(dense: true, title: Text(p.split('\\').last, style: const TextStyle(fontSize: 12)),
      subtitle: Text(p, style: const TextStyle(fontSize: 10)),
      trailing: IconButton(icon: const Icon(Icons.delete, size: 16),
        onPressed: () { StorageManager.instance.setProgramas(list.where((x) => x != p).toList()); setState(() {}); }),
    )).toList();
  }

  void _guardar() {
    WindowsServices.setAutoStart(_inicioAutomatico);
    StorageManager.instance.setConfiguracion(Configuracion(
      velocidad: _velocidad,
      apariencia: 0,
      opacidad: _opacidad,
      tamano: _tamano,
      inicioAutomatico: _inicioAutomatico,
      evitarSuspension: StorageManager.instance.configuracion.evitarSuspension,
      animal: _animal,
      autoCerrarNotas: _autoCerrarNotas,
      idioma: _idioma,
    ));
    widget.estado.setState(() {
      widget.estado._velocidad = _velocidad;
      widget.estado._opacidadGlobal = _opacidad;
      widget.estado._tamano = _tamano;
      widget.estado._animal = _animal;
      widget.estado._autoCerrarNotas = _autoCerrarNotas;
      widget.estado._idioma = _idioma;
    });
    widget.estado._precacheImages();
    widget.estado._iniciarCaminata();
    widget.estado._actualizarPosicionVentana(forceRefresh: true);
    Navigator.pop(context);
  }
}
