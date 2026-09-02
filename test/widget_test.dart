import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangroveguardapp/views/scanner_page.dart';
import 'package:mangroveguardapp/main.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MangroveGuardApp(showHome: false));

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test(
    'Android uses the platform default camera format to avoid unsupported YUV configs',
    () {
      expect(resolveCameraFormatGroup(isAndroid: true), isNull);
      expect(resolveCameraFormatGroup(isAndroid: false), isNotNull);
      expect(
        resolveCameraFormatGroup(isAndroid: false),
        equals(ImageFormatGroup.bgra8888),
      );
    },
  );
}
