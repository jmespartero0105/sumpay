import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

/// A single onboarding slide.
class OnboardingPage {
  const OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.lottieAsset,
    required this.accent,
  });

  final String title;
  final String description;
  final IconData icon;
  final String lottieAsset;
  final Color accent;
}

/// Content shown on first launch.
class OnboardingData {
  const OnboardingData._();

  static const List<OnboardingPage> pages = <OnboardingPage>[
    OnboardingPage(
      title: 'Help reaches you\nwithout the internet',
      description:
          'SUMPAY sends your emergency signal over a LoRa radio backbone. When cell towers and broadband fail, your barangay still hears you.',
      icon: Symbols.settings_input_antenna_rounded,
      lottieAsset: AppConstants.lottieMesh,
      accent: AppColors.primary,
    ),
    OnboardingPage(
      title: 'One tap to raise\nan emergency',
      description:
          'Choose the type of help you need, set the priority, and send. Your location and medical profile travel with the request automatically.',
      icon: Symbols.sos_rounded,
      lottieAsset: AppConstants.lottieEmergency,
      accent: AppColors.emergency,
    ),
    OnboardingPage(
      title: 'Neighbours extend\nthe network',
      description:
          'If no gateway is in range, nearby phones relay your message over Bluetooth or Wi-Fi Direct until it reaches an ESP32 node.',
      icon: Symbols.hub_rounded,
      lottieAsset: AppConstants.lottieMesh,
      accent: AppColors.info,
    ),
    OnboardingPage(
      title: 'Stay informed,\nstay accounted for',
      description:
          'Receive barangay broadcasts, acknowledge advisories and report your household status so responders know where everyone is.',
      icon: Symbols.campaign_rounded,
      lottieAsset: AppConstants.lottieSuccess,
      accent: AppColors.success,
    ),
  ];
}
