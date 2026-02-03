import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('override in main()');
});

/// Model class to hold connection settings state
class ConnectionSettings {
  final String name;
  final String host;
  final int port;

  const ConnectionSettings({
    required this.name,
    required this.host,
    required this.port,
  });

  /// Check if connection settings are properly configured
  bool get isSet => host.isNotEmpty && port > 0;
  Uri get baseUrl => Uri.parse('http://$host:$port');

  ConnectionSettings copyWith({
    String? name,
    String? host,
    int? port,
    bool? isLoaded,
  }) {
    return ConnectionSettings(
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionSettings &&
        other.name == name &&
        other.host == host &&
        other.port == port;
  }

  @override
  int get hashCode {
    return Object.hash(name, host, port);
  }

  @override
  String toString() {
    return 'ConnectionSettings(name: $name, host: $host, port: $port)';
  }
}

/// StateNotifier for managing connection settings
class ConnectionSettingsNotifier extends Notifier<ConnectionSettings> {
  static const String sharedPrefName = 'Kalinka.name';
  static const String sharedPrefHost = 'Kalinka.host';
  static const String sharedPrefPort = 'Kalinka.port';

  late SharedPreferences _sharedPrefs;

  /// Initialize settings from SharedPreferences
  ConnectionSettings _load() {
    final name = _sharedPrefs.getString(sharedPrefName) ?? 'Unknown';
    final host = _sharedPrefs.getString(sharedPrefHost) ?? '';
    final port = _sharedPrefs.getInt(sharedPrefPort) ?? 0;

    return ConnectionSettings(name: name, host: host, port: port);
  }

  /// Set device connection settings
  Future<void> setDevice(String name, String host, int port) async {
    await _sharedPrefs.setString(sharedPrefName, name);
    await _sharedPrefs.setString(sharedPrefHost, host);
    await _sharedPrefs.setInt(sharedPrefPort, port);

    state = ConnectionSettings(name: name, host: host, port: port);
  }

  /// Reset connection settings
  void reset() {
    state = ConnectionSettings(name: '', host: '', port: 0);
  }

  @override
  ConnectionSettings build() {
    // Get SharedPreferences from the provider
    _sharedPrefs = ref.read(sharedPrefsProvider);
    return _load();
  }
}

/// Provider for connection settings
final connectionSettingsProvider =
    NotifierProvider<ConnectionSettingsNotifier, ConnectionSettings>(
      ConnectionSettingsNotifier.new,
    );
