import 'package:flutter_test/flutter_test.dart';

import 'package:imperium_sui/main.dart';

void main() {
  testWidgets('startup shell is rendered', (tester) async {
    await tester.pumpWidget(const ImperiumSuiApp());

    expect(find.text('Imperium Sui'), findsOneWidget);
    expect(find.text('Flutter project is ready.'), findsOneWidget);
    expect(find.text('Run the app'), findsOneWidget);
  });
}
