import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/theme/app_theme.dart';

/// Selectable grid of emergency categories.
class EmergencyTypeGrid extends StatelessWidget {
  const EmergencyTypeGrid({
    super.key,
    required this.selected,
    this.additional = const <EmergencyType>[],
    required this.onSelected,
    this.onSetMain,
    required this.columns,
  });

  final EmergencyType? selected;
  final List<EmergencyType> additional;
  final ValueChanged<EmergencyType> onSelected;
  final ValueChanged<EmergencyType>? onSetMain;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final List<EmergencyType> types = EmergencyType.residentSelectable;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: types.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.98,
      ),
      itemBuilder: (BuildContext context, int index) {
        final EmergencyType type = types[index];
        final bool isPrimary = type == selected;
        final bool isAdditional = additional.contains(type);
        return _TypeTile(
          type: type,
          isSelected: isPrimary || isAdditional,
          isPrimary: isPrimary,
          onTap: () => onSelected(type),
          onSetMain: (isAdditional && onSetMain != null)
              ? () => onSetMain!(type)
              : null,
        );
      },
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.isSelected,
    required this.isPrimary,
    required this.onTap,
    this.onSetMain,
  });

  final EmergencyType type;
  final bool isSelected;
  final bool isPrimary;
  final VoidCallback onTap;
  final VoidCallback? onSetMain;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${type.label} emergency',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onSetMain,
        child: AnimatedContainer(
          duration: AppConstants.shortAnim,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isSelected
                ? type.color.withValues(alpha: 0.13)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isSelected ? type.color : theme.dividerColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: <Widget>[
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      type.icon,
                      size: 30,
                      color: isSelected
                          ? type.color
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                      fill: isSelected ? 1 : 0,
                    ),
                    const SizedBox(height: 9),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        type.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isSelected
                              ? type.color
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.75),
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Icon(
                    Symbols.check_circle_rounded,
                    size: 17,
                    color: type.color,
                    fill: 1,
                  ),
                ),
              if (isPrimary)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: type.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'MAIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
