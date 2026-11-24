import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:est_clubs_events/features/notifications/notifications.dart';

void main() {
  test('parses notification read state and event link', () {
    final n = AppNotification.fromJson(
        {'id': 1, 'title': 'T', 'body': 'B', 'isRead': false, 'eventId': 7});
    expect(n.isRead, isFalse);
    expect(n.eventId, '7');
    expect(AppNotification.fromJson({'id': 2, 'readAt': '2030-01-01T00:00:00Z'}).isRead,
        isTrue);
  });

  testWidgets('bell shows unread badge only when count > 0', (t) async {
    Widget app(int n) => ProviderScope(
          overrides: [unreadCountProvider.overrideWith((ref) async => n)],
          child: const MaterialApp(home: Scaffold(body: NotificationBell())),
        );
    await t.pumpWidget(app(3));
    await t.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    await t.pumpWidget(app(0));
    await t.pumpAndSettle();
    expect(find.text('0'), findsNothing);
  });
}
