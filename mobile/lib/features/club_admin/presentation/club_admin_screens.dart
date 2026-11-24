import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../profile/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../events/domain/event.dart';
import '../data/club_admin_repository.dart';

String statusLabel(String? s) => switch (s) {
      'PENDING_APPROVAL' => 'En attente',
      'PUBLISHED' => 'Publié',
      'REJECTED' => 'Refusé',
      _ => s ?? '',
    };

/// Club admin home: list of the club's events with approval status.
class ClubAdminHome extends ConsumerStatefulWidget {
  const ClubAdminHome({super.key});
  @override
  ConsumerState<ClubAdminHome> createState() => _ClubAdminHomeState();
}

class _ClubAdminHomeState extends ConsumerState<ClubAdminHome> {
  int _reload = 0; // change => PagedListView reloads

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
        MaterialPageRoute(builder: (_) => EventFormScreen(event: e)));
    if (saved == true && mounted) setState(() => _reload++);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    final clubId = user?.clubId;
    return Scaffold(
      appBar: AppBar(title: const Text('Espace club'), actions: [
        IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authStateProvider.notifier).logout()),
      ]),
      floatingActionButton: clubId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Événement')),
      body: clubId == null
          ? const EmptyState(message: "Aucun club associé à ce compte.")
          : PagedListView<Event>(
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
                    onSelected: (v) => v == 'edit' ? _openForm(e) : _delete(e),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// Create (event == null) or edit an event.
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.event});
  final Event? event;
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
          'poster', f.path,
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
        deadline: _deadline);
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
      registrationDeadline: _deadline,
      posterUrl: _posterUrl,
    );
    final repo = ref.read(clubAdminRepositoryProvider);
    try {
      final e = widget.event;
      if (e == null) {
        await repo.create(ref.read(authStateProvider).user!.clubId!, input);
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
          _dateTile('Début', _start, (d) => _start = d),
          _dateTile('Fin', _end, (d) => _end = d),
          _dateTile("Date limite d'inscription (optionnel)", _deadline, (d) => _deadline = d),
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
