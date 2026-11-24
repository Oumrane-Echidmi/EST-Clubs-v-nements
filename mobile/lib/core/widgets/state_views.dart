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
