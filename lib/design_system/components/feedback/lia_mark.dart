import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../theme/app_colors.dart';

/// Asterisco de [points] pontas — braços retangulares cruzando o centro,
/// no estilo da marca (não existe no Lucide com 5 pontas).
class LiaBurstIcon extends StatelessWidget {
  const LiaBurstIcon({
    super.key,
    this.size = 16,
    this.color = AppColors.notebook,
    this.points = 5,
  });

  final double size;
  final Color color;
  final int points;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BurstPainter(color: color, points: points),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter({required this.color, required this.points});

  final Color color;
  final int points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final side = size.shortestSide;
    final armWidth = side * 0.30;
    final armLength = side * 0.5;
    final hub = armWidth * 0.5;

    canvas.translate(size.width / 2, size.height / 2);
    canvas.drawCircle(Offset.zero, hub, paint);
    for (var i = 0; i < points; i++) {
      canvas.save();
      canvas.rotate(i * (2 * math.pi / points) - math.pi / 2);
      canvas.drawRect(
        Rect.fromLTWH(-armWidth / 2, -armLength, armWidth, armLength),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.points != points;
  }
}

/// Chip da LIA no topo da home — amarelo cheio da marca.
class LiaChip extends StatelessWidget {
  const LiaChip({super.key, required this.onTap, this.label = 'LIA'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.yellowPale.withValues(alpha: 0.55),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: const BoxDecoration(
            color: AppColors.yellowPale,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            splashColor: AppColors.heading.withValues(alpha: 0.08),
            highlightColor: AppColors.heading.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LiaBurstIcon(size: 18),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marca circular da LIA — o ícone pulsa e o halo acompanha.
class LiaPulseMark extends StatefulWidget {
  const LiaPulseMark({
    super.key,
    this.size = 72,
    this.iconSize = 28,
    this.pulse = true,
  });

  final double size;
  final double iconSize;
  final bool pulse;

  @override
  State<LiaPulseMark> createState() => _LiaPulseMarkState();
}

class _LiaPulseMarkState extends State<LiaPulseMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.pulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LiaPulseMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse == oldWidget.pulse) return;
    if (widget.pulse) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.lia,
      ),
      child: Icon(
        LucideIcons.astroid,
        color: AppColors.heading,
        size: widget.iconSize,
      ),
    );

    if (!widget.pulse) {
      return mark;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = 0.94 + (0.08 * t);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.lia.withValues(alpha: 0.16 + 0.2 * t),
                blurRadius: 16 + 14 * t,
                spreadRadius: 1 + 5 * t,
              ),
            ],
          ),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: mark,
    );
  }
}

/// Ilustração de corpo inteiro da LIA — pose de árvore, mãos unidas. Usada
/// nos momentos em que ela é a protagonista da tela (ex: preparando algo),
/// não como marca pequena recorrente (pra isso, ver [LiaPulseMark]).
class LiaFigure extends StatefulWidget {
  const LiaFigure({super.key, this.height = 200, this.pulse = true});

  final double height;
  final bool pulse;

  @override
  State<LiaFigure> createState() => _LiaFigureState();
}

class _LiaFigureState extends State<LiaFigure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.pulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LiaFigure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse == oldWidget.pulse) return;
    if (widget.pulse) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/lia/lia_tree_pose.png',
      height: widget.height,
      fit: BoxFit.contain,
    );

    if (!widget.pulse) {
      return image;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = 0.96 + (0.08 * t);
        return Transform.scale(scale: scale, child: child);
      },
      child: image,
    );
  }
}
