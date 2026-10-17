import '../storage.dart';

class NotaService {
  static Future<List<Nota>> cargarNotas() async {
    return StorageManager.instance.notas;
  }

  static Future<void> guardarNota(String texto, {int colorValue = 0xFFFFF9C4}) async {
    final notas = [
      ...StorageManager.instance.notas,
      Nota(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        texto: texto,
        colorValue: colorValue,
      ),
    ];
    await StorageManager.instance.setNotas(notas);
  }

  static Future<void> eliminarNota(String id) async {
    final notas = StorageManager.instance.notas.where((n) => n.id != id).toList();
    await StorageManager.instance.setNotas(notas);
  }
}
