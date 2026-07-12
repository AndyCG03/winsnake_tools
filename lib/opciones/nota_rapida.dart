import 'package:flutter/material.dart';
import '../storage.dart';

class NotaWidget extends StatefulWidget {
  final String texto;
  final VoidCallback onCerrar;

  const NotaWidget({
    super.key,
    required this.texto,
    required this.onCerrar,
  });

  @override
  State<NotaWidget> createState() => _NotaWidgetState();
}

class _NotaWidgetState extends State<NotaWidget> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 200,
      top: 100,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 180,
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
                widget.texto,
                style: const TextStyle(color: Colors.brown, fontSize: 12),
              ),
            ],
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
    final notas = [...StorageManager.instance.notas, Nota(texto: texto)];
    await StorageManager.instance.setNotas(notas);
  }

  static Future<void> eliminarNota(int index) async {
    final notas = StorageManager.instance.notas;
    notas.removeAt(index);
    await StorageManager.instance.setNotas(notas);
  }
}
