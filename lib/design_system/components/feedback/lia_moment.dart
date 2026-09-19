import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Estados ilustrados da LIA na espera — as quatro poses de árvore.
enum LiaMood {
  idle,
  esperando,
  pensando,
  comemorando;

  String get asset => switch (this) {
    idle => 'assets/images/lia/lia_idle.png',
    esperando => 'assets/images/lia/lia_esperando.png',
    pensando => 'assets/images/lia/lia_pensando.png',
    comemorando => 'assets/images/lia/lia_comemorando.png',
  };

  static const waitCycle = [esperando, pensando, comemorando];
}

/// Ilustração da LIA. Troca de pose com fade; pulso leve no corpo.
class LiaFigure extends StatefulWidget {
  const LiaFigure({
    super.key,
    this.mood = LiaMood.esperando,
    this.height = 240,
    this.pulse = true,
  });

  final LiaMood mood;
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
      duration: const Duration(milliseconds: 1800),
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
    final image = AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Image.asset(
        widget.mood.asset,
        key: ValueKey(widget.mood),
        height: widget.height,
        fit: BoxFit.contain,
      ),
    );

    if (!widget.pulse) return image;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(scale: 0.96 + (0.06 * t), child: child);
      },
      child: image,
    );
  }
}

/// Bloco central da espera da LIA — figura, marca, título, microtexto e
/// os três pontos do mock (LiaMoment).
class LiaWaitScene extends StatefulWidget {
  const LiaWaitScene({
    super.key,
    required this.title,
    required this.steps,
    this.hasError = false,
    this.figureHeight = 240,
  });

  final String title;
  final List<String> steps;
  final bool hasError;
  final double figureHeight;

  @override
  State<LiaWaitScene> createState() => _LiaWaitSceneState();
}

class _LiaWaitSceneState extends State<LiaWaitScene> {
  var _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(LiaWaitScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError != oldWidget.hasError) {
      _timer?.cancel();
      if (!widget.hasError) _startTimer();
    }
  }

  void _startTimer() {
    if (widget.hasError || widget.steps.length <= 1) return;
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.steps.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final mood = widget.hasError
        ? LiaMood.idle
        : LiaMood.waitCycle[_index % LiaMood.waitCycle.length];
    final hint = widget.hasError
        ? 'Você pode voltar e tentar de novo.'
        : widget.steps[_index];
    final hintColor = widget.hasError
        ? AppColors.foreground
        : AppColors.heading.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LiaFigure(
            mood: mood,
            height: widget.figureHeight,
            pulse: !widget.hasError,
          ),
          const SizedBox(height: 20),
          Text(
            'LIA',
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.heading,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: textTheme.displaySmall?.copyWith(
                color: AppColors.heading,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: Text(
                hint,
                key: ValueKey(_index),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: hintColor,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (!widget.hasError) ...[
            const SizedBox(height: 4),
            _WaitDots(
              count: widget.steps.length.clamp(1, 3),
              active: _index % widget.steps.length.clamp(1, 3),
            ),
          ],
        ],
      ),
    );
  }
}

class _WaitDots extends StatelessWidget {
  const _WaitDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == active
                  ? AppColors.heading
                  : AppColors.heading.withValues(alpha: 0.25),
            ),
          ),
        ],
      ],
    );
  }
}
