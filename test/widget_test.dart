import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emotion_companion/widgets/app_splash.dart';

void main() {
  testWidgets('AppSplash 启动页正常渲染标题', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppSplash(
          appInit: Future<void>.value(),
          onFinished: () {},
          isDarkMode: false,
        ),
      ),
    );

    expect(find.text('抱抱情绪云'), findsOneWidget);
    expect(find.text('用温暖抱抱你的每一种情绪'), findsOneWidget);

    // 冲掉启动装饰的延时定时器，避免测试收尾时报残留 Timer
    await tester.pump(const Duration(seconds: 2));
  });
}
