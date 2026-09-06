import 'package:flutter/widgets.dart';

import '../constants/app_constants.dart';

/// Convenience helpers for adapting layout between phones and tablets.
extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);

  double get screenWidth => MediaQuery.sizeOf(this).width;

  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isPhone => screenWidth < AppConstants.tabletBreakpoint;

  bool get isTablet =>
      screenWidth >= AppConstants.tabletBreakpoint &&
      screenWidth < AppConstants.desktopBreakpoint;

  bool get isWide => screenWidth >= AppConstants.tabletBreakpoint;

  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;

  /// Grid column count that keeps touch targets comfortable.
  int gridColumns({int phone = 2, int tablet = 3, int desktop = 4}) {
    if (screenWidth >= AppConstants.desktopBreakpoint) return desktop;
    if (screenWidth >= AppConstants.tabletBreakpoint) return tablet;
    return phone;
  }

  /// Horizontal page padding that grows on larger canvases.
  double get pageInset =>
      isWide ? AppConstants.pagePadding * 1.6 : AppConstants.pagePadding;

  /// Maximum content width so text never becomes uncomfortably long.
  double get contentMaxWidth {
    // Use more of the viewport on larger screens so desktop web doesn't waste
    // space with narrow centred content, while staying readable on phones.
    if (screenWidth >= 1400) return 1280;
    if (screenWidth >= 1100) return 1040;
    if (isWide) return 900;
    return double.infinity;
  }
}

/// Constrains a child to a readable width and centres it on large screens.
class ContentContainer extends StatelessWidget {
  const ContentContainer({
    super.key,
    required this.child,
    this.maxWidth,
  });

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? context.contentMaxWidth,
        ),
        child: child,
      ),
    );
  }
}
