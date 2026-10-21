import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/sign_svg.dart';
import '../../core/swu_parser.dart';
import '../../data/models.dart';
import '../../services/sign_image_service.dart';
import '../theme.dart';
import 'sign_writing_canvas.dart';

/// Moldura com o desenho SignWriting do sinal renderizado nativamente ou via SVG de fallback.
class SignWritingImage extends StatefulWidget {
  const SignWritingImage({
    super.key,
    required this.entry,
    this.height = 148,
    this.interactive = false,
    this.padding = const EdgeInsets.all(14),
  });

  final SignEntry entry;
  final double height;
  final bool interactive;
  final EdgeInsets padding;

  @override
  State<SignWritingImage> createState() => _SignWritingImageState();
}

class _SignWritingImageState extends State<SignWritingImage> {
  Future<Uint8List?>? _future;
  SwuSignLayout? _layout;

  @override
  void initState() {
    super.initState();
    _resolveSign();
  }

  @override
  void didUpdateWidget(covariant SignWritingImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.key != widget.entry.key ||
        oldWidget.entry.sign != widget.entry.sign) {
      _resolveSign();
    }
  }

  void _resolveSign() {
    if (widget.entry.hasImage) {
      _layout = SwuParser.parse(widget.entry.sign);
      if (_layout == null) {
        // Fallback para serviço de imagem (SVG / rede) se o SWU não puder ser parseado diretamente
        _future = SignImageService.instance.load(widget.entry);
      } else {
        _future = null;
      }
    } else {
      _layout = null;
      _future = null;
    }
  }

  void _retry() {
    setState(() {
      _resolveSign();
      if (_layout == null && widget.entry.hasImage) {
        _future = SignImageService.instance.load(widget.entry, force: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final containerColor =
        isDark ? const Color(0xFF1E232A) : AppColors.paper;
    final borderColor =
        isDark ? const Color(0xFF3B414A) : const Color(0xFFE3DDD3);
    final lineColor =
        isDark ? Colors.white : const Color(0xFF1B1C1E);
    final fillColor =
        isDark ? const Color(0xFF1E232A) : Colors.white;

    Widget body;

    if (_layout != null && !_layout!.isEmpty) {
      // 1. Renderização nativa e offline com fontes TrueType
      body = Padding(
        padding: widget.padding,
        child: SignWritingCanvas(
          layout: _layout!,
          lineColor: lineColor,
          fillColor: fillColor,
          interactive: widget.interactive,
          padding: EdgeInsets.zero,
        ),
      );
    } else if (!widget.entry.hasImage) {
      // 2. Sinal explicitamente sem desenho
      body = const _ImageMessage(
        icon: Icons.draw_outlined,
        message: 'Sinal sem desenho disponível.',
      );
    } else {
      // 3. Fallback assíncrono (SVG em cache/rede)
      body = FutureBuilder<Uint8List?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            );
          }
          if (snapshot.hasError) {
            return _ImageMessage(
              icon: Icons.cloud_off_outlined,
              message: 'Não foi possível carregar o sinal.',
              onRetry: _retry,
              compact: widget.height < 170,
            );
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return const _ImageMessage(
              icon: Icons.draw_outlined,
              message: 'Sinal sem desenho disponível.',
            );
          }
          final svg = Padding(
            padding: widget.padding,
            child: SvgPicture.memory(
              normalizeSignPuddleSvg(bytes),
              fit: BoxFit.contain,
              semanticsLabel: widget.entry.title,
            ),
          );
          if (!widget.interactive) return svg;
          return InteractiveViewer(
            minScale: 0.7,
            maxScale: 5,
            boundaryMargin: const EdgeInsets.all(24),
            child: svg,
          );
        },
      );
    }

    return Semantics(
      label: 'Desenho em SignWriting de ${widget.entry.title}',
      image: true,
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: body,
      ),
    );
  }
}

class _ImageMessage extends StatelessWidget {
  const _ImageMessage({
    required this.icon,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: const Color(0xFF7A7F87)),
              const SizedBox(height: 4),
              Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF5E646D),
                  fontSize: 10.5,
                  height: 1.25,
                ),
              ),
              if (onRetry != null)
                IconButton(
                  onPressed: onRetry,
                  tooltip: 'Tentar novamente',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 28,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: const Color(0xFF7A7F87)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF5E646D),
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(48, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Tentar novamente'),
              ),
          ],
        ),
      ),
    );
  }
}
