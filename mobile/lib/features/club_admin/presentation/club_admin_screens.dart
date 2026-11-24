import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../profile/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/event_widgets.dart';
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

/// First page of attendees of one event (for "Derniers inscrits").
final _registrantsProvider = FutureProvider.autoDispose.family<List<Registrant>, String>(
    (ref, eventId) async =>
        (await ref.watch(clubAdminRepositoryProvider).registrants(eventId, 1)).items);

const _navy = Color(0xFF1E3A8A);
const _orange = Color(0xFFF97316);

/// Tiny line chart with a soft fill and an orange end dot (Stitch sparkline).
class _Sparkline extends CustomPainter {
  _Sparkline(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    Offset pt(int i) => Offset(
        size.width * i / (values.length - 1),
        size.height - 6 - (size.height - 12) * (values[i] - minV) / range);
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final a = pt(i - 1), b = pt(i);
      final mid = (a.dx + b.dx) / 2;
      line.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x331E3A8A), Color(0x001E3A8A)])
              .createShader(Offset.zero & size));
    canvas.drawPath(
        line,
        Paint()
          ..color = _navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(pt(values.length - 1), 4, Paint()..color = _orange);
  }

  @override
  bool shouldRepaint(_Sparkline old) => old.values != values;
}

/// Top of the Stitch club dashboard: office card with Bureau/Étudiant switch,
/// live ticketing alert, registrations chart, stat tiles, create button and
/// latest registrants.
class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader({required this.clubId, required this.onCreate});
  final String clubId;
  final VoidCallback onCreate;

  static String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
  }

  Widget _card({required Widget child, Color? color}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color ?? Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2))]),
        child: child,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(clubDetailProvider(clubId)).value;
    final approved = club == null || club.status == 'APPROVED';
    final events = ref.watch(_firstPageProvider(clubId)).value ?? const <Event>[];
    final now = DateTime.now().toUtc();
    final published = events.where((e) => e.status == 'PUBLISHED').toList();
    final upcoming = published.where((e) => e.startAt.isAfter(now)).toList();

    // Fullest upcoming event with seats = "alerte billetterie".
    final withSeats = upcoming.where((e) => e.fillRatio != null).toList()
      ..sort((a, b) => b.fillRatio!.compareTo(a.fillRatio!));
    final hot = withSeats.isEmpty ? null : withSeats.first;

    // Registrations over time: cumulative total per event, oldest to newest.
    final byDate = events.where((e) => e.registeredCount != null).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    var running = 0.0;
    final series = [for (final e in byDate) running += e.registeredCount!];
    final total = series.isEmpty ? 0 : series.last.round();
    double? trend;
    if (series.length >= 4) {
      final mid = series[series.length ~/ 2 - 1];
      if (mid > 0) trend = (series.last - mid) / mid * 100;
    }
    final ratios = published.map((e) => e.fillRatio).whereType<double>().toList();
    final avgFill = ratios.isEmpty ? null : ratios.reduce((a, b) => a + b) / ratios.length;

    final focus = hot ?? (upcoming.isEmpty ? null : upcoming.first);
    final regs = focus == null ? null : ref.watch(_registrantsProvider(focus.id));

    String? closing(Event e) {
      final d = e.registrationDeadline;
      if (d == null) return null;
      final left = d.difference(now.add(e.serverOffset));
      if (left.isNegative) return null;
      return left.inHours < 72
          ? 'Clôture dans ${left.inHours < 1 ? 1 : left.inHours}h'
          : 'Clôture dans ${left.inDays}j';
    }

    Widget seg(String text, bool on, VoidCallback? tap) => Expanded(
          child: GestureDetector(
            onTap: tap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: on ? _navy : Colors.transparent,
                  borderRadius: BorderRadius.circular(20)),
              alignment: Alignment.center,
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : const Color(0xFF444651))),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(children: [
        // Office card + Bureau / Étudiant switch
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFDCE9FF), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.shield_outlined, color: Colors.white)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: const [
                  Text('ESPACE BUREAU ',
                      style: TextStyle(
                          color: Color(0xFF9D4300), fontWeight: FontWeight.w800, fontSize: 11)),
                  Icon(Icons.circle, size: 7, color: _orange),
                ]),
                Text(club?.name ?? '…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
            ),
            Container(
              width: 138,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                seg('Bureau', true, null),
                seg('Étudiant', false, () => context.go('/student')),
              ]),
            ),
          ]),
        ),
        if (hot != null) ...[
          const SizedBox(height: 12),
          _card(
            color: const Color(0xFFFFDBCA),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.local_fire_department, color: Color(0xFF9D4300), size: 20),
                const SizedBox(width: 6),
                const Expanded(
                    child: Text('ALERTE BILLETTERIE EN DIRECT',
                        style: TextStyle(
                            color: Color(0xFF9D4300), fontWeight: FontWeight.w800, fontSize: 12))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(20)),
                  child: Text('${(hot.fillRatio! * 100).round()}% RÉSERVÉ',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                    child: Text(hot.title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19))),
                Text('${hot.availableSeats} places restantes !',
                    style: const TextStyle(
                        color: Color(0xFF9D4300), fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: hot.fillRatio,
                    minHeight: 7,
                    color: _orange,
                    backgroundColor: Colors.white54),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Text('${hot.capacity! - hot.availableSeats!} / ${hot.capacity} inscrits confirmés',
                      style: const TextStyle(
                          color: Color(0xFF9D4300), fontWeight: FontWeight.w600, fontSize: 12)),
                ),
                if (closing(hot) != null) ...[
                  const Icon(Icons.circle, size: 7, color: _orange),
                  const SizedBox(width: 4),
                  Text(closing(hot)!,
                      style: const TextStyle(
                          color: Color(0xFF9D4300), fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ]),
            ]),
          ),
        ],
        // TOTAL INSCRIPTIONS + sparkline
        const SizedBox(height: 12),
        _card(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TOTAL INSCRIPTIONS',
                    style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF444651))),
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$total',
                      style: const TextStyle(
                          fontSize: 36, fontWeight: FontWeight.w800, color: Color(0xFF0B1C30))),
                  const SizedBox(width: 8),
                  if (trend != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: const Color(0xFFDCE9FF), borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(trend >= 0 ? Icons.trending_up : Icons.trending_down,
                            size: 14, color: _navy),
                        const SizedBox(width: 3),
                        Text('${trend >= 0 ? '+' : ''}${trend.round()}%',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: _navy)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 4),
                Text('Sur ${byDate.length} événement${byDate.length > 1 ? 's' : ''} du club',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF444651))),
              ]),
            ),
            SizedBox(
              width: 120,
              height: 60,
              child: CustomPaint(painter: _Sparkline(series)),
            ),
          ]),
        ),
        // Two stat tiles
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: _card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('ÉVÉNEMENTS',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF444651))),
                  Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: const Color(0xFFDCE9FF), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.event_available, size: 18, color: _navy)),
                ]),
                const SizedBox(height: 8),
                Text('${upcoming.length}',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                const Text('En cours de diffusion',
                    style: TextStyle(fontSize: 12, color: Color(0xFF444651))),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('REMPLISSAGE',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF444651))),
                  Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFFDBCA), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.pie_chart_outline, size: 18, color: Color(0xFF9D4300))),
                ]),
                const SizedBox(height: 8),
                Text(avgFill == null ? '—' : '${(avgFill * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                const Text('Moyenne des événements',
                    style: TextStyle(fontSize: 12, color: Color(0xFF444651))),
              ]),
            ),
          ),
        ])),
        if (!approved) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFFFDBCA), borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.hourglass_top, color: Color(0xFF9D4300)),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      "Ce club est en attente de validation : la création d'événements sera possible après approbation.")),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: _navy, minimumSize: const Size.fromHeight(52)),
          onPressed: approved ? onCreate : null,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Créer un nouvel événement de club',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        // Derniers inscrits
        if (focus != null) ...[
          const SizedBox(height: 22),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Derniers inscrits',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                Text(focus.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF444651))),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFFDCE9FF), borderRadius: BorderRadius.circular(14)),
              child: Text('${focus.registeredCount ?? 0} Validés',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _navy)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFDCE9FF),
                    side: BorderSide.none,
                    foregroundColor: _navy,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RegistrantsScreen(event: focus))),
                icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                label: const Text('Présences',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    foregroundColor: const Color(0xFF0B1C30),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  final rows = regs?.value ?? const <Registrant>[];
                  final csv = StringBuffer('Nom,Email,Statut\n');
                  for (final r in rows) {
                    csv.writeln('"${r.name}",${r.email},${r.status}');
                  }
                  await Clipboard.setData(ClipboardData(text: csv.toString()));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Liste CSV copiée dans le presse-papiers')));
                  }
                },
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export CSV',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (regs != null)
            regs.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('$e'),
              data: (rows) => Column(children: [
                for (final r in rows.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _card(
                      child: Row(children: [
                        CircleAvatar(
                            radius: 22,
                            backgroundColor: r.status == 'CONFIRMED'
                                ? const Color(0xFFDCE1FF)
                                : const Color(0xFFFFDBCA),
                            child: Text(_initials(r.name.isEmpty ? r.email : r.name),
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: r.status == 'CONFIRMED'
                                        ? const Color(0xFF00236F)
                                        : const Color(0xFF9D4300)))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.name.isEmpty ? r.email : r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(r.studentId == null ? r.email : '#${r.studentId}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF444651))),
                          ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: r.status == 'CANCELLED'
                                  ? const Color(0xFFFFDAD6)
                                  : (r.status == 'CONFIRMED'
                                      ? const Color(0xFFDCE9FF)
                                      : const Color(0xFFD7F5E3)),
                              borderRadius: BorderRadius.circular(16)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                                r.status == 'CANCELLED'
                                    ? Icons.cancel_outlined
                                    : Icons.check_circle_outline,
                                size: 14,
                                color: r.status == 'CANCELLED' ? const Color(0xFFBA1A1A) : _navy),
                            const SizedBox(width: 4),
                            Text(
                                r.status == 'CANCELLED'
                                    ? 'Annulé'
                                    : (r.status == 'ATTENDED' ? 'Présent' : 'Validé'),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: r.status == 'CANCELLED'
                                        ? const Color(0xFFBA1A1A)
                                        : _navy)),
                          ]),
                        ),
                        if (r.status == 'CONFIRMED')
                          IconButton(
                              tooltip: 'Marquer présent',
                              icon: const Icon(Icons.task_alt, color: Color(0xFF444651)),
                              onPressed: () async {
                                await ref.read(clubAdminRepositoryProvider).markAttended(r.id);
                                ref.invalidate(_registrantsProvider(focus.id));
                              }),
                      ]),
                    ),
                  ),
              ]),
            ),
        ],
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
                  leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(width: 56, height: 56, child: eventPoster(e))),
                  title: Text(e.title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text([
                    statusLabel(e.status) +
                        (e.capacity == null
                            ? ''
                            : ' · ${e.registeredCount ?? 0}/${e.capacity} inscrits'),
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
