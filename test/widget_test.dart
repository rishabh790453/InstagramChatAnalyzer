import 'package:flutter_test/flutter_test.dart';
import 'package:instajsonfiles/main.dart';

void main() {
  testWidgets('renders analyzer dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Instagram Chat Analyzer'), findsOneWidget);
    expect(find.text('Upload JSON'), findsOneWidget);
    expect(find.text('Saved Analyses'), findsOneWidget);
  });
}
