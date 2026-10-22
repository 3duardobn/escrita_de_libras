import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/swu_parser.dart';

/// Widget que renderiza um sinal de SignWriting nativamente no Canvas
/// usando as fontes SuttonSignWritingLine e SuttonSignWritingFill.
class SignWritingCanvas extends StatelessWidget {
  const SignWritingCanvas({
    super.key,
    required this.layout,
    this.lineColor,
    this.fillColor = Colors.white,
    this.padding = const EdgeInsets.all(8),
    this.interactive = false,
  });

  /// Layout já parseado do sinal.
  final SwuSignLayout layout;

  /// Cor dos traços do sinal (se nulo, usa Theme.of(context).colorScheme.onSurface).
  final Color? lineColor;

  /// Cor do preenchimento interno dos símbolos (padrão branco).
  final Color fillColor;

  /// Espaçamento interno.
  final EdgeInsets padding;

  /// Se verdadeiro, permite zoom e pan via InteractiveViewer.
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveLineColor = lineColor ??
        (isDark ? theme.colorScheme.onSurface : const Color(0xFF1E2229));
    final effectiveFillColor = fillColor;

    Widget content = CustomPaint(
      painter: _SignWritingPainter(
        layout: layout,
        lineColor: effectiveLineColor,
        fillColor: effectiveFillColor,
        padding: padding,
      ),
      size: Size.infinite,
    );

    if (interactive) {
      content = InteractiveViewer(
        minScale: 0.3,
        maxScale: 6.0,
        boundaryMargin: const EdgeInsets.all(80),
        clipBehavior: Clip.none,
        panAxis: PanAxis.free,
        child: content,
      );
    }

    return content;
  }
}

class _SignWritingPainter extends CustomPainter {
  _SignWritingPainter({
    required this.layout,
    required this.lineColor,
    required this.fillColor,
    required this.padding,
  });

  final SwuSignLayout layout;
  final Color lineColor;
  final Color fillColor;
  final EdgeInsets padding;

  @override
  void paint(Canvas canvas, Size size) {
    if (layout.isEmpty) return;

    final availW = math.max(10.0, size.width - padding.horizontal);
    final availH = math.max(10.0, size.height - padding.vertical);

    // Escala para caber no container mantendo a proporção original
    final scaleX = availW / layout.width;
    final scaleY = availH / layout.height;
    final scale = math.min(scaleX, scaleY);

    // Tamanho da fonte escalonado proporcionalmente (base oficial = 30px)
    final fontSize = 30.0 * scale;

    // Centraliza o sinal dentro da área disponível
    final renderedW = layout.width * scale;
    final renderedH = layout.height * scale;
    final originX = padding.left + (availW - renderedW) / 2;
    final originY = padding.top + (availH - renderedH) / 2;

    for (final spatial in layout.spatials) {
      final dx = originX + (spatial.x - layout.minX) * scale;
      final dy = originY + (spatial.y - layout.minY) * scale;

      // 1. Camada de Preenchimento (Fill)
      final fillPainter = TextPainter(
        text: TextSpan(
          text: spatial.fillChar,
          style: TextStyle(
            fontFamily: 'SuttonSignWritingFill',
            fontSize: fontSize,
            color: fillColor,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      fillPainter.layout();
      fillPainter.paint(canvas, Offset(dx, dy));

      // 2. Camada de Contorno (Line)
      final linePainter = TextPainter(
        text: TextSpan(
          text: spatial.lineChar,
          style: TextStyle(
            fontFamily: 'SuttonSignWritingLine',
            fontSize: fontSize,
            color: lineColor,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      linePainter.layout();
      linePainter.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _SignWritingPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.padding != padding;
  }
}
