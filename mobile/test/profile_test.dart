import 'package:flutter_test/flutter_test.dart';
import 'package:est_clubs_events/features/profile/profile.dart';

void main() {
  test('accepts jpg/png/webp under 5 MB, any case', () {
    expect(validateImage('/a/b.JPG', 1000), isNull);
    expect(validateImage('c.png', maxImageBytes), isNull);
    expect(validateImage('d.webp', 1), isNull);
  });
  test('rejects other formats and big files', () {
    expect(validateImage('x.gif', 10), isNotNull);
    expect(validateImage('x.pdf', 10), isNotNull);
    expect(validateImage('x.jpg', maxImageBytes + 1), isNotNull);
  });
}
