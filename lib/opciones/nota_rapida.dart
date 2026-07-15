import 'package:flutter/material.dart';
import '../storage.dart';

class NotaWidget extends StatefulWidget {
  final Nota nota;
  final VoidCallback onCerrar;
  final ValueChanged<Nota> onMover;

  const NotaWidget({
    super.key,
    required this.nota,
    required this.onCerrar,
    required this.onMover,
  });

  @override
  State<NotaWidget> createState() => _NotaWidgetState();
}

class _NotaWidgetState extends State<NotaWidget> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.nota.x,
      top: widget.nota.y,
      child: GestureDetector(
        onPanUpdate: (d) {
          widget.onMover(Nota(
            id: widget.nota.id,
            texto: widget.nota.texto,
            x: widget.nota.x + d.delta.dx,
            y: widget.nota.y + d.delta.dy,
          ));
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 160,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9C4),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.note, size: 14, color: Colors.brown),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onCerrar,
                      child: const Icon(Icons.close, size: 16, color: Colors.brown),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.nota.texto,
                  style: const TextStyle(color: Colors.brown, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotaService {
  static Future<List<Nota>> cargarNotas() async {
    return StorageManager.instance.notas;
  }

  static Future<void> guardarNota(String texto) async {
    final notas = [...StorageManager.instance.notas,
      Nota(id: DateTime.now().microsecondsSinceEpoch.toString(), texto: texto)];
    await StorageManager.instance.setNotas(notas);
  }

  static Future<void> eliminarNota(String id) async {
    final notas = StorageManager.instance.notas.where((n) => n.id != id).toList();
    await StorageManager.instance.setNotas(notas);
  }

  static Future<void> actualizarNota(Nota nota) async {
    final notas = StorageManager.instance.notas;
    final idx = notas.indexWhere((n) => n.id == nota.id);
    if (idx == -1) return;
    notas[idx] = nota;
    await StorageManager.instance.setNotas(notas);
  }
}