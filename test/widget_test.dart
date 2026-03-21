import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bantunow/main.dart';

void main() {
  testWidgets('BantuNow app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BantuNowApp());
  });
}