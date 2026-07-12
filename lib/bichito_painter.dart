import 'dart:math';
import 'package:flutter/material.dart';

enum Expresion { normal, durmiendo, esperando, alerta }

abstract class BichitoDesign {
  final String nombre;
  BichitoDesign(this.nombre);
  void paint(Canvas canvas, Size size, int frame, Expresion expresion, bool mirandoIzq);
}

class DesignLadybug extends BichitoDesign {
  DesignLadybug() : super('Mariquita');

  @override
  void paint(Canvas canvas, Size size, int frame, Expresion expresion, bool mirandoIzq) {
    canvas.save();
    if (mirandoIzq) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final cx = size.width / 2;
    final cy = size.height / 2;
    final bw = size.width * 0.6;
    final bh = size.height * 0.5;
    final bobY = sin(frame * pi / 2) * 2;

    // Body
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy + bobY), width: bw, height: bh),
        Paint()..color = const Color(0xFFE53935));

    // Stripe
    canvas.drawLine(Offset(cx, cy - bh / 2 + bobY), Offset(cx, cy + bh / 2 + bobY),
        Paint()..color = Colors.black..strokeWidth = 2);

    // Spots
    final sr = bw * 0.12;
    canvas.drawCircle(Offset(cx - bw * 0.22, cy - bh * 0.15 + bobY), sr, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(cx + bw * 0.22, cy - bh * 0.15 + bobY), sr, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(cx - bw * 0.18, cy + bh * 0.2 + bobY), sr * 0.8, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(cx + bw * 0.18, cy + bh * 0.2 + bobY), sr * 0.8, Paint()..color = Colors.black);

    // Head
    canvas.drawCircle(Offset(cx, cy - bh / 2 - 4 + bobY), bw * 0.18, Paint()..color = Colors.black);

    // Eyes
    _drawEyes(canvas, cx, cy - bh / 2 - 6 + bobY, bw * 0.1, expresion);

    // Antennae
    final antPaint = Paint()..color = Colors.black..strokeWidth = 1.5;
    final antW = sin((frame + 1) * pi / 3) * 3;
    canvas.drawLine(Offset(cx - 4, cy - bh / 2 - 4 + bobY), Offset(cx - 6 + antW, cy - bh / 2 - 18 + bobY), antPaint);
    canvas.drawLine(Offset(cx + 4, cy - bh / 2 - 4 + bobY), Offset(cx + 6 - antW, cy - bh / 2 - 18 + bobY), antPaint);

    // Legs
    final legPaint = Paint()..color = Colors.black..strokeWidth = 1.5;
    final legS = sin(frame * pi / 2) * 4;
    canvas.drawLine(Offset(cx - bw / 2, cy + bobY), Offset(cx - bw / 2 - 6 - legS, cy + bh * 0.3 + bobY), legPaint);
    canvas.drawLine(Offset(cx + bw / 2, cy + bobY), Offset(cx + bw / 2 + 6 + legS, cy + bh * 0.3 + bobY), legPaint);
    canvas.drawLine(Offset(cx - bw / 2, cy + bh * 0.3 + bobY), Offset(cx - bw / 2 - 4 + legS, cy + bh * 0.6 + bobY), legPaint);
    canvas.drawLine(Offset(cx + bw / 2, cy + bh * 0.3 + bobY), Offset(cx + bw / 2 + 4 - legS, cy + bh * 0.6 + bobY), legPaint);

    _drawIndicators(canvas, cx, cy, bw, bh, bobY, expresion);
    canvas.restore();
  }
}

class DesignBee extends BichitoDesign {
  DesignBee() : super('Abeja');

