import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../profile/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../clubs/data/clubs_repository.dart';
import '../../events/domain/event.dart';
import '../data/club_admin_repository.dart';



String statusLabel(String? s) => switch (s) {
      'PENDING_APPROVAL' => 'En attente',
      'PUBLISHED' => 'Publié',
      'REJECTED' => 'Refusé',
      _ => s ?? '',
    };

/// Clubs the signed-in club admin administers (see ClubAdminRepository.myAdminClubs).
final adminClubsProvider = FutureProvider.autoDispose<List<Club>>((ref) {
  final user = ref.watch(authStateProvider).user;
  if (user == null) return const <Club>[];
  return ref.watch(clubAdminRepositoryProvider).myAdminClubs(user.id);
});

final _firstPageProvider = FutureProvider.autoDispose.family<List<Event>, String>(
    (ref, clubId) async =>
        (await ref.watch(clubAdminRepositoryProvider).myClubEvents(clubId, 1)).items);

/// Top of the Stitch club dashboard: "Espace bureau" card, live ticketing alert
/// for the busiest event, and the big "create event" button.
class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader({required this.clubId, required this.onCreate});
  final String clubId;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(clubDetailProvider(clubId)).value;
    final events = ref.watch(_firstPageProvider(clubId)).value ?? const <Event>[];
    final withSeats = events.where((e) => e.fillRatio != null).toList()
      ..sort((a, b) => b.fillRatio!.compareTo(a.fillRatio!));
    final hot = withSeats.isEmpty ? null : withSeats.first;
    const navy = Color(0xFF1E3A8A);
    const orange = Color(0xFFF97316);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFDCE9FF), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.shield_outlined, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ESPACE BUREAU',
                    style: TextStyle(
                        color: Color(0xFF9D4300), fontWeight: FontWeight.w800, fontSize: 12)),
                Text(club?.name ?? '…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ]),
            ),
          ]),
        ),
        if (hot != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFFFDBCA), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.local_fire_department, color: Color(0xFF9D4300)),
                const SizedBox(width: 6),
                const Expanded(
                    child: Text('ALERTE BILLETTERIE EN DIRECT',
                        style: TextStyle(
                            color: Color(0xFF9D4300), fontWeight: FontWeight.w800, fontSize: 12))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration:
                      BoxDecoration(color: orange, borderRadius: BorderRadius.circular(20)),
                  child: Text('${(hot.fillRatio! * 100).round()}% RÉSERVÉ',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: Text(hot.title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20))),
                Text('${hot.availableSeats} places restantes !',
                    style: const TextStyle(
                        color: Color(0xFF9D4300), fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: hot.fillRatio,
                    minHeight: 7,
                    color: orange,
                    backgroundColor: Colors.white54),
              ),
              const SizedBox(height: 6),
              Text('${hot.capacity! - hot.availableSeats!} / ${hot.capacity} inscrits confirmés',
                  style: const TextStyle(
                      color: Color(0xFF9D4300), fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: navy, minimumSize: const Size.fromHeight(52)),
          onPressed: onCreate,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Créer un nouvel événement de club',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('Mes événements',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20))),
        ),
      ]),
    );
  }
}

/// Club admin home: list of the club's events with approval status.
class ClubAdminHome extends ConsumerStatefulWidget {
  const ClubAdminHome({super.key});
  @override
  ConsumerState<ClubAdminHome> createState() => _ClubAdminHomeState();
}

class _ClubAdminHomeState extends ConsumerState<ClubAdminHome> {
  int _reload = 0; // change => PagedListView reloads
  String? _clubId; // chosen club when the admin manages several
  String? _activeClubId;

