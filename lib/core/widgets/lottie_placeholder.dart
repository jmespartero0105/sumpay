import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Renders a Lottie animation when the asset is bundled, and falls back to an
/// animated icon badge when it is not.
///
/// This keeps the prototype runnable before the design team supplies the final
/// motion assets, without any code changes required later.
class LottiePlaceholder extends StatelessWidget {
  const LottiePlaceholder({
    super.key,
    required this.asset,
    required this.fallbackIcon,
    this.size = 160,
    this.repeat = true,
    this.color,
  });

  final String asset;
  final IconData fallbackIcon;
  final double size;
  final bool repeat;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color accent = color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: size,
      width: size,
      child: Lottie.asset(
        asset,
        repeat: repeat,
        fit: BoxFit.contain,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return _FallbackPulse(icon: fallbackIcon, color: accent, size: size);
        },
      ),
    );
  }
}

class _FallbackPulse extends StatefulWidget {
  const _FallbackPulse({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  State<_FallbackPulse> createState() => _FallbackPulseState();
}

class _FallbackPulseState extends State<_FallbackPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeInOut.transform(_controller.value);
        return Center(
          child: Container(
            height: widget.size * (0.62 + (t * 0.12)),
            width: widget.size * (0.62 + (t * 0.12)),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.10 + (t * 0.06)),
            ),
            child: Icon(
              widget.icon,
              size: widget.size * 0.32,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}
