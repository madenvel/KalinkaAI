import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connection_settings_provider.dart';
import '../providers/connection_state_provider.dart';

class MediaNotificationNotifier extends Notifier<void> {
  static const _methodChannel = MethodChannel(
    'org.kalinka.kalinka/media_session',
  );

  @override
  void build() {
    if (!Platform.isAndroid) return;

    // Enable immediately if already connected.
    final currentStatus = ref.read(connectionStateProvider);
    if (currentStatus == ConnectionStatus.connected) {
      final settings = ref.read(connectionSettingsProvider);
      if (settings.isSet) _enable(settings.host, settings.port);
    }

    // Re-enable on every successful (re)connection. The native service
    // self-disables when its own WS drops, so each `connected` transition is
    // the signal to spin a fresh session up. Transient states
    // (connecting, reconnecting) are ignored.
    ref.listen(connectionStateProvider, (_, status) {
      if (status == ConnectionStatus.connected) {
        final settings = ref.read(connectionSettingsProvider);
        if (settings.isSet) _enable(settings.host, settings.port);
      } else if (status == ConnectionStatus.none ||
          status == ConnectionStatus.offline) {
        _disable();
      }
    });
  }

  void _enable(String host, int port) {
    _methodChannel.invokeMethod<void>('enableNotification', {
      'host': host,
      'port': port,
    });
  }

  void _disable() {
    _methodChannel.invokeMethod<void>('disableNotification').ignore();
  }
}

final mediaNotificationProvider =
    NotifierProvider<MediaNotificationNotifier, void>(
      MediaNotificationNotifier.new,
    );
