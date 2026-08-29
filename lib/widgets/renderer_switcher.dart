import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_model/data_model.dart' show RendererInfo;
import '../providers/kalinka_player_api_provider.dart'
    show RendererSwitchException;
import '../providers/renderer_host_provider.dart' show rendererIdentityProvider;
import '../providers/renderer_provider.dart';
import '../providers/renderer_settings_route_provider.dart';
import '../providers/toast_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import 'kalinka_bottom_sheet.dart';
import 'transport_button.dart';

/// One string for the chrome (tooltips, labels) and the sheet's empty note,
/// so the copy cannot drift between them.
const _noRendererLabel = 'No renderer available';

/// What a row in the picker was asked to do.
enum RendererPickerIntent { play, configure }

/// The renderer a row names, and which of its two controls was tapped.
class RendererPickerChoice {
  final String rendererId;
  final String rendererName;
  final RendererPickerIntent intent;

  const RendererPickerChoice({
    required this.rendererId,
    required this.rendererName,
    required this.intent,
  });
}

/// Icon button that opens the renderer picker — the list of playback endpoints
/// the server knows about, with the one playback is running on marked.
///
/// Renders nothing until a list has been read (and never on a server that
/// predates the `/renderer/*` endpoints). A loaded-but-empty list still shows
/// the crossed icon: playback is going to fail, and the sheet says why.
class RendererSwitcherButton extends ConsumerWidget {
  final double hitDiameter;
  final double iconSize;

  const RendererSwitcherButton({
    super.key,
    this.hitDiameter = 46,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One record select: structural == keeps rebuilds scoped to these facets.
    final (visible, empty, playingOn, outputLive) = ref.watch(
      rendererListProvider.select(
        (s) => (
          s.switcherVisible,
          s.renderers.isEmpty,
          // The button is too small for a name, so the current output goes in
          // the label instead — otherwise nothing says where sound is going.
          s.active?.friendlyName,
          // Live = sound has somewhere to go: an output chosen and reachable.
          s.active?.isConnected ?? false,
        ),
      ),
    );
    if (!visible) return const SizedBox.shrink();

    final idleLabel = empty ? _noRendererLabel : 'Choose output';
    return Semantics(
      label: playingOn == null || playingOn.isEmpty
          ? idleLabel
          : 'Output: $playingOn',
      button: true,
      child: Tooltip(
        message: idleLabel,
        excludeFromSemantics: true,
        child: TransportButton(
          hitDiameter: hitDiameter,
          onTapDown: (_) => KalinkaHaptics.selectionClick(),
          onTap: () => _openPicker(context, ref),
          child: _CastGlyph(size: iconSize, live: outputLive),
        ),
      ),
    );
  }
}

/// Cast icon, badged with a grey cross only when sound has nowhere to go —
/// the normal state is unremarkable and gets no ornament.
class _CastGlyph extends StatelessWidget {
  final double size;
  final bool live;

  const _CastGlyph({required this.size, required this.live});

  @override
  Widget build(BuildContext context) {
    // Constant footprint in both states, or the row twitches on live flips.
    return SizedBox(
      width: size + 4,
      height: size + 2,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(Icons.cast, size: size, color: KalinkaColors.textSecondary),
          if (!live)
            const Positioned(
              right: 0,
              bottom: 0,
              child: Icon(
                Icons.close,
                size: 10,
                color: KalinkaColors.statusOffline,
              ),
            ),
        ],
      ),
    );
  }
}

/// Renderer switch for the Now Playing header: the current output by name,
/// with a chevron saying a menu drops from it. Same picker as the playbar
/// button, same crossed-icon empty state when the server has no renderers.
class RendererSwitcherDropdown extends ConsumerWidget {
  /// Longer names are ellipsised; the header has a centred label to respect.
  final double maxNameWidth;

  const RendererSwitcherDropdown({super.key, this.maxNameWidth = 140});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (visible, empty, outputLive) = ref.watch(
      rendererListProvider.select(
        (s) => (
          s.switcherVisible,
          s.renderers.isEmpty,
          s.active?.isConnected ?? false,
        ),
      ),
    );
    if (!visible) return const SizedBox.shrink();

    final active = ref.watch(rendererListProvider.select((s) => s.active));
    final ownId = ref.watch(rendererIdentityProvider).value?.rendererId;
    final idleLabel = empty ? _noRendererLabel : 'Choose output';
    final name = active == null
        ? idleLabel
        : rendererDisplayName(active, isSelf: active.rendererId == ownId);

