import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_theme.dart';

/// Labelled text field with large touch target and consistent styling.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.helperText,
    this.onChanged,
    this.textInputAction,
    this.readOnly = false,
    this.onTap,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? minLines;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          onChanged: onChanged,
          textInputAction: textInputAction,
          readOnly: readOnly,
          onTap: onTap,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            helperStyle: theme.textTheme.bodySmall,
            prefixIcon: prefixIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: Icon(prefixIcon, size: 22),
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

/// Rounded search field used on list screens.
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.trailing,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: theme.textTheme.bodyLarge,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              prefixIcon: const Icon(Symbols.search_rounded, size: 22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
            ),
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 10),
          trailing!,
        ],
      ],
    );
  }
}

/// Horizontally scrolling single-select filter row.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final bool selected = index == selectedIndex;
          return ChoiceChip(
            label: Text(labels[index]),
            selected: selected,
            onSelected: (_) => onSelected(index),
            showCheckmark: false,
            labelStyle: theme.textTheme.labelMedium?.copyWith(
              color: selected ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: theme.colorScheme.surface,
            selectedColor: theme.colorScheme.primary,
            side: BorderSide(
              color: selected ? theme.colorScheme.primary : theme.dividerColor,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          );
        },
      ),
    );
  }
}
