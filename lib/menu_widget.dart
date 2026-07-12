import 'package:flutter/material.dart';

class MenuWidget extends StatelessWidget {
  final VoidCallback onCerrar;
  final bool evitarSuspensionActivo;
  final VoidCallback onToggleEvitarSuspension;
  final VoidCallback onAbrirCarpeta;
  final VoidCallback onAbrirPrograma;
  final VoidCallback onTemporizador;
  final bool bloquearCursorActivo;
  final VoidCallback onToggleBloquearCursor;
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
    required this.bloquearCursorActivo,
    required this.onToggleBloquearCursor,
    required this.onNota,
    required this.onConfiguracion,
    required this.onSalir,
  });

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
                ..._buildItems(context),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildItems(BuildContext context) {
    return [
      _MenuItem(
        icon: Icons.power_settings_new,
        label: 'Evitar suspensión',
        trailing: Transform.scale(
          scale: 0.65,
          child: Switch(
            value: evitarSuspensionActivo,
            onChanged: (_) => onToggleEvitarSuspension(),
            activeTrackColor: Colors.greenAccent,
          ),
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
        icon: Icons.lock_outline,
        label: 'Bloquear cursor',
        trailing: Transform.scale(
          scale: 0.65,
          child: Switch(
            value: bloquearCursorActivo,
            onChanged: (_) => onToggleBloquearCursor(),
            activeTrackColor: Colors.orangeAccent,
          ),
        ),
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
      const Divider(color: Colors.white12, height: 1),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: textColor ?? Colors.white70),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor ?? Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
            if (trailing != null) trailing!,
            if (trailing == null && onTap != null)
              const Icon(Icons.chevron_right, size: 16, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