  Future<void> _delete(Event e) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text("Supprimer l'événement"),
              content: Text('Supprimer "${e.title}" ?'),
              actions: [
                TextButton(onPressed: () => c.pop(false), child: const Text('Non')),
                FilledButton(onPressed: () => c.pop(true), child: const Text('Oui')),
              ],
            ));
    if (ok != true) return;
    try {
      await ref.read(clubAdminRepositoryProvider).delete(e.id);
      if (mounted) setState(() => _reload++);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err')));
      }
    }
  }

  Future<void> _openForm([Event? e]) async {
    final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
            builder: (_) => EventFormScreen(event: e, clubId: _activeClubId!)));
    if (saved == true && mounted) {
      ref.invalidate(_firstPageProvider);
      setState(() => _reload++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(adminClubsProvider);
    final clubs = clubsAsync.value ?? const <Club>[];
    final clubId = _clubId ?? (clubs.isEmpty ? null : clubs.first.id);
    _activeClubId = clubId;
    return Scaffold(
      appBar: AppBar(title: const Text('Espace club'), actions: [
        if (clubs.length > 1)
          PopupMenuButton<String>(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Changer de club',
              onSelected: (v) => setState(() {
                    _clubId = v;
                    _reload++;
                  }),
              itemBuilder: (_) => [
                    for (final c in clubs) PopupMenuItem(value: c.id, child: Text(c.name))
                  ]),
        if (clubId != null)
          IconButton(
              tooltip: 'Mon club',
              icon: const Icon(Icons.edit_note),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ClubEditScreen(clubId: clubId)))),
        IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authStateProvider.notifier).logout()),
      ]),
      body: clubsAsync.isLoading
          ? const LoadingView()
          : clubId == null
          ? const EmptyState(message: "Aucun club administré par ce compte.")
          : Column(children: [
              _DashboardHeader(clubId: clubId, onCreate: _openForm),
              Expanded(child: PagedListView<Event>(
              key: ValueKey(_reload),
              fetch: (p) => ref.read(clubAdminRepositoryProvider).myClubEvents(clubId, p),
              emptyMessage: "Aucun événement. Créez le premier !",
              itemBuilder: (c, e) => Card(
                child: ListTile(
                  title: Text(e.title),
                  subtitle: Text([
                    statusLabel(e.status),
                    if (e.status == 'REJECTED' && e.rejectionReason != null)
                      'Motif : ${e.rejectionReason}',
                  ].join('\n')),
                  isThreeLine: e.rejectionReason != null,
                  onTap: () => c.push('/events/${e.id}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => switch (v) {
                      'edit' => _openForm(e),
                      'regs' => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => RegistrantsScreen(event: e))),
                      _ => _delete(e),
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'regs', child: Text('Inscrits')),
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
                  ),
                ),
              ),
            )),
            ]),
    );
  }
}

/// Edit the club description and logo.
class ClubEditScreen extends ConsumerStatefulWidget {
  const ClubEditScreen({super.key, required this.clubId});
  final String clubId;
  @override
  ConsumerState<ClubEditScreen> createState() => _ClubEditState();
}

class _ClubEditState extends ConsumerState<ClubEditScreen> {
  final _desc = TextEditingController();
  double? _progress;
  String? _msg;
  bool _busy = false;
  String? _logoUrl;

  Future<void> _pickLogo() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f == null) return;
    final err = validateImage(f.path, await File(f.path).length());
    if (err != null) return setState(() => _msg = err);
    setState(() {
      _progress = 0;
      _msg = null;
    });
    try {
      final url = await ref.read(profileRepositoryProvider).uploadImage('logo', f.path, clubId: widget.clubId,
          onProgress: (p) => mounted ? setState(() => _progress = p) : null);
      if (mounted) setState(() => _logoUrl = url);
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(clubAdminRepositoryProvider).updateClub(widget.clubId,
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          logoUrl: _logoUrl);
      if (mounted) setState(() => _msg = 'Club enregistré');
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mon club')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          OutlinedButton.icon(
              onPressed: _progress == null ? _pickLogo : null,
              icon: const Icon(Icons.image_outlined),
              label: Text(_logoUrl == null ? 'Changer le logo' : 'Logo ajouté ✓')),
          if (_progress != null) LinearProgressIndicator(value: _progress),
          const SizedBox(height: 12),
          TextField(
              controller: _desc,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Description')),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_msg!)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Enregistrer')),
        ]),
      );
}

/// Students registered to an event: mark ATTENDED or cancel.
class RegistrantsScreen extends ConsumerStatefulWidget {
  const RegistrantsScreen({super.key, required this.event});
  final Event event;
  @override
  ConsumerState<RegistrantsScreen> createState() => _RegistrantsState();
}

class _RegistrantsState extends ConsumerState<RegistrantsScreen> {
  int _reload = 0;

  Future<void> _act(Future<void> Function() f) async {
    try {
      await f();
      if (mounted) setState(() => _reload++);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(clubAdminRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Inscrits · ${widget.event.title}')),
      body: PagedListView<Registrant>(
        key: ValueKey(_reload),
        fetch: (p) => repo.registrants(widget.event.id, p),
        emptyMessage: 'Aucun inscrit',
        itemBuilder: (c, r) => Card(
          child: ListTile(
            title: Text(r.name.isEmpty ? r.email : r.name),
            subtitle: Text('${r.email} · ${r.status}'),
            trailing: r.status == 'CONFIRMED'
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        tooltip: 'Présent',
                        icon: const Icon(Icons.check_circle_outline),
                        onPressed: () => _act(() => repo.markAttended(r.id))),
                    IconButton(
                        tooltip: 'Annuler',
                        icon: const Icon(Icons.cancel_outlined),
                        onPressed: () => _act(() => repo.cancelRegistration(r.id))),
                  ])
                : null,
          ),
        ),
      ),
    );
  }
}

