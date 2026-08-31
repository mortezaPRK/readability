import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('reads HTML from URL without blocking', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.write('''
        <html>
          <head><title>Remote article</title></head>
          <body><article><p>${'Remote content. ' * 50}</p></article></body>
        </html>
      ''');
      await request.response.close();
    });

    try {
      final process = await Process.start(
        Platform.resolvedExecutable,
        [
          'run',
          'bin/cli.dart',
          '--json',
          'http://${server.address.host}:${server.port}/article',
        ],
      );
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );

      expect(await stderr, isEmpty);
      expect(exitCode, 0);
      expect(
        jsonDecode(await stdout),
        containsPair('title', 'Remote article'),
      );
    } finally {
      await server.close(force: true);
    }
  });
}
