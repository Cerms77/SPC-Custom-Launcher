// Painted northern-lights scene inspired by the approved Aurora mockup.
// Unlike an enlarged low-resolution JPG, this stays smooth on UHD screens.
import 'dart:math' as math;
import 'package:flutter/material.dart';

class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(child: CustomPaint(painter: _AuroraPainter()));
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0, .25, .43, .58, .74, 1],
        colors: [
          Color(0xFF020A25),
          Color(0xFF11164A),
          Color(0xFF183480),
          Color(0xFF5563A5),
          Color(0xFF072A63),
          Color(0xFF030D32),
        ],
      ).createShader(Offset.zero & size),
    );

    // Wide, soft aurora curtains: teal on the left and right, purple at center.
    _glow(canvas, size, .16, .30, .30, .29, const Color(0xFF06FFB6), .85);
    _glow(canvas, size, .54, .27, .25, .28, const Color(0xFF9F36FA), .77);
    _glow(canvas, size, .80, .37, .36, .26, const Color(0xFF02DFEE), .69);
    _glow(canvas, size, .30, .43, .26, .16, const Color(0xFF36B6FF), .28);
    _glow(canvas, size, .96, .51, .24, .16, const Color(0xFFFF87CD), .29);

    final curtains = <(double, double, double, Color)>[
      (.12, .07, .25, const Color(0xFF00E7CB)),
      (.21, .13, .34, const Color(0xFF49FFB6)),
      (.36, .03, .29, const Color(0xFF27DECC)),
      (.50, .11, .27, const Color(0xFFB64CFF)),
      (.62, .15, .39, const Color(0xFF38F7F5)),
      (.79, .03, .29, const Color(0xFF06D6C8)),
      (.91, .13, .27, const Color(0xFF24C7F3)),
    ];
    for (final c in curtains) {
      final x = c.$1 * w;
      final top = c.$2 * h;
      final bottom = c.$3 * h + .17 * h;
      final path = Path()
        ..moveTo(x - .055 * w, top)
        ..cubicTo(x - .11 * w, .20 * h, x + .03 * w, .36 * h, x - .03 * w, bottom)
        ..quadraticBezierTo(x + .08 * w, bottom + .015 * h, x + .07 * w, .24 * h)
        ..quadraticBezierTo(x + .055 * w, top, x - .055 * w, top)
        ..close();
      canvas.drawPath(path, Paint()
        ..color = c.$4.withOpacity(.20)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * .035));
      canvas.drawPath(path, Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.$4.withOpacity(.03), c.$4.withOpacity(.34),
                   c.$4.withOpacity(.02)],
        ).createShader(Rect.fromLTWH(x - w * .08, top, w * .16, bottom - top)));
    }

    // Fine stars, deterministic so the background never flickers.
    int seed = 82971;
    double random() {
      seed = (seed * 1664525 + 1013904223) & 0x7fffffff;
      return seed / 0x7fffffff;
    }
    for (var i = 0; i < 275; i++) {
      final x = random() * w;
      final y = random() * h * .54;
      final r = (random() * .85 + .20) * (w / 1672).clamp(.5, 1.5);
      final alpha = .18 + random() * .65;
      canvas.drawCircle(Offset(x, y), r, Paint()
        ..color = Colors.white.withOpacity(alpha));
    }

    // Distant snowy mountains, inspired by the reference panorama.
    _mountain(canvas, size, [
      Offset(0, h * .53), Offset(w * .11, h * .465),
      Offset(w * .23, h * .49), Offset(w * .34, h * .56),
      Offset(w * .48, h * .575), Offset(w * .59, h * .54),
      Offset(w * .72, h * .49), Offset(w * .89, h * .43),
      Offset(w, h * .46), Offset(w, h * .70), Offset(0, h * .70)
    ], const Color(0xFFBCB9F5), const Color(0xFF335AA3));
    _mountain(canvas, size, [
      Offset(0, h * .51), Offset(w * .12, h * .475),
      Offset(w * .26, h * .55), Offset(w * .47, h * .60),
      Offset(w * .62, h * .58), Offset(w * .79, h * .51),
      Offset(w * .90, h * .442), Offset(w, h * .47),
      Offset(w, h * .68), Offset(0, h * .68)
    ], const Color(0xFFE7BDEE), const Color(0xFF5B79CC));

    // A low dark pine forest and the lake's shoreline.
    canvas.drawRect(Rect.fromLTWH(0, h * .658, w, h * .034),
        Paint()..color = const Color(0xFF061A46));
    for (var i = 0; i < 170; i++) {
      final x = random() * w;
      final treeH = h * (.035 + random() * .075);
      final bottom = h * (.672 + random() * .016);
      final tree = Path()
        ..moveTo(x, bottom - treeH)
        ..lineTo(x - treeH * .21, bottom - treeH * .48)
        ..lineTo(x - treeH * .11, bottom - treeH * .48)
        ..lineTo(x - treeH * .31, bottom)
        ..lineTo(x + treeH * .31, bottom)
        ..lineTo(x + treeH * .11, bottom - treeH * .48)
        ..lineTo(x + treeH * .21, bottom - treeH * .48)
        ..close();
      canvas.drawPath(tree, Paint()
        ..color = Color.lerp(const Color(0xFF020D31),
            const Color(0xFF0D3460), random() * .5)!);
    }

    // Glassy lake: deep-blue base, teal/purple reflections, thin ripples.
    final lake = Rect.fromLTWH(0, h * .69, w, h * .31);
    canvas.drawRect(lake, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFF0A3D7A), Color(0xFF0B2762), Color(0xFF031638)],
    ).createShader(lake));
    for (final c in [
      (.17, .10, const Color(0xFF00DCC6)),
      (.51, .14, const Color(0xFFB04BE8)),
      (.79, .12, const Color(0xFF21C6E8)),
    ]) {
      final x = c.$1 * w;
      canvas.drawRect(Rect.fromLTWH(x - c.$2 * w, h * .69, c.$2 * 2 * w, h * .31),
        Paint()
          ..shader = RadialGradient(colors: [
            c.$3.withOpacity(.40), c.$3.withOpacity(0),
          ]).createShader(Rect.fromCenter(
            center: Offset(x, h * .83), width: c.$2 * 2 * w, height: h * .50,
          )));
    }
    for (var i = 0; i < 160; i++) {
      final y = h * (.70 + random() * .29);
      final x = random() * w;
      final length = (4 + random() * 80) * w / 1672;
      canvas.drawLine(Offset(x, y), Offset(x + length, y),
        Paint()..color = (i.isEven ? const Color(0xFF58B1D7)
                         : const Color(0xFFBC66DC)).withOpacity(.05 + random() * .14)
          ..strokeWidth = .6);
    }
    // Subtle dark edge wash leaves text/controls legible over the sky.
    canvas.drawRect(Offset.zero & size, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0, .17, .48, .79, 1],
        colors: [Color(0x51020721), Colors.transparent,
                 Colors.transparent, Color(0x11030920), Color(0x40020516)],
      ).createShader(Offset.zero & size));
  }

  void _glow(Canvas c, Size s, double x, double y, double rx,
      double ry, Color color, double strength) {
    final rect = Rect.fromCenter(
        center: Offset(s.width * x, s.height * y),
        width: s.width * rx * 2, height: s.height * ry * 2);
    c.drawOval(rect, Paint()..shader = RadialGradient(
      colors: [color.withOpacity(strength * .52),
        color.withOpacity(strength * .18), color.withOpacity(0)],
      stops: const [0, .52, 1],
    ).createShader(rect));
  }

  void _mountain(Canvas c, Size s, List<Offset> pts, Color snow, Color base) {
    final path = Path()..addPolygon(pts, true);
    c.drawPath(path, Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [snow, base],
    ).createShader(Rect.fromLTWH(0, s.height * .43, s.width, s.height * .28)));
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => false;
}
