import 'dart:async';
import 'package:flutter/material.dart';
import '../traduccion.dart';

class TemporizadorState {
  final int minutos;
  final VoidCallback onTerminar;
  bool _activo = false;
  Timer? _timer;
  Duration _restante = Duration.zero;
  final _controller = StreamController<Duration>.broadcast();

  bool get activo => _activo;
  Duration get restante => _restante;
  Stream<Duration> get stream => _controller.stream;

  TemporizadorState({required this.minutos, required this.onTerminar});

  void iniciar() {
    if (_activo) return;
    _restante = Duration(minutes: minutos);
    _activo = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _restante = _restante - const Duration(seconds: 1);
      _controller.add(_restante);
      if (_restante.inSeconds <= 0) {
        _activo = false;
        _timer?.cancel();
        onTerminar();
      }
    });
    _controller.add(_restante);
  }

  void cancel() {
    _timer?.cancel();
    _activo = false;
    _controller.close();
  }
}

class TemporizadorDialog extends StatefulWidget {
  final void Function(int minutos) onIniciar;
  final String idioma;

  const TemporizadorDialog({super.key, required this.onIniciar, this.idioma = 'es'});

  @override
  State<TemporizadorDialog> createState() => _TemporizadorDialogState();
}

class _TemporizadorDialogState extends State<TemporizadorDialog> {
  int _minutos = 5;
  static const List<int> _presets = [5, 15, 25, 45, 60];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      title: Text(t('temporizador', widget.idioma), style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 220,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('minutos', widget.idioma), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    if (_minutos > 1) setState(() => _minutos--);
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_minutos',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    if (_minutos < 180) setState(() => _minutos++);
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: _presets.map((p) {
                final selected = _minutos == p;
                return GestureDetector(
                  onTap: () => setState(() => _minutos = p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${p}m',
                      style: TextStyle(
                        fontSize: 11,
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('cancelar', widget.idioma)),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onIniciar(_minutos);
            Navigator.pop(context);
          },
          child: Text(t('iniciar', widget.idioma)),
        ),
      ],
    );
  }
}
