import 'package:flutter/material.dart';

class MenuWidget extends StatelessWidget {
  final VoidCallback onCerrar;
  final bool evitarSuspensionActivo;
  final VoidCallback onToggleEvitarSuspension;
  final VoidCallback onAbrirCarpeta;
  final VoidCallback onAbrirPrograma;
  final VoidCallback onTemporizador;
  final VoidCallback onNota;
  final VoidCallback onConfiguracion;
  final VoidCallback onSalir;

  const MenuWidget({
    super.key,
    required this.onCerrar,
    required this.evitarSuspensionActivo,
    required this.onToggleEvitarSuspension,
    required this.onAbrirCarpeta,
    required this.onAbrirPrograma,
    required this.onTemporizador,
    required this.onNota,
    required this.onConfiguracion,
    required this.onSalir,
  });

  // Anchos fijos para alineación perfecta entre filas
  static const double _iconW = 34.0;
  static const double _trailingW = 56.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xF01A1A2E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 24,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                ..._buildItems(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildItems() {
    return [
      _MenuItem(
        icon: Icons.power_settings_new,
        label: 'Evitar suspensión',
        trailing: _Switch(
          value: evitarSuspensionActivo,
          onChanged: (_) => onToggleEvitarSuspension(),
          activeColor: Colors.greenAccent,
        ),
      ),
      _MenuItem(
        icon: Icons.folder_open,
        label: 'Abrir carpeta',
        onTap: onAbrirCarpeta,
      ),
      _MenuItem(
        icon: Icons.play_circle_outline,
        label: 'Abrir programa',
        onTap: onAbrirPrograma,
      ),
      _MenuItem(
        icon: Icons.timer_outlined,
        label: 'Temporizador',
        onTap: onTemporizador,
      ),
      _MenuItem(
        icon: Icons.note_add_outlined,
        label: 'Nota rápida',
        onTap: onNota,
      ),
      _MenuItem(
        icon: Icons.settings,
        label: 'Configuración',
        onTap: onConfiguracion,
      ),
      const Divider(color: Colors.white12, height: 1, thickness: 1),
      _MenuItem(
        icon: Icons.exit_to_app,
        label: 'Salir',
        onTap: onSalir,
        textColor: const Color(0xFFEF5350),
      ),
      const SizedBox(height: 4),
    ];
  }
}

/// Toggle compacto personalizado que ocupa exactamente 30x16px,
/// evitando el sobre-espacio de layout que deja Transform.scale + Switch.
class _Switch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final Color activeColor;

  const _Switch({
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MenuWidget._trailingW,
      height: 20,
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: Container(
            width: 30,
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: value ? activeColor : Colors.white24,
            ),
            padding: const EdgeInsets.all(2),
            child: Align(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? textColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? Colors.white;
    final iconColor = textColor ?? Colors.white70;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            // Icono a ancho fijo -> alineado en todas las filas
            SizedBox(
              width: MenuWidget._iconW,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Icon(icon, size: 20, color: iconColor),
              ),
            ),
            // Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: color, fontSize: 13, height: 1.2),
              ),
            ),
            // Trailing a ancho fijo -> alineado en todas las filas
            SizedBox(
              width: MenuWidget._trailingW,
              child: Align(
                alignment: Alignment.centerRight,
                child: trailing ??
                    (onTap != null
                        ? const Icon(Icons.chevron_right,
                            size: 18, color: Colors.white24)
                        : const SizedBox.shrink()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
