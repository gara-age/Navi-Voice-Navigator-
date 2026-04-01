import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:voice_navigator/app/app_shell.dart';

void main() {
  testWidgets('Voice Navigator 런처가 렌더링된다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VoiceNavigatorApp()));

    expect(find.text('Voice Navigator'), findsWidgets);
    expect(find.text('연동 모드'), findsOneWidget);
    expect(find.text('데모 모드'), findsOneWidget);
  });
}
