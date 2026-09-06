import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/lottie_placeholder.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/onboarding_page.dart';

/// First-launch introduction to the SUMPAY communication model.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == OnboardingData.pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(authProvider.notifier).completeOnboarding();
    context.go(AppRoutes.login);
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: AppConstants.mediumAnim,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ContentContainer(
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 6),
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: OnboardingData.pages.length,
                  onPageChanged: (int value) => setState(() => _index = value),
                  itemBuilder: (BuildContext context, int index) {
                    final OnboardingPage page = OnboardingData.pages[index];
                    return _OnboardingSlide(page: page);
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.pageInset,
                  8,
                  context.pageInset,
                  20,
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(
                        OnboardingData.pages.length,
                        (int i) => AnimatedContainer(
                          duration: AppConstants.shortAnim,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: i == _index ? 26 : 8,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? theme.colorScheme.primary
                                : theme.dividerColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    FilledButton(
                      onPressed: _next,
                      child: Text(_isLast ? 'Get started' : 'Continue'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.page});

  final OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.pageInset),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          LottiePlaceholder(
            asset: page.lottieAsset,
            fallbackIcon: page.icon,
            color: page.accent,
            size: context.isWide ? 260 : 210,
          ),
          const SizedBox(height: 44),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(height: 1.2),
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
