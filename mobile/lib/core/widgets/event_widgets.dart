import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/events/domain/event.dart';
import '../../features/events/domain/registration_state.dart';
import '../theme/app_theme.dart';

/// ONE shared clock for the whole app: emits every second.
/// Every CountdownChip watches this, so we never create many timers.
final tickerProvider = StreamProvider<DateTime>((ref) =>
    Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now().toUtc()));

class StatusChip extends StatelessWidget {
  const StatusChip(this.state, {super.key});
  final RegistrationState state;
  @override
  Widget build(BuildContext context) {
    final c = state.color(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm + 4, vertical: AppSpacing.xs + 2),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Text(state.label,
          style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class CountdownChip extends ConsumerWidget {
  const CountdownChip({super.key, required this.target, this.serverOffset = Duration.zero});
  final DateTime target;
  final Duration serverOffset;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(tickerProvider).value ?? DateTime.now().toUtc();
    return Chip(
      avatar: const Icon(Icons.timer_outlined, size: 16),
      label: Text(formatCountdown(target, now, serverOffset: serverOffset)),
    );
  }
}

/// Poster-first card. It only DISPLAYS backend state; tapping is up to the caller.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.onTap});
  final Event event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final local = event.startAt.toLocal();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: event.posterUrl == null
                ? Container(
                    color: AppColors.primaryContainer,
                    child: const Icon(Icons.event, color: Colors.white, size: 48))
                : CachedNetworkImage(
                    imageUrl: event.posterUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const ColoredBox(color: Colors.black12),
                    errorWidget: (_, _, _) => const Icon(Icons.broken_image)),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              Text('${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}'
                  '${event.location == null ? '' : ' · ${event.location}'}'),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                StatusChip(event.registrationState),
                const Spacer(),
                if (event.availableSeats != null)
                  Text('${event.availableSeats} places'),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
