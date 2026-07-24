/// Decodes the handful of HTML entities that appear in provider-supplied
/// titles (Jamendo encodes ampersands, quotes, angle brackets, and numeric
/// references), so names render as text — "Smooth Jazz & Bossa" rather than
/// "Smooth Jazz &amp; Bossa". Applied once at JSON parse so every consumer
/// (search results, catalog pages, the queue) gets clean text.
String unescapeHtml(String input) {
  if (!input.contains('&')) return input;
  var s = input
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
  // Numeric references (&#123; / &#x1F; ). Decode ampersand LAST so a decoded
  // value can never form a fresh entity.
  s = s.replaceAllMapped(RegExp(r'&#(x?[0-9a-fA-F]+);'), (m) {
    final raw = m[1]!;
    final code = raw.startsWith('x')
        ? int.tryParse(raw.substring(1), radix: 16)
        : int.tryParse(raw);
    if (code == null || code < 0 || code > 0x10FFFF) return m[0]!;
    return String.fromCharCode(code);
  });
  return s.replaceAll('&amp;', '&');
}

/// Null-passthrough variant for nullable name fields.
String? unescapeHtmlOrNull(String? input) =>
    input == null ? null : unescapeHtml(input);
