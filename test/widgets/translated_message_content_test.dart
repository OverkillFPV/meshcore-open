import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/helpers/link_handler.dart';
import 'package:meshcore_open/utils/platform_info.dart';
import 'package:meshcore_open/widgets/translated_message_content.dart';

Iterable<InlineSpan> _spans(WidgetTester tester) {
  if (PlatformInfo.isDesktop) {
    return tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((w) => w.textSpan!);
  }
  return tester.widgetList<Text>(find.byType(Text)).map((w) => w.textSpan!);
}

List<String> _plainTexts(WidgetTester tester) =>
    _spans(tester).map((s) => s.toPlainText()).toList();

Future<void> _pump(WidgetTester tester, TextScaler scaler) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: scaler),
        child: const Scaffold(
          body: TranslatedMessageContent(
            displayText: 'hello https://example.com',
            originalText: 'bonjour',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpText(WidgetTester tester, String text) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TranslatedMessageContent(
          displayText: text,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('message body follows the system text scale', (tester) async {
    await _pump(tester, TextScaler.noScaling);
    final baseWidth = tester.getSize(find.byType(SelectableText).first).width;

    await _pump(tester, const TextScaler.linear(2));
    final scaledWidth = tester.getSize(find.byType(SelectableText).first).width;
    expect(scaledWidth, greaterThan(baseWidth * 1.8));
  }, skip: !PlatformInfo.isDesktop);

  testWidgets('original and translated text both render', (tester) async {
    await _pump(tester, TextScaler.noScaling);
    expect(_plainTexts(tester), ['bonjour', 'hello https://example.com']);
  });

  testWidgets('leading mention drops the @ and brackets', (tester) async {
    await _pumpText(tester, '@[⚡ - Overkill™️] hello there');
    expect(_plainTexts(tester), ['⚡ - Overkill™️ hello there']);
  });

  testWidgets('inline mentions drop the @ and brackets', (tester) async {
    await _pumpText(tester, 'ping @[Bob] and @[Alice Mary] please');
    expect(_plainTexts(tester), ['ping Bob and Alice Mary please']);
  });

  testWidgets('mentions render in the mention style', (tester) async {
    await _pumpText(tester, 'hi @[Bob]!');
    final context = tester.element(find.byType(Scaffold));
    final primary = Theme.of(context).colorScheme.primary;
    final span = _spans(tester).first as TextSpan;
    final mention = span.children!
        .whereType<TextSpan>()
        .where((s) => s.text == 'Bob')
        .first;
    expect(mention.style?.fontWeight, FontWeight.bold);
    expect(mention.style?.color, primary);
    expect(
      mention.style?.backgroundColor,
      LinkHandler.mentionBackground(context),
      reason: 'mention should have a coloured surround',
    );
  });

  testWidgets('plain text without mentions is untouched', (tester) async {
    await _pumpText(tester, 'no mentions here');
    expect(_plainTexts(tester), ['no mentions here']);
  });
}
