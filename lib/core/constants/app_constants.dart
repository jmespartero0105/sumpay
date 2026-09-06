/// Static, compile-time application constants.
class AppConstants {
  const AppConstants._();

  static const String appName = 'SUMPAY';
  static const String appFullName =
      'Smart Unified Mesh Platform for Area Yielding-Response';
  static const String appVersion = '1.0.0';
  static const String appBuild = '1';
  static const String organisation = 'Barangay Disaster Risk Reduction Office';

  static const double pagePadding = 20;
  static const double sectionGap = 22;
  static const double cardGap = 14;

  static const double tabletBreakpoint = 720;
  static const double desktopBreakpoint = 1100;

  static const Duration shortAnim = Duration(milliseconds: 200);
  static const Duration mediumAnim = Duration(milliseconds: 350);
  static const Duration longAnim = Duration(milliseconds: 650);

  /// Simulated splash bootstrap duration.
  static const Duration bootstrapDelay = Duration(milliseconds: 2200);

  /// Lottie asset paths. Files are optional; widgets degrade gracefully.
  static const String lottieEmergency = 'assets/lottie/emergency_pulse.json';
  static const String lottieMesh = 'assets/lottie/mesh_network.json';
  static const String lottieEmpty = 'assets/lottie/empty_state.json';
  static const String lottieSuccess = 'assets/lottie/success_check.json';
}
