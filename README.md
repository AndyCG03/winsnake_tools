# Bichito Widget

Widget de escritorio para Windows con un bicho animado que camina libremente sobre la pantalla, siempre visible encima de otras ventanas, con menú contextual de utilidades del sistema.

## Estado Actual

- **Versión:** 1.0.0
- **Plataforma:** Windows (Flutter Desktop)
- **Última actualización:** Julio 2026

## Funcionalidades

| Opción | Descripción |
|--------|-------------|
| **Evitar suspensión** | Evita que la PC entre en suspensión (SetThreadExecutionState) |
| **Abrir carpeta** | Abre carpetas del sistema con Explorer |
| **Abrir programa** | Ejecuta programas del sistema |
| **Temporizador** | Cuenta regresiva con alerta visual |
| **Bloquear cursor** | Bloquea el cursor en un área (Ctrl+Shift+L desbloquea) |
| **Nota rápida** | Nota post-it persistente |
| **Configuración** | Velocidad, opacidad, auto-start, carpetas, programas |
| **Salir** | Cierra la aplicación |

## Controles

- **Hover sobre el bicho**: Se detiene y cambia a imagen de espera
- **Click sobre el bicho**: Abre menú de opciones
- **Arrastrar el bicho**: Lo mueve por la pantalla
- **Clic fuera del menú**: Cierra el menú

## Sprites

| Imagen | Propósito |
|--------|-----------|
| `assets/img/1.png` | Frame 1 de caminar (291×139) |
| `assets/img/2.png` | Frame 2 de caminar (337×139) |
| `assets/img/3.png` | Frame 3 de caminar (306×139) |
| `assets/img/4.png` | Hover/espera/hablar (261×194) |

## Configuración

Los datos se almacenan en `%APPDATA%/bichito_widget/storage.json`:
- Velocidad de movimiento
- Opacidad
- Inicio automático con Windows (registro HKCU\Run)
- Lista de carpetas guardadas
- Lista de programas guardados
- Estado de evitar suspensión
- Estado de bloqueo de cursor

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

El ejecutable se genera en `build\windows\x64\runner\Debug\bichito_widget.exe`.

## Estructura del Proyecto

```
lib/
├── main.dart                  # Punto de entrada, ventana frameless 290×170
├── bichito_widget.dart        # Widget principal, lógica de movimiento/hover/menú
├── bichito_painter.dart       # Painters CustomPainter (legacy, no usado)
├── menu_widget.dart           # Menú contextual oscuro con switches
├── storage.dart               # Persistencia JSON en %APPDATA%
├── servicios/
│   └── windows_services.dart  # FFI: SetThreadExecutionState, ClipCursor, Registry, etc.
├── opciones/
│   ├── temporizador.dart      # Temporizador con Stream y diálogo de minutos
│   └── nota_rapida.dart       # Widget post-it y servicio de persistencia
└── configuracion/             # (reservado)
assets/
└── img/
    ├── 1.png                  # Frame caminar 1
    ├── 2.png                  # Frame caminar 2
    ├── 3.png                  # Frame caminar 3
    └── 4.png                  # Hover/espera
windows/
└── runner/main.cpp            # Ventana inicial 290×170
```
