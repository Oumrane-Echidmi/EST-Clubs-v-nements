import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/events/domain/event.dart';
import '../../features/events/domain/registration_state.dart';
import '../theme/app_theme.dart';
import 'app_images.dart';

/// ONE shared clock for the whole app: emits every second.
/// Every CountdownChip watches this, so we never create many timers.
final tickerProvider = StreamProvider<DateTime>((ref) =>
    Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now().toUtc()));

const _orange = Color(0xFFF97316); // Stitch CTA orange
const _navy = AppColors.primaryContainer;

String _two(int n) => n.toString().padLeft(2, '0');
const _days = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
const _months = ['Jan.', 'Fév.', 'Mars', 'Avr.', 'Mai', 'Juin', 'Juil.', 'Août', 'Sep.', 'Oct.', 'Nov.', 'Déc.'];

/// "Ven. 27 Nov." (device timezone), as in the Stitch cards.
String formatEventDate(DateTime utc, {bool withTime = false}) {
  final d = utc.toLocal();
  final s = '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  return withTime ? '$s • ${_two(d.hour)}:${_two(d.minute)}' : s;
}

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

/// Seats bar from the Stitch cards: "32 / 40 places réservées" + "8 places libres".
class CapacityBar extends StatelessWidget {
  const CapacityBar(this.event, {super.key});
  final Event event;
  @override
  Widget build(BuildContext context) {
    final r = event.fillRatio;
    if (r == null) return const SizedBox.shrink();
    final taken = event.capacity! - event.availableSeats!;
    final full = event.availableSeats == 0;
    final color = full ? _orange : (r > 0.85 ? _orange : _navy);
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('$taken / ${event.capacity} places réservées',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Text(full ? 'Complet' : '${event.availableSeats} places libres',
            style: TextStyle(
                color: full ? _orange : Colors.green.shade700,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
            value: r, minHeight: 6, color: color, backgroundColor: const Color(0xFFDCE9FF)),
      ),
    ]);
  }
}

Widget _poster(Event e, {double? size}) => photo(
    url: e.posterUrl,
    asset: eventPosterAsset(e.id, e.category, clubName: e.clubName),
    width: size,
    height: size);

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.bg, required this.fg, this.icon});
  final String text;
  final Color bg, fg;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 5)],
          Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );
}

/// Compact list card (Stitch "Cette semaine à l'EST"): thumbnail, club, title,
/// status, date/place, seats bar and action pill. It only DISPLAYS backend state.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.onTap});
  final Event event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final full = event.registrationState == RegistrationState.full;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(width: 64, height: 64, child: _poster(event, size: 64))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (event.clubName != null)
                    Text(event.clubName!,
                        style: const TextStyle(
                            color: AppColors.secondary, fontWeight: FontWeight.w700, fontSize: 12)),
                  Text(event.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800, height: 1.15)),
                ]),
              ),
              const SizedBox(width: 8),
              StatusChip(event.registrationState),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.schedule, size: 16, color: _navy),
              const SizedBox(width: 6),
              Text(formatEventDate(event.startAt, withTime: true),
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              if (event.location != null) ...[
                const Spacer(),
                const Icon(Icons.place_outlined, size: 16, color: _navy),
                const SizedBox(width: 4),
                Flexible(
                    child: Text(event.location!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500))),
              ],
            ]),
            if (event.fillRatio != null) ...[
              const SizedBox(height: 12),
              CapacityBar(event),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _Pill(
                  full
                      ? 'Voir les détails'
                      : (event.registrationState == RegistrationState.registered
                          ? 'Voir mon inscription'
                          : 'Détails & Inscription'),
                  bg: full ? const Color(0xFFFFDBCA) : const Color(0xFFE5EEFF),
                  fg: full ? AppColors.secondary : AppColors.primary),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Featured event (Stitch hero): full-bleed poster with dark gradient, orange
/// countdown, title, seats box and the big orange CTA.
class HeroEventCard extends ConsumerWidget {
  const HeroEventCard({super.key, required this.event, this.onTap});
  final Event event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(tickerProvider).value ?? DateTime.now().toUtc();
    final open = event.canRegister;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 210,
            child: Stack(fit: StackFit.expand, children: [
              _poster(event),
              const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x66000000), Color(0xE6001540)]))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _Pill(formatCountdown(event.startAt, now, serverOffset: event.serverOffset),
                        bg: _orange, fg: Colors.white, icon: Icons.timer_outlined),
                  ]),
                  const Spacer(),
                  Row(children: [
                    const _Pill('OFFICIEL UIZ', bg: Color(0xFF1E3A8A), fg: Colors.white),
                    const SizedBox(width: 8),
                    if (event.clubName != null)
                      Flexible(
                          child: Text('Organisé par ${event.clubName}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12))),
                  ]),
                  const SizedBox(height: 4),
                  Text(event.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.1)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.calendar_month_outlined, color: _navy),
                const SizedBox(width: 8),
                Text(formatEventDate(event.startAt),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                if (event.location != null) ...[
                  const Spacer(),
                  const Icon(Icons.place_outlined, size: 18, color: _navy),
                  const SizedBox(width: 4),
                  Flexible(
                      child: Text(event.location!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                ],
              ]),
              if (event.fillRatio != null) ...[
                const SizedBox(height: 12),
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEFF4FF),
                        borderRadius: BorderRadius.circular(12)),
                    child: CapacityBar(event)),
              ],
              const SizedBox(height: 12),
              Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: open ? _orange : const Color(0xFFE5EEFF),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(open ? Icons.bolt : Icons.info_outline,
                      color: open ? Colors.white : AppColors.primary),
                  const SizedBox(width: 6),
                  Text(open ? 'Réserver ma place en 1 clic' : event.registrationState.label,
                      style: TextStyle(
                          color: open ? Colors.white : AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 17)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Public poster (placeholder gradient when there is no image).
Widget eventPoster(Event e) => _poster(e);

/// Icon + text row used on the event detail page.
class InfoRow extends StatelessWidget {
  const InfoRow(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 20, color: _navy),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}