  @override
  void paint(Canvas canvas, Size size, int frame, Expresion expresion, bool mirandoIzq) {
    canvas.save();
    if (mirandoIzq) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final cx = size.width / 2;
    final cy = size.height / 2;
    final bw = size.width * 0.55;
    final bh = size.height * 0.45;
    final bobY = sin(frame * pi / 2) * 2;

    // Wings
    final wingPaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    final wp1 = Path()
      ..moveTo(cx, cy - bh / 2 + bobY)
      ..quadraticBezierTo(cx - bw * 0.5, cy - bh * 0.8 + bobY, cx - 2, cy - bh / 2 - 2 + bobY);
    canvas.drawPath(wp1, wingPaint);
    final wp2 = Path()
      ..moveTo(cx, cy - bh / 2 + bobY)
      ..quadraticBezierTo(cx + bw * 0.5, cy - bh * 0.8 + bobY, cx + 2, cy - bh / 2 - 2 + bobY);
    canvas.drawPath(wp2, wingPaint);

    // Body
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy + bobY), width: bw, height: bh),
        Paint()..color = const Color(0xFFFFC107));

    // Stripes
    for (int i = 0; i < 3; i++) {
      final sy = cy - bh / 2 + (i + 1) * bh / 4 + bobY;
      final halfW = sqrt(pow(bw / 2, 2) * (1 - pow((sy - cy - bobY) / (bh / 2), 2)));
      canvas.drawLine(Offset(cx - halfW, sy), Offset(cx + halfW, sy),
          Paint()..color = Colors.black..strokeWidth = 2.5);
    }

    // Head
    canvas.drawCircle(Offset(cx, cy - bh / 2 - 3 + bobY), bw * 0.17, Paint()..color = const Color(0xFFFFC107));

    _drawEyes(canvas, cx, cy - bh / 2 - 5 + bobY, bw * 0.1, expresion);

    // Antennae
    final antPaint = Paint()..color = Colors.black..strokeWidth = 1.5;
    final antW = sin((frame + 1) * pi / 3) * 3;
    canvas.drawLine(Offset(cx - 3, cy - bh / 2 - 3 + bobY), Offset(cx - 5 + antW, cy - bh / 2 - 16 + bobY), antPaint);
    canvas.drawLine(Offset(cx + 3, cy - bh / 2 - 3 + bobY), Offset(cx + 5 - antW, cy - bh / 2 - 16 + bobY), antPaint);

    // Legs
    final legPaint = Paint()..color = Colors.black..strokeWidth = 1.5;
    final legS = sin(frame * pi / 2) * 3;
    canvas.drawLine(Offset(cx - bw / 2, cy + bobY), Offset(cx - bw / 2 - 5 - legS, cy + bh * 0.3 + bobY), legPaint);
    canvas.drawLine(Offset(cx + bw / 2, cy + bobY), Offset(cx + bw / 2 + 5 + legS, cy + bh * 0.3 + bobY), legPaint);

    _drawIndicators(canvas, cx, cy, bw, bh, bobY, expresion);
    canvas.restore();
  }
}

class DesignCaterpillar extends BichitoDesign {
  DesignCaterpillar() : super('Oruga');

