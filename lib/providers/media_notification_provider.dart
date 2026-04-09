import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_settings_provider.dart';
import '../providers/connection_state_provider.dart';

class MediaNotificationNotifier extends Notifier<void> {
  static const _methodChannel = MethodChannel(
    'org.kalinka.kalinka/media_session',
  );

  // Track which server the notification is currently enabled for.
  // Null means the notification is disabled.
  String? _enabledHost;
  int? _enabledPort;

  @override
  void build() {
    if (!Platform.isAndroid) return;

    // Enable immediately if already connected.
    final currentStatus = ref.read(connectionStateProvider);
    if (currentStatus == ConnectionStatus.connected) {
      final settings = ref.read(connectionSettingsProvider);
      if (settings.isSet) _enable(settings.host, settings.port);
    }

    // Enable on connect; disable only on intentional disconnect (none) or
    // permanent loss (offline). Transient states (connecting, reconnecting)
    // are ignored to prevent the notification from flickering — e.g. when the
    // WS briefly cycles during a reconnect or when the user opens Now Playing.
    ref.listen(connectionStateProvider, (_, status) {
      if (status == ConnectionStatus.connected) {
        final settings = ref.read(connectionSettingsProvider);
        if (settings.isSet) {
          // Skip if already enabled for the same server.
          if (settings.host != _enabledHost || settings.port != _enabledPort) {
            _enable(settings.host, settings.port);
          }
        }
      } else if (status == ConnectionStatus.none ||
          status == ConnectionStatus.offline) {
        if (_enabledHost != null) _disable();
      }
      // connecting / reconnecting: leave the notification as-is.
    });
  }

  void _enable(String host, int port) {
    _enabledHost = host;
    _enabledPort = port;
    _methodChannel.invokeMethod<void>('enableNotification', {
      'host': host,
      'port': port,
    });
  }

  void _disable() {
    _enabledHost = null;
    _enabledPort = null;
    _methodChannel.invokeMethod<void>('disableNotification').ignore();
  }
}

final mediaNotificationProvider =
    NotifierProvider<MediaNotificationNotifier, void>(
      MediaNotificationNotifier.new,
    );