    return Semantics(
      label: active == null ? name : 'Output: $name',
      button: true,
      child: Tooltip(
        message: idleLabel,
        excludeFromSemantics: true,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              KalinkaHaptics.selectionClick();
              _openPicker(context, ref);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CastGlyph(size: 18, live: outputLive),
                  const SizedBox(width: 7),
                  ConstrainedBox(
                    // The empty-state message must never ellipsise; names may.
                    constraints: BoxConstraints(
                      maxWidth: empty ? 200 : maxNameWidth,
                    ),
                    child: Text(
                      name,
                      style: KalinkaTextStyles.trayRowSublabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: KalinkaColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(rendererListProvider.notifier);
  final toast = ref.read(toastProvider.notifier);
  final route = ref.read(rendererSettingsRouteProvider.notifier);
  final navigator = Navigator.of(context);
  // Servers with the renderer events keep the list fresh over the queue
  // socket; this re-read is the fallback for ones that predate them.
  notifier.refresh();
  final choice = await showKalinkaBottomSheet<RendererPickerChoice>(
    context: context,
    contentBuilder: (_) => const RendererPickerContent(),
  );
  if (choice == null) return;

  switch (choice.intent) {
    case RendererPickerIntent.configure:
      // The panel is hosted by MusicPlayerScreen, under anything still on
      // the navigator — the phone's Now Playing sheet, for one. Fall back
      // to it first so the panel is what the user ends up looking at.
      navigator.popUntil((r) => r.isFirst);
      route.open(choice.rendererId, choice.rendererName);
    case RendererPickerIntent.play:
      try {
        await notifier.select(choice.rendererId);
      } on RendererSwitchException catch (e) {
        toast.show(e.message, isError: true);
      } catch (_) {
        toast.show('Couldn’t switch output', isError: true);
      }
  }
}

/// Body of the renderer picker sheet. Pops a [RendererPickerChoice].
class RendererPickerContent extends ConsumerWidget {
  const RendererPickerContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rendererListProvider);
    final renderers = state.renderers;
    final ownId = ref.watch(rendererIdentityProvider).value?.rendererId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PickerHeader(),
        if (renderers.isEmpty)
          _EmptyNote(loading: state.loading)
        else
          // Many-renderer installs are rare, but a scroll cap keeps the sheet
          // from swallowing the screen if one turns up.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 10),
              itemCount: renderers.length,
              itemBuilder: (ctx, i) => _RendererRow(
                renderer: renderers[i],
                isSelf: renderers[i].rendererId == ownId,
                onIntent: (intent) => Navigator.pop(
                  ctx,
                  RendererPickerChoice(
                    rendererId: renderers[i].rendererId,
                    rendererName: rendererDisplayName(
                      renderers[i],
                      isSelf: renderers[i].rendererId == ownId,
                    ),
                    intent: intent,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Sheet title. The list keeps itself current over the queue socket, so the
/// header offers nothing to press.
class _PickerHeader extends StatelessWidget {
  const _PickerHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text('PLAY ON', style: KalinkaTextStyles.sectionHeaderMuted),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final bool loading;

  const _EmptyNote({required this.loading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loading ? 'Looking for outputs…' : _noRendererLabel,
            style: KalinkaTextStyles.trayRowLabel,
          ),
          if (!loading) ...[
            const SizedBox(height: 4),
            Text(
              'An output appears here once it connects to your server.',
              style: KalinkaTextStyles.trayRowSublabel,
            ),
          ],
        ],
      ),
    );
  }
}

/// Friendly name, falling back to the id for a renderer that reported none.
/// The renderer this page itself hosts is simply "This browser" — the
/// UA-derived name it registers under is for everyone else's picker.
String rendererDisplayName(RendererInfo renderer, {bool isSelf = false}) {
  if (isSelf && renderer.kind == 'web') return 'This browser';
  return renderer.friendlyName.isEmpty
      ? renderer.rendererId
      : renderer.friendlyName;
}

const _backendLabels = {
  'alsa': 'ALSA',
  'pipewire': 'PipeWire',
  'pulse': 'PulseAudio',
  'pulseaudio': 'PulseAudio',
  'coreaudio': 'Core Audio',
  'wasapi': 'WASAPI',
  'oboe': 'Oboe',
};

/// Supporting line: which machine this output is and how it plays — the
/// question the picker exists to answer, since friendly names alone don't
/// distinguish two boxes. Offline leads, because it's why the row is dead.
String rendererDetail(RendererInfo renderer, {bool isSelf = false}) {
  final parts = <String>[];
  if (!renderer.isConnected) parts.add('Offline');
  final host = renderer.hostname;
  // Skipped when the name already carries it — most default to "… on <host>".
  if (host.isNotEmpty &&
      !renderer.friendlyName.toLowerCase().contains(host.toLowerCase())) {
    parts.add(host);
  }
  if (renderer.isConnected) {
    // Skipped for the self row, whose name already reads "This browser".
    if (renderer.kind == 'web' && !isSelf) parts.add('Browser');
    final backend = renderer.audioBackend;
    if (backend.isNotEmpty) {
      parts.add(_backendLabels[backend.toLowerCase()] ?? backend);
    }
  }
  return parts.join(' · ');
}

class _RendererRow extends StatelessWidget {
  final RendererInfo renderer;

  /// The renderer this app itself hosts (web build); its row says so.
  final bool isSelf;
  final ValueChanged<RendererPickerIntent> onIntent;

  const _RendererRow({
    required this.renderer,
    required this.isSelf,
    required this.onIntent,
  });

  @override
  Widget build(BuildContext context) {
    final connected = renderer.isConnected;
    final active = renderer.active;
    // Pinning an offline renderer leaves playback where it is, so those rows
    // are shown for context but can't be chosen.
    final canPlayHere = connected && !active;
    // Settings are read from the renderer over its own socket, so an offline
    // one has nothing to serve — but the renderer playback is already on is a
    // perfectly good thing to configure.
    final canConfigure = connected;
    final name = rendererDisplayName(renderer, isSelf: isSelf);
    final detail = rendererDetail(renderer, isSelf: isSelf);

    return Semantics(
      // One output plays at a time; say so rather than leaving a screen reader
      // to infer it from a tick.
      inMutuallyExclusiveGroup: true,
      selected: active,
      enabled: connected,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          // Selection lives in the container, not the label colour — it
          // survives a glance and doesn't lean on hue to carry state.
          color: active ? KalinkaColors.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? KalinkaColors.accentBorder : Colors.transparent,
          ),
        ),
        child: Opacity(
          opacity: connected ? 1.0 : 0.45,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Full-bleed, and under the content: hovering the name lights
                // the whole item rather than the strip left of the rule. The
                // gear is painted over it and takes its own hits first, so its
                // highlight stays a circle.
                Positioned.fill(
                  child: InkWell(
                    onTap: canPlayHere
                        ? () {
                            KalinkaHaptics.selectionClick();
                            onIntent(RendererPickerIntent.play);
                          }
                        : null,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      // Text swallows pointers (RenderParagraph hit-tests
                      // itself for selection), which would keep the hover off
                      // the InkWell below. Nothing here is a target anyway.
                      child: IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(11, 10, 8, 10),
                          child: Row(
                            children: [
                              _SelectionMark(selected: active),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: KalinkaTextStyles.trayRowLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (detail.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        detail,
                                        style:
                                            KalinkaTextStyles.trayRowSublabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Two targets in one row: the rule is what says so.
                    Container(
                      width: 1,
                      height: 26,
                      color: KalinkaColors.borderSubtle,
                    ),
                    _GearButton(
                      rendererName: name,
                      onTap: canConfigure
                          ? () {
                              KalinkaHaptics.selectionClick();
                              onIntent(RendererPickerIntent.configure);
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Leading single-choice mark: an empty ring, filled with a check on the
/// output playback runs on. Shape carries the state, colour only reinforces.
class _SelectionMark extends StatelessWidget {
  final bool selected;

  const _SelectionMark({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? KalinkaColors.accent : Colors.transparent,
        border: Border.all(
          color: selected ? KalinkaColors.accent : KalinkaColors.borderDefault,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 13, color: KalinkaColors.textPrimary)
          : null,
    );
  }
}

class _GearButton extends StatelessWidget {
  final String rendererName;
  final VoidCallback? onTap;

  const _GearButton({required this.rendererName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rendererName settings',
      button: true,
      enabled: onTap != null,
      child: Tooltip(
        message: 'Output settings',
        excludeFromSemantics: true,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.settings_outlined,
                size: 19,
                color: onTap == null
                    ? KalinkaColors.textMuted
                    : KalinkaColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