  @override
  void paint(Canvas canvas, Size size, int frame, Expresion expresion, bool mirandoIzq) {
    canvas.save();
    if (mirandoIzq) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final cx = size.width / 2;
    final cy = size.height / 2;
    final sr = size.width * 0.15;
    final bobY = sin(frame * pi / 2) * 2;
    final wvX = sin(frame * pi / 2) * 2;

    // Body segments
    for (int i = 0; i < 4; i++) {
      final sx = cx + (i - 1.5) * sr * 1.1 + wvX * (i % 2 == 0 ? 1 : -1);
      final sy = cy + bobY + sin((frame + i) * pi / 2) * 1.5;
      canvas.drawCircle(Offset(sx, sy), sr - i * 1.5,
          Paint()..color = i % 2 == 0 ? const Color(0xFF4CAF50) : const Color(0xFF388E3C));
    }

    // Head
    final hx = cx - 2 * sr * 1.1 + wvX;
    final hy = cy + bobY + sin(frame * pi / 2) * 1.5;
    canvas.drawCircle(Offset(hx, hy), sr + 2, Paint()..color = const Color(0xFF4CAF50));

    _drawEyes(canvas, hx - 1, hy - 2, sr * 0.45, expresion);

    // Antennae
    final antPaint = Paint()..color = Colors.black..strokeWidth = 1.5;
    final antW = sin((frame + 1) * pi / 3) * 3;
    canvas.drawLine(Offset(hx - 3, hy - sr - 2), Offset(hx - 5 + antW, hy - sr - 14), antPaint);
    canvas.drawLine(Offset(hx + 3, hy - sr - 2), Offset(hx + 5 - antW, hy - sr - 14), antPaint);

    // Legs
    for (int i = 0; i < 4; i++) {
      final lx = cx + (i - 1.5) * sr * 1.1 + wvX * (i % 2 == 0 ? 1 : -1);
      final ly = cy + bobY + sin((frame + i) * pi / 2) * 1.5;
      final legS = sin((frame + i) * pi / 2) * 2;
      canvas.drawLine(Offset(lx - 3 + legS, ly + sr - 3), Offset(lx - 3 - legS, ly + sr + 5),
          Paint()..color = Colors.black..strokeWidth = 1);
      canvas.drawLine(Offset(lx + 3 + legS, ly + sr - 3), Offset(lx + 3 - legS, ly + sr + 5),
          Paint()..color = Colors.black..strokeWidth = 1);
    }

    _drawIndicators(canvas, hx, hy, sr * 3, sr * 2, bobY, expresion);
    canvas.restore();
  }
}

void _drawEyes(Canvas canvas, double cx, double cy, double size, Expresion expresion) {
  final eo = size * 0.5;
  canvas.drawCircle(Offset(cx - eo, cy), size, Paint()..color = Colors.white);
  canvas.drawCircle(Offset(cx + eo, cy), size, Paint()..color = Colors.white);

  switch (expresion) {
    case Expresion.normal:
    case Expresion.alerta:
      canvas.drawCircle(Offset(cx - eo, cy), size * 0.5, Paint()..color = Colors.black);
      canvas.drawCircle(Offset(cx + eo, cy), size * 0.5, Paint()..color = Colors.black);
    case Expresion.durmiendo:
      final lp = Paint()..color = Colors.black..strokeWidth = 1.5;
      canvas.drawLine(Offset(cx - eo - size * 0.6, cy), Offset(cx - eo + size * 0.6, cy), lp);
      canvas.drawLine(Offset(cx + eo - size * 0.6, cy), Offset(cx + eo + size * 0.6, cy), lp);
    case Expresion.esperando:
      canvas.drawCircle(Offset(cx - eo, cy - size * 0.3), size * 0.4, Paint()..color = Colors.black);
      canvas.drawCircle(Offset(cx + eo, cy - size * 0.3), size * 0.4, Paint()..color = Colors.black);
  }
}

void _drawIndicators(Canvas canvas, double cx, double cy, double bw, double bh, double bobY, Expresion expresion) {
  if (expresion == Expresion.alerta) {
    final tp = TextPainter(
      text: TextSpan(text: '❗', style: TextStyle(fontSize: bw * 0.5)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - bh / 2 - 24 + bobY));
  }
  if (expresion == Expresion.durmiendo) {
    final tp = TextPainter(
      text: TextSpan(text: '💤', style: TextStyle(fontSize: bw * 0.35)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(cx + bw / 2 + 2, cy - bh / 2 + bobY));
  }
}

class BichitoPainter extends CustomPainter {
  final BichitoDesign design;
  final int frame;
  final Expresion expresion;
  final bool mirandoIzq;

  BichitoPainter({
    required this.design,
    required this.frame,
    this.expresion = Expresion.normal,
    this.mirandoIzq = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    design.paint(canvas, size, frame, expresion, mirandoIzq);
  }

  @override
  bool shouldRepaint(BichitoPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.expresion != expresion ||
        oldDelegate.mirandoIzq != mirandoIzq ||
        oldDelegate.design != design;
  }
}

final List<BichitoDesign> disenosDisponibles = [
  DesignLadybug(),
  DesignBee(),
  DesignCaterpillar(),
];
