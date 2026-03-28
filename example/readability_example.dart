// ignore_for_file: avoid_print

import 'package:reader_mode/reader_mode.dart';

void main() {
  // Example HTML content
  const html = '''
<!DOCTYPE html>
<html>
<head>
  <title>Example Article</title>
  <meta name="author" content="John Doe"/>
</head>
<body>
  <nav>Navigation links here</nav>
  <article>
    <h1>The Main Article Title</h1>
    <p>This is the first paragraph of the article content.
    It contains important information that readers want to see.</p>
    <p>This is another paragraph with more content. The Readability
    algorithm will extract this as the main content of the page.</p>
  </article>
  <aside>Sidebar content</aside>
  <footer>Footer content</footer>
</body>
</html>
''';

  // Method 1: Use the parse() convenience function (recommended)
  print('Parsing with parse() function...\n');
  final article = parse(
    html,
    baseUri: 'https://example.com/article',
  );
  if (article == null) {
    throw StateError('Failed to extract readable content');
  }

  print('Title: ${article.title}');
  print('Byline: ${article.byline}');
  print('Excerpt: ${article.excerpt}');
  print('Length: ${article.length} characters');
  print('\nContent:\n${article.content}');
}
