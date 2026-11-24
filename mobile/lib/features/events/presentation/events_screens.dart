import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/paged.dart';
import '../../../core/widgets/event_widgets.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';
import '../domain/registration_state.dart';

class EventsTab extends ConsumerStatefulWidget {
  const EventsTab({super.key});
  @override
  ConsumerState<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends ConsumerState<EventsTab> {
  String _q = '';
  String? _cat;
  static const _categories = ['Tech & IA', 'Ateliers', 'Compétitions'];
  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Rechercher un événement'),
            onSubmitted: (v) => setState(() => _q = v.trim()),
          ),
        ),
        const SizedBox(height: 8),
        FilterChipsRow(
            options: _categories,
            selected: _cat,
            onChanged: (v) => setState(() => _cat = v)),
        Expanded(
          child: PagedListView<Event>(
            key: ValueKey('$_q|$_cat'),
            fetch: (p) =>
                ref.read(eventsRepositoryProvider).list(p, search: _q, category: _cat),
            emptyMessage: 'Aucun événement trouvé',
            itemBuilder: (c, e) =>
                EventCard(event: e, onTap: () => c.push('/events/${e.id}')),
          ),
        ),
      ]);
}

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen(this.id, {super.key});
  final String id;
  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailState();
}

class _EventDetailState extends ConsumerState<EventDetailScreen> {
  bool _busy = false;

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(title: Text(title), content: Text(body), actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Oui')),
        ]),
      ) ??
      false;

  /// Runs register/cancel once (no double taps), then reloads the event so
  /// seats and registration state come from the backend again.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(eventDetailProvider(widget.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _action(Event e) {
    final repo = ref.read(eventsRepositoryProvider);
    final s = e.registrationState;
    if (s.canRegister) {
      return FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF97316), minimumSize: const Size.fromHeight(54)),
        onPressed: _busy
            ? null
            : () async {
                if (await _confirm("Confirmer l'inscription", 'Vous inscrire à "${e.title}" ?')) {
                  await _run(() => repo.register(e.id));
                }
              },
        child: Text(s.label),
      );
    }
    if (s == RegistrationState.registered &&
        e.canCancel &&
        e.myRegistrationId != null) {
      return OutlinedButton(
        onPressed: _busy
            ? null
            : () async {
                if (await _confirm("Annuler l'inscription", 'Annuler votre inscription ?')) {
                  await _run(() => repo.cancel(e.myRegistrationId!));
                }
              },
        child: const Text("Annuler mon inscription"),
      );
    }
    return StatusChip(s); // FULL, ENDED, ... : display only
  }

  /// Adds the event to the device calendar (add_2_calendar).
  /// Falls back to the backend .ics file when the device calendar fails.
  Future<void> _addToCalendar(Event e) async {
    final ok = await cal.Add2Calendar.addEvent2Cal(cal.Event(
      title: e.title,
      description: e.description ?? '',
      location: e.location ?? '',
      startDate: e.startAt.toLocal(),
      endDate: (e.endAt ?? e.startAt.add(const Duration(hours: 1))).toLocal(),
    ));
    if (ok || !mounted) return;
    try {
      final dir = (await getTemporaryDirectory()).path;
      final path = await ref.read(eventsRepositoryProvider).downloadIcs(e.id, dir);
      await OpenFilex.open(path);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(eventDetailProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Événement')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (err, _) => ErrorView(
            message: '$err',
            onRetry: () => ref.invalidate(eventDetailProvider(widget.id))),
        data: (e) => ListView(padding: const EdgeInsets.all(16), children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(aspectRatio: 16 / 9, child: eventPoster(e))),
          const SizedBox(height: 16),
          if (e.clubName != null)
            Text(e.clubName!,
                style: const TextStyle(
                    color: Color(0xFF9D4300), fontWeight: FontWeight.w800, fontSize: 13)),
          Text(e.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (e.registrationState == RegistrationState.open ||
              e.registrationState == RegistrationState.registered)
            Align(
                alignment: AlignmentDirectional.centerStart,
                child: CountdownChip(target: e.startAt, serverOffset: e.serverOffset)),
          const SizedBox(height: 8),
          InfoRow(Icons.calendar_month_outlined, formatEventDate(e.startAt, withTime: true)),
          if (e.location != null) InfoRow(Icons.place_outlined, e.location!),
          if (e.registrationDeadline != null)
            InfoRow(Icons.hourglass_bottom,
                "Inscriptions jusqu'au ${formatEventDate(e.registrationDeadline!, withTime: true)}"),
          if (e.fillRatio != null) ...[
            const SizedBox(height: 12),
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(12)),
                child: CapacityBar(e)),
          ],
          if ((e.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('À propos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(e.description!),
          ],
          const SizedBox(height: 24),
          _action(e),
          if (e.registrationState == RegistrationState.registered)
            TextButton.icon(
                onPressed: () => _addToCalendar(e),
                icon: const Icon(Icons.event_available),
                label: const Text('Ajouter au calendrier')),
        ]),
      ),
    );
  }
}

/// "Mes inscriptions": Upcoming / Completed / Cancelled (display filter on status).
class MyRegistrationsTab extends ConsumerWidget {
  const MyRegistrationsTab({super.key});

  static const _tabs = {
    'À venir': 'CONFIRMED',
    'Terminées': 'ATTENDED',
    'Annulées': 'CANCELLED',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
        length: _tabs.length,
        child: Column(children: [
          TabBar(tabs: [for (final t in _tabs.keys) Tab(text: t)]),
          Expanded(
            child: TabBarView(children: [
              for (final status in _tabs.values)
                PagedListView<Registration>(
                  fetch: (p) async {
                    final page = await ref.read(eventsRepositoryProvider).myRegistrations(p);
                    return Paged(page.items.where((r) => r.status == status).toList(),
                        page.page, page.totalPages);
                  },
                  emptyMessage: 'Aucune inscription',
                  itemBuilder: (c, r) => EventCard(
                      event: r.event, onTap: () => c.push('/events/${r.event.id}')),
                ),
            ]),
          ),
        ]),
      );
}
