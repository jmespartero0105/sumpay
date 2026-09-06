import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';

/// Large, pulsing emergency trigger used on the home dashboard.
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.reduceMotion = false,
  });

  final VoidCallback onPressed;
  final bool enabled;
  final bool reduceMotion;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant SosButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion && _controller.isAnimating) {
      _controller.stop();
    } else if (!widget.reduceMotion && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Send emergency SOS',
      child: SizedBox(
        height: 300,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  if (!widget.reduceMotion) ...<Widget>[
                    _Ripple(progress: _controller.value),
                    _Ripple(progress: (_controller.value + 0.5) % 1.0),
                  ],
                  child!,
                ],
              );
            },
            child: GestureDetector(
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.enabled ? widget.onPressed : null,
              child: AnimatedScale(
                scale: _pressed ? 0.94 : 1.0,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                child: Container(
                  height: 220,
                  width: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[AppColors.secondary, AppColors.primary],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.36),
                        blurRadius: 34,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Symbols.sos_rounded,
                        size: 68,
                        color: Colors.white,
                        weight: 700,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'EMERGENCY',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Tap to send',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ripple extends StatelessWidget {
  const _Ripple({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final double eased = Curves.easeOut.transform(progress);
    return Container(
      height: 220 + (eased * 70),
      width: 220 + (eased * 70),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.16 * (1 - eased)),
      ),
    );
  }
}
