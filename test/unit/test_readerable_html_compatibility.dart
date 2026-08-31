import 'package:html/parser.dart' as html_parser;
import 'package:reader_mode/reader_mode.dart';
import 'package:test/test.dart';

void main() {
  test('ignores paragraphs nested inside list items', () {
    final doc = html_parser.parse(
      '<html><body><ul><li><div><p>${'List content. ' * 50}</p></div></li></ul></body></html>',
    );

    expect(isProbablyReaderable(doc), isFalse);
  });
}