/// Create (event == null) or edit an event.
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.event, required this.clubId});
  final Event? event;
  final String clubId;
  @override
  ConsumerState<EventFormScreen> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<EventFormScreen> {
  late final _title = TextEditingController(text: widget.event?.title);
  late final _desc = TextEditingController(text: widget.event?.description);
  late final _loc = TextEditingController(text: widget.event?.location);
  late final _cap = TextEditingController(text: '${widget.event?.capacity ?? ''}');
  late DateTime? _start = widget.event?.startAt.toLocal();
  late DateTime? _end = widget.event?.endAt?.toLocal();
  late DateTime? _deadline = widget.event?.registrationDeadline?.toLocal();
  late String? _category = widget.event?.category;
  bool _busy = false;
  String? _error;
  late String? _posterUrl = widget.event?.posterUrl;
  double? _uploadProgress;

  Future<void> _pickPoster() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f == null) return;
    final err = validateImage(f.path, await File(f.path).length());
    if (err != null) return setState(() => _error = err);
    setState(() {
      _uploadProgress = 0;
      _error = null;
    });
    try {
      final url = await ref.read(profileRepositoryProvider).uploadImage(
          'poster', f.path, clubId: widget.clubId,
          onProgress: (p) => mounted ? setState(() => _uploadProgress = p) : null);
      if (mounted) setState(() => _posterUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
    }
  }

  Future<DateTime?> _pick(DateTime? initial) async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context,
        initialDate: initial ?? now,
        firstDate: now.subtract(const Duration(days: 365)),
        lastDate: now.add(const Duration(days: 365 * 3)));
    if (d == null || !mounted) return null;
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial ?? now));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _save() async {
    if (_busy) return;
    final err = validateEventInput(
        title: _title.text,
        capacity: int.tryParse(_cap.text),
        startAt: _start,
        endAt: _end,
        deadline: _deadline,
        category: _category);
    if (err != null) return setState(() => _error = err);
    setState(() {
      _busy = true;
      _error = null;
    });
    final input = EventInput(
      title: _title.text.trim(),
      description: _desc.text.trim(),
      location: _loc.text.trim(),
      startAt: _start!,
      endAt: _end!,
      capacity: int.parse(_cap.text),
      registrationDeadline: _deadline!,
      category: _category!,
      posterUrl: _posterUrl,
    );
    final repo = ref.read(clubAdminRepositoryProvider);
    try {
      final e = widget.event;
      if (e == null) {
        await repo.create(widget.clubId, input);
      } else {
        await repo.update(e.id, input);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _dateTile(String label, DateTime? v, void Function(DateTime) set) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(v == null ? 'Choisir…' : v.toString().substring(0, 16)),
        trailing: const Icon(Icons.calendar_month),
        onTap: () async {
          final d = await _pick(v);
          if (d != null) setState(() => set(d));
        },
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.event == null ? 'Nouvel événement' : "Modifier l'événement")),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          OutlinedButton.icon(
              onPressed: _uploadProgress == null ? _pickPoster : null,
              icon: const Icon(Icons.image_outlined),
              label: Text(_posterUrl == null ? 'Ajouter une affiche' : 'Affiche ajoutée ✓ (changer)')),
          if (_uploadProgress != null) LinearProgressIndicator(value: _uploadProgress),
          const SizedBox(height: 12),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Titre')),
          const SizedBox(height: 12),
          TextField(
              controller: _desc,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 12),
          TextField(controller: _loc, decoration: const InputDecoration(labelText: 'Lieu')),
          const SizedBox(height: 12),
          TextField(
              controller: _cap,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacité')),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Catégorie'),
            items: [
              for (final c in eventCategories.entries)
                DropdownMenuItem(value: c.value, child: Text(c.key)),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
          _dateTile('Début', _start, (d) => _start = d),
          _dateTile('Fin', _end, (d) => _end = d),
          _dateTile("Date limite d'inscription", _deadline, (d) => _deadline = d),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enregistrer')),
        ]),
      );
}
