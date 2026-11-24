import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key, required this.message, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: AppColors.outline),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
          ]),
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ]),
        ),
      );
}

/// Horizontal single-choice chips ("Tous" first), Stitch style: selected chip is
/// navy with white text, the others light blue. [selected] == null means "Tous".
class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow(
      {super.key, required this.options, required this.selected, required this.onChanged});
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool on, VoidCallback tap) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: on,
            onSelected: (_) => tap(),
            showCheckmark: false,
            selectedColor: AppColors.primaryContainer,
            backgroundColor: const Color(0xFFDCE9FF),
            side: BorderSide.none,
            shape: const StadiumBorder(),
            labelStyle: TextStyle(
                color: on ? Colors.white : AppColors.primary, fontWeight: FontWeight.w700),
          ),
        );
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('Tous', selected == null, () => onChanged(null)),
          for (final o in options) chip(o, selected == o, () => onChanged(o)),
        ],
      ),
    );
  }
}
