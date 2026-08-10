import 'package:flutter_test/flutter_test.dart';

import 'package:connectlang_app/main.dart';

void main() {
  testWidgets('App renders the bootstrap placeholder screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ConnectLangApp());

    expect(find.text('ConnectLang'), findsOneWidget);
    expect(find.textContaining('Supabase inicializado'), findsOneWidget);
  });
}
