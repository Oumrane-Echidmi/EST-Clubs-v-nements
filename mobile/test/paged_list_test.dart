import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:est_clubs_events/core/errors/app_exception.dart';
import 'package:est_clubs_events/core/network/paged.dart';
import 'package:est_clubs_events/core/widgets/paged_list.dart';

Widget _wrap(Future<Paged<String>> Function(int) f) => MaterialApp(
    home: Scaffold(
        body: PagedListView<String>(
            fetch: f,
            emptyMessage: 'vide',
            itemBuilder: (_, s) => Text(s))));

void main() {
  testWidgets('shows loading, then items', (t) async {
    await t.pumpWidget(_wrap((p) async => Paged(['a', 'b'], 1, 1)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await t.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('shows empty state', (t) async {
    await t.pumpWidget(_wrap((p) async => Paged(<String>[], 1, 1)));
    await t.pumpAndSettle();
    expect(find.text('vide'), findsOneWidget);
  });

  testWidgets('shows error with retry that reloads', (t) async {
    var calls = 0;
    await t.pumpWidget(_wrap((p) async {
      calls++;
      if (calls == 1) throw AppException('X', 'Panne réseau');
      return Paged(['ok'], 1, 1);
    }));
    await t.pumpAndSettle();
    expect(find.text('Panne réseau'), findsOneWidget);
    await t.tap(find.text('Réessayer'));
    await t.pumpAndSettle();
    expect(find.text('ok'), findsOneWidget);
  });
}
