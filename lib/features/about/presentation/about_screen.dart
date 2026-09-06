import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_bars.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/info_widgets.dart';
import '../../../core/widgets/section_header.dart';

/// Static information about the SUMPAY project and its architecture.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: const SumpayAppBar(title: 'About SUMPAY'),
      body: SafeArea(
        child: ContentContainer(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageInset,
              12,
              context.pageInset,
              28,
            ),
            children: <Widget>[
              Center(
                child: Column(
                  children: <Widget>[
                    Container(
                      height: 96,
                      width: 96,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Symbols.emergency_share_rounded,
                        size: 48,
                        color: Colors.white,
                        weight: 600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(AppConstants.appName,
                        style: theme.textTheme.displaySmall),
                    const SizedBox(height: 6),
                    Text(
                      AppConstants.appFullName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Version ${AppConstants.appVersion} (build ${AppConstants.appBuild})',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              const SectionHeader(title: 'What is SUMPAY?'),
              AppCard(
                child: Text(
                  'SUMPAY is an offline-first emergency communication app for barangays. When the internet and cellular networks fail during disasters, SUMPAY keeps residents connected to their barangay by relaying messages directly between nearby phones, so help can still be reached even without a signal.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              const SectionHeader(title: 'How communication flows'),
              AppCard(
                child: Column(
                  children: const <Widget>[
                    _FlowStep(
                      order: '1',
                      title: 'Resident mobile app',
                      detail: 'You compose an SOS or message on your phone.',
                    ),
                    _FlowStep(
                      order: '2',
                      title: 'Nearby devices relay',
                      detail:
                          'When you have no signal, neighbouring phones pass your message along over the SUMPAY Network.',
                    ),
                    _FlowStep(
                      order: '3',
                      title: 'Barangay',
                      detail: 'Officials and volunteers receive and respond.',
                    ),
                    _FlowStep(
                      order: '4',
                      title: 'Optional cloud sync',
                      detail:
                          'Records upload only after normal connectivity returns.',
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              const SectionHeader(title: 'Project details'),
              AppCard(
                child: Column(
                  children: const <Widget>[
                    DetailRow(
                      label: 'Type',
                      value: 'College capstone prototype',
                      icon: Symbols.school_rounded,
                    ),
                    DetailRow(
                      label: 'Stage',
                      value: 'UI prototype (front-end only)',
                      icon: Symbols.design_services_rounded,
                    ),
                    DetailRow(
                      label: 'Framework',
                      value: 'Flutter • Material 3',
                      icon: Symbols.smartphone_rounded,
                    ),
                    DetailRow(
                      label: 'Connectivity',
                      value: 'SUMPAY Network • Internet sync',
                      icon: Symbols.hub_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              AppCard(
                color: AppColors.warningSoft,
                borderColor: AppColors.warning.withValues(alpha: 0.3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Symbols.construction_rounded,
                      size: 22,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This build is a UI prototype. Backend services, the LoRa link, Bluetooth mesh and cloud sync are represented by placeholder data pending adviser approval and integration.',
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.sectionGap),
              Center(
                child: Text(
                  AppConstants.organisation,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium,
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '© ${DateTime.now().year} SUMPAY. For academic use.',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.order,
    required this.title,
    required this.detail,
    this.isLast = false,
  });

  final String order;
  final String title;
  final String detail;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    order,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: theme.dividerColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
