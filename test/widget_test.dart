import 'package:flutter_test/flutter_test.dart';
import 'package:aerotest/main.dart';

void main() {
  testWidgets('Dashboard ekranı yüklenir', (WidgetTester tester) async {
    await tester.pumpWidget(const AeroTestApp());
    expect(find.text('AeroTest'), findsOneWidget);
  });
}
