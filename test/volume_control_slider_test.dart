import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/data_model/ext_device_events.dart';
import 'package:kalinka/data_model/kalinka_ws_api.dart';
import 'package:kalinka/providers/app_state_provider.dart';
import 'package:kalinka/providers/kalinka_ws_api_provider.dart';
import 'package:kalinka/widgets/volume_control_slider.dart';

// ── Fakes ──────────────────────────────────────────────────────────────────────

class _SettableExtDeviceNotifier extends ExtDeviceStateStore {
  _SettableExtDeviceNotifier(this._initial);
  final ExtDeviceState _initial;

  @override
  ExtDeviceState build() => _initial;

  void emit(ExtDeviceState s) => state = s;
}

/// Subclass that overrides sendDeviceCommand to avoid real WebSocket usage.
class _FakeWsApi extends KalinkaWsApi {
  _FakeWsApi(super.ref);
  final List<DeviceCommand> sentCommands = [];

  @override
  Future<void> sendDeviceCommand(DeviceCommand command) async {
    sentCommands.add(command);
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

ExtDeviceState _deviceState({
  int currentVolume = 50,
  int maxVolume = 100,
  bool supported = true,
  int seq = 0,
}) =>
    ExtDeviceState(
      powerOn: true,
      volume: DeviceVolume(
        currentVolume: currentVolume,
        maxVolume: maxVolume,
        volumeGain: 0,
        supported: supported,
      ),
      seq: seq,
    );

/// Pumps [NowPlayingVolumeControl] in an isolated [ProviderContainer].
///
/// Returns the container so tests can push new state via
/// `container.read(extDeviceStateStoreProvider.notifier) as
///  _SettableExtDeviceNotifier`.
///
/// The [_FakeWsApi] instance is accessible after first user interaction via
/// `container.read(kalinkaWsApiProvider) as _FakeWsApi`.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  ExtDeviceState? initialState,
}) async {
  final state = initialState ?? _deviceState();

  final container = ProviderContainer(
    overrides: [
      extDeviceStateStoreProvider
          .overrideWith(() => _SettableExtDeviceNotifier(state)),
      kalinkaWsApiProvider.overrideWith((ref) => _FakeWsApi(ref)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: NowPlayingVolumeControl(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  return container;
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('NowPlayingVolumeControl', () {
    // ── Visibility ────────────────────────────────────────────────────────────

    testWidgets('hidden when volume is not supported', (tester) async {
      await _pump(tester, initialState: _deviceState(supported: false));

      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('visible and at correct position when volume is supported',
        (tester) async {
      await _pump(
          tester, initialState: _deviceState(currentVolume: 30, maxVolume: 100));

      expect(find.byType(Slider), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, closeTo(0.30, 0.01));
    });

    // ── Mid-drag server echo must not reset the slider ────────────────────────

    testWidgets(
        'server echo during drag does not snap slider back to server value',
        (tester) async {
      // Arrange: server at 30 %, seq = 5.
      final container = await _pump(
        tester,
        initialState: _deviceState(currentVolume: 30, maxVolume: 100, seq: 5),
      );

      final sliderFinder = find.byType(Slider);

      // Act: start a drag gesture at the slider centre and move right.
      // The Slider fires onChanged on pointer-move, setting _isAdjustingVolume
      // = true and _localVolumeProgress to the new position.
      final gesture = await tester.startGesture(
        tester.getCenter(sliderFinder),
      );
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();

      final valueAfterDrag = tester.widget<Slider>(sliderFinder).value;
      // Sanity check: the drag moved the slider away from 30 %.
      expect(valueAfterDrag, isNot(closeTo(0.30, 0.05)));

      // Simulate a server echo (e.g., the 50 ms debounce command was processed).
      // seq changes → without the fix this resets _isAdjustingVolume, snapping
      // the thumb back to the server value (0.30).
      (container.read(extDeviceStateStoreProvider.notifier)
              as _SettableExtDeviceNotifier)
          .emit(_deviceState(currentVolume: 30, maxVolume: 100, seq: 6));
      await tester.pump();

      // Assert: slider must still show the local drag position.
      final valueAfterEcho = tester.widget<Slider>(sliderFinder).value;
      expect(valueAfterEcho, closeTo(valueAfterDrag, 0.001));

      // Cleanup.
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
    });

    // ── Post-drag server confirmation releases the override ───────────────────

    testWidgets(
        'server confirmation after drag end releases slider to server control',
        (tester) async {
      // Arrange: server at 30 %, seq = 5.
      final container = await _pump(
        tester,
        initialState: _deviceState(currentVolume: 30, maxVolume: 100, seq: 5),
      );

      final sliderFinder = find.byType(Slider);

      // Act: complete a full drag gesture.
      // onChangeEnd captures _volumeBeforeSeq = 5.
      final gesture = await tester.startGesture(
        tester.getCenter(sliderFinder),
      );
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await gesture.up(); // triggers onChangeEnd
      await tester.pump(const Duration(milliseconds: 100)); // drain debounce timer

      // Server processes the command and echoes back with seq = 6 and the new
      // volume (70 %).  The condition
      //   _isAdjustingVolume && _volumeBeforeSeq != null && next != _volumeBeforeSeq
      // is now true → slider returns to server-controlled mode.
      (container.read(extDeviceStateStoreProvider.notifier)
              as _SettableExtDeviceNotifier)
          .emit(_deviceState(currentVolume: 70, maxVolume: 100, seq: 6));
      await tester.pump();

      // Assert: slider now reflects server value (70 %).
      final slider = tester.widget<Slider>(sliderFinder);
      expect(slider.value, closeTo(0.70, 0.01));
    });

    // ── Same-seq event after drag end must NOT release ────────────────────────

    testWidgets(
        'same-seq server event after drag end does not release slider',
        (tester) async {
      // Arrange.
      final container = await _pump(
        tester,
        initialState: _deviceState(currentVolume: 30, maxVolume: 100, seq: 5),
      );

      final sliderFinder = find.byType(Slider);

      final gesture = await tester.startGesture(
        tester.getCenter(sliderFinder),
      );
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      final valueAfterDrag = tester.widget<Slider>(sliderFinder).value;

      // Server event with the SAME seq as _volumeBeforeSeq — should not clear
      // the adjusting state (this would be a stale duplicate event).
      (container.read(extDeviceStateStoreProvider.notifier)
              as _SettableExtDeviceNotifier)
          .emit(_deviceState(currentVolume: 30, maxVolume: 100, seq: 5));
      await tester.pump();

      // Slider remains at the dragged position, not snapped back to 30 %.
      final valueAfterStaleEvent = tester.widget<Slider>(sliderFinder).value;
      expect(valueAfterStaleEvent, closeTo(valueAfterDrag, 0.001));
    });

    // ── Commands ──────────────────────────────────────────────────────────────

    testWidgets('sends set_volume command via WS when drag completes',
        (tester) async {
      final container = await _pump(
        tester,
        initialState: _deviceState(currentVolume: 50, maxVolume: 100),
      );

      // Complete a drag; onChangeEnd sends the command immediately.
      await tester.drag(find.byType(Slider), const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 100));

      // The provider is now initialised; cast is safe after interaction.
      final wsApi = container.read(kalinkaWsApiProvider) as _FakeWsApi;
      expect(wsApi.sentCommands, isNotEmpty);
      expect(wsApi.sentCommands.last, isA<SetVolumeCommand>());
    });
  });
}
