import 'package:flutter/material.dart';
import '../storage.dart';

class NotaDot extends StatelessWidget {
  final Nota nota;

  const NotaDot({super.key, required this.nota});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Color(nota.colorValue),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
      ),
    );
  }
}

class NotaService {
  static Future<List<Nota>> cargarNotas() async {
    return StorageManager.instance.notas;
  }

  static Future<void> guardarNota(String texto, {int colorValue = 0xFFFFF9C4}) async {
    final notas = [...StorageManager.instance.notas,
      Nota(id: DateTime.now().microsecondsSinceEpoch.toString(), texto: texto, colorValue: colorValue)];
    await StorageManager.instance.setNotas(notas);
  }

  static Future<void> eliminarNota(String id) async {
    final notas = StorageManager.instance.notas.where((n) => n.id != id).toList();
    await StorageManager.instance.setNotas(notas);
  }
}
