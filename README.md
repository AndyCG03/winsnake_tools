# WinSnake Tools

Widget de escritorio para Windows con una serpiente animada que camina sobre la pantalla, siempre visible encima de otras ventanas, con menú contextual de utilidades del sistema.

## Estado Actual

- **Versión:** 1.0.0
- **Plataforma:** Windows (Flutter Desktop)
- **Última actualización:** Julio 2026

## Funcionalidades

| Opción | Descripción |
|--------|-------------|
| **Evitar suspensión** | Evita que la PC entre en suspensión (SetThreadExecutionState) |
| **Dormir** | La serpiente se queda quieta y duerme (animación loop con img 7/8/9) |
| **Abrir carpeta** | Abre carpetas del sistema con Explorer |
| **Abrir programa** | Ejecuta programas del sistema |
| **Temporizador** | Cuenta regresiva con alerta visual |
| **Nota rápida** | Nota post-it persistente |
| **Configuración** | Velocidad, opacidad, auto-start, carpetas, programas |
| **Salir** | Cierra la aplicación |

## Controles

- **Hover sobre la serpiente**: Se detiene y cambia a imagen de espera
- **Click sobre la serpiente**: Abre menú de opciones (sin detener la caminata)
- **Clic fuera del menú**: Cierra el menú

## Comportamiento

- La serpiente camina de lado a lado en la parte inferior de la pantalla, justo arriba de la barra de tareas
- Al acercarse al borde, anticipa el giro mostrando un sprite de giro antes de rebotar
- Al abrir el menú, la serpiente salta (img 5) a la misma altura que el resto de sprites
- La opacidad configurable solo afecta a la serpiente, no al menú
- La serpiente solo se detiene cuando el cursor está sobre ella o el menú está abierto
- El área interactiva (hover/click) se ajusta exactamente al tamaño del sprite visible

## Sprites

| Imagen | Propósito |
|--------|-----------|
| `assets/img/1.png` | Frame 1 de caminar (291×139) |
| `assets/img/2.png` | Frame 2 de caminar (337×139) |
| `assets/img/3.png` | Frame 3 de caminar (306×139) |
| `assets/img/4.png` | Hover/espera (261×194) |
| `assets/img/5.png` | Salto al abrir menú (239×268) |
| `assets/img/6.png` | Anticipo de giro (279×169) |
| `assets/img/7.png` | Frame 1 de dormir (131×102) |
| `assets/img/8.png` | Frame 2 de dormir (130×72) |
| `assets/img/9.png` | Frame 3 de dormir (130×85) |

Todas las imágenes se renderizan con la misma altura de referencia (194px) para mantener la alineación inferior consistente.

## Configuración

Los datos se almacenan en `%APPDATA%/winsnake_tools/storage.json`:
- Velocidad de movimiento
- Opacidad (solo para la serpiente)
- Inicio automático con Windows (registro HKCU\Run)
- Lista de carpetas guardadas
- Lista de programas guardados
- Estado de evitar suspensión

## Requisitos del Sistema

- **SO:** Windows 10+ (64-bit)
- **Flutter SDK:** 3.38.6+
- **Dart SDK:** 3.10.7+
- **Dependencias:** window_manager 0.3.9, shared_preferences 2.5.4, screen_retriever 0.1.9, win32 5.15.0

## Compilación

```bash
flutter pub get --offline
flutter build windows --debug
```

El ejecutable se genera en `build\windows\x64\runner\Debug\winsnake_tools.exe`.

## Estructura del Proyecto

```
lib/
├── main.dart                  # Punto de entrada, ventana frameless
├── winsnake_widget.dart       # Widget principal, lógica de movimiento/hover/menú
├── winsnake_painter.dart      # Painters CustomPainter (legacy)
├── menu_widget.dart           # Menú contextual oscuro con switches
├── storage.dart               # Persistencia JSON en %APPDATA%
├── servicios/
│   └── windows_services.dart  # FFI: SetThreadExecutionState, Registry, etc.
├── opciones/
│   ├── temporizador.dart      # Temporizador con Stream y diálogo de minutos
│   └── nota_rapida.dart       # Widget post-it y servicio de persistencia
└── configuracion/             # (reservado)
assets/
└── img/
    ├── 1.png                  # Frame caminar 1
    ├── 2.png                  # Frame caminar 2
    ├── 3.png                  # Frame caminar 3
    ├── 4.png                  # Hover/espera
    ├── 5.png                  # Salto al abrir menú
    ├── 6.png                  # Anticipo de giro
    ├── 7.png                  # Dormir frame 1
    ├── 8.png                  # Dormir frame 2
    └── 9.png                  # Dormir frame 3
windows/
└── runner/main.cpp            # Ventana inicial
```
