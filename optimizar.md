# Plan de optimización de recursos — WinSnake Tools

## Prioridad alta

### 1. Caminar 60 FPS (walk timer)

**Problema**: `_walkTimer` en `_iniciarCaminata()` se ejecuta cada `20 / velocidad` ms. A velocidad 1.0 → 20ms ≈ 50 FPS. A velocidad 3.0 → ~6ms ≈ 166 FPS. Cada tick llama a `_moverSnake()` → `_actualizarPosicionVentana()` que hace I/O síncrono (`windowManager.setBounds`).

**Solución**: Limitar el timer a ~16ms (60 FPS ≈ 16.6ms) incluso a velocidades altas. La velocidad debe simularse con pasos más grandes en vez de intervalos más cortos:

```dart
final interval = max(16, (20 / _velocidad.clamp(0.3, 5.0)).round());
final paso = _velocidad * (interval / 16.0); // ajustar paso al intervalo real
```

### 2. Acumular movimientos antes de redimensionar ventana

**Problema**: `_moverSnake()` llama a `_actualizarPosicionVentana()` (windowManager.setBounds) en CADA tick. A 50-166 llamadas/segundo es I/O excesivo.

**Solución**: Usar `windowManager.setBounds` solo cuando la posición supere un umbral (~4px) o mediante un timer de 30-50ms que tome la última posición:

```dart
double _lastCommitX = 0;
void _moverSnake() {
  // ... calcular nuevaX ...
  _posX = nuevaX;
  if ((_posX - _lastCommitX).abs() >= 4) {
    _lastCommitX = _posX;
    _actualizarPosicionVentana(); // llama a setBounds
  }
}
```

### 3. Throttle escritura de notas durante arrastre

**Problema**: `onPanUpdate` en `NotaWidget` → `widget.onMover` → `NotaService.actualizarNota()` → `StorageManager.setNotas()` → escritura a disco (`writeAsString`) en CADA frame de arrastre (~60 FPS). Esto satura E/S y gasta batería en laptops.

**Solución**: Usar un `Timer` de 100ms dentro del estado del `NotaWidget` que acumule la última posición antes de persistir:

```dart
Timer? _saveTimer;
void _guardar(Offset pos) {
  _pendingPos = pos;
  _saveTimer ??= Timer(const Duration(milliseconds: 100), () {
    widget.onMover(Nota(id: widget.nota.id, texto: widget.nota.texto, x: _pendingPos!.dx, y: _pendingPos!.dy));
    _saveTimer = null;
  });
}
```

### 4. Evitar reconstrucción innecesaria del Stack de notas

**Problema**: Las notas son children de un `Stack` que se reconstruye completamente cada `setState` (cada tick de animación, cada frame de caminata). Aunque `ValueKey` preserva el estado interno, el marco de widgets se re-crea.

**Solución**: Extraer el área de notas a un widget separado con `const` constructor o usar un `RepaintBoundary` alrededor para limitar el repintado.

## Prioridad media

### 5. ImageCache para sprites

**Problema**: `Image.asset(_imagenActual, width: imgW, height: imgH)` sin `key`. Flutter usa ImageCache internamente, pero el cambio de frame genera una nueva petición de asset cada 200ms. Con 9 sprites de ~200-300px cada uno, el cache nunca se estabiliza.

**Solución**: Precargar las 9 imágenes al iniciar con `precacheImage()` y asignar `Image.asset` con `frameBuilder` para evitar flickering. O usar `cacheWidth`/`cacheHeight` con el tamaño escalado real.

### 6. Opacity vs. drawImage

**Problema**: `Opacity` wrapper alrededor del área de la serpiente crea una `RenderLayer` que se combina con el fondo transparente. Flutter no puede optimizar este escenario.

**Solución**: Si se necesita opacidad < 1.0, usar `Paint` con `ColorFilter` o aplicar la opacidad directamente en el `Color` de los widgets internos (donde sea posible).

### 7. Timer de animación redundante cuando no hay cambios visuales

**Problema**: `_animationTimer` se ejecuta cada 200ms aunque la serpiente esté detenida (menú abierto, durmiendo, etc.). El callback chequea `_estado` pero el timer sigue corriendo.

**Solución**: Cancelar y recrear el timer cuando cambia el estado, en vez de tenerlo siempre activo. O usar `setState` solo cuando realmente cambia el frame.

### 8. Cargar notas una sola vez y sincronizar en segundo plano

**Problema**: `_cargarNotas()` se llama en cada creación/eliminación/movimiento de nota. Lee de disco y re-procesa toda la lista.

**Solución**: Mantener una copia en memoria sincronizada con `StorageManager` usando `notifyListeners` (ya es `ChangeNotifier`). Escuchar cambios en vez de leer de disco cada vez.

## Prioridad baja

### 9. Evitar setState en timer cuando mounted es false

**Problema**: Varios `Timer.periodic` y `Future.delayed` chequean `mounted` antes de `setState`, pero no cancelan el timer. El timer sigue corriendo en background.

**Solución**: Cancelar todos los timers en el callback o agregar un flag de `_disposed`.

### 10. Unificar actualizaciones de ventana

**Problema**: `_actualizarPosicionVentana()` se llama desde múltiples sitios: `_moverSnake()`, `_onTapSnake()`, `_toggleDormir()`, `_toggleEvitarSuspension()`, `_cargarConfiguracion()`, etc. En muchos casos se llama dos veces seguidas.

**Solución**: Usar un `Timer.run(() => _actualizarPosicionVentana())` post-frame para evitar llamadas duplicadas en el mismo ciclo.

### 11. Ancho fijo del área de notas

**Problema**: `_notasAreaH` usa un estimado fijo de 100px por nota. Esto es impreciso.

**Solución**: Usar `GlobalKey` en cada `NotaWidget` para medir su altura real y calcular el área con precisión.

## Impacto esperado

| Optimización | Reducción estimada |
|---|---|
| Walk timer 60 FPS cap | 40-70% menos llamadas a `setBounds` |
| Batch window moves | ~90% menos llamadas a `setBounds` |
| Throttle nota drag | ~95% menos escrituras a disco |
| Image precaching | Sin impacto directo en CPU/RAM, evita flickering |
| Notes fuera del rebuild loop | Reduce frametime del walk en ~0.1ms |
