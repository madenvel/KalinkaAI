import 'package:flutter_riverpod/flutter_riverpod.dart'
    show Provider, ProviderListenableSelect;
import './connection_settings_provider.dart' show connectionSettingsProvider;

class UrlResolver {
  UrlResolver(this.base);
  final String base;

  String abs(String path) {
    if (path.startsWith('http')) return path;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path : '/$path';
    return '$b$p';
  }

  String get baseKey => base; // stable key if you ever need it
}

// 2) Provider wired to your settings
final urlResolverProvider = Provider<UrlResolver>((ref) {
  // only rebuild resolver when the *base* actually changes
  final base = ref.watch(connectionSettingsProvider.select((s) => s.baseUrl));
  return UrlResolver(base.toString());
});
