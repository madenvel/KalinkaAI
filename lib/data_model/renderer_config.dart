// Wire types for `GET`/`PUT /renderer/{id}/config`.
//
// A renderer owns its own settings — they are not part of `/server/config`, so
// they arrive in their own vocabulary rather than the presentation schema's.
// Translating one to the other is `renderer_config_adapter.dart`'s job; this
// file only parses what the server sends.
//
// Values are text on the wire in both directions, as they are in the
// renderer's native config; [RendererConfigField.type] says how to read them.

/// How a renderer field's value should be interpreted.
enum RendererFieldType {
  string,
  integer,
  boolean,
  enumeration,

  /// No value — writing anything runs it once.
  trigger,
  unknown;

  static RendererFieldType fromName(String? s) => switch (s) {
    'string' => RendererFieldType.string,
    'int' => RendererFieldType.integer,
    'bool' => RendererFieldType.boolean,
    'enum' => RendererFieldType.enumeration,
    'trigger' => RendererFieldType.trigger,
    _ => RendererFieldType.unknown,
  };
}

/// What applying a field costs, so the page can warn before the user commits.
enum RendererApplyCost {
  instant,
  interruptsPlayback,
  restartRequired,
  unknown;

  static RendererApplyCost fromName(String? s) => switch (s) {
    'instant' => RendererApplyCost.instant,
    'interrupts_playback' => RendererApplyCost.interruptsPlayback,
    'restart_required' => RendererApplyCost.restartRequired,
    _ => RendererApplyCost.unknown,
  };

  /// Ordering for "worst cost among these fields" — [unknown] sorts lowest so
  /// a cost this build doesn't recognise never invents a warning.
  int get severity => switch (this) {
    RendererApplyCost.unknown => 0,
    RendererApplyCost.instant => 1,
    RendererApplyCost.interruptsPlayback => 2,
    RendererApplyCost.restartRequired => 3,
  };

  /// Short phrase for the pending-changes banner, or null when applying is
  /// silent.
  String? get warning => switch (this) {
    RendererApplyCost.interruptsPlayback => 'playback will stop',
    RendererApplyCost.restartRequired => 'renderer restart required',
    _ => null,
  };
}

class RendererConfigOption {
  final String value;
  final String label;
  final String description;

  const RendererConfigOption({
    required this.value,
    required this.label,
    this.description = '',
  });

  factory RendererConfigOption.fromJson(Map<String, dynamic> j) =>
      RendererConfigOption(
        value: (j['value'] ?? '') as String,
        label: (j['label'] ?? '') as String,
        description: (j['description'] ?? '') as String,
      );
}

class RendererConfigField {
  /// Dotted and renderer-local, e.g. `output.alsa.device`.
  final String path;
  final String title;
  final String description;
  final RendererFieldType type;
  final String value;
  final String defaultValue;

  /// Populated for [RendererFieldType.enumeration] only.
  final List<RendererConfigOption> options;
  final RendererApplyCost apply;
  final bool readOnly;

  const RendererConfigField({
    required this.path,
    required this.title,
    this.description = '',
    this.type = RendererFieldType.unknown,
    this.value = '',
    this.defaultValue = '',
    this.options = const [],
    this.apply = RendererApplyCost.unknown,
    this.readOnly = false,
  });

  factory RendererConfigField.fromJson(Map<String, dynamic> j) =>
      RendererConfigField(
        path: (j['path'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        type: RendererFieldType.fromName(j['type'] as String?),
        value: (j['value'] ?? '') as String,
        defaultValue: (j['default'] ?? '') as String,
        options: [
          for (final o in (j['options'] ?? const []) as List)
            RendererConfigOption.fromJson(Map<String, dynamic>.from(o as Map)),
        ],
        apply: RendererApplyCost.fromName(j['apply'] as String?),
        readOnly: (j['read_only'] ?? false) as bool,
      );
}

class RendererConfigSection {
  /// Prefix shared by its fields, e.g. `output`.
  final String path;
  final String title;
  final String description;
  final List<RendererConfigField> fields;

  const RendererConfigSection({
    required this.path,
    required this.title,
    this.description = '',
    this.fields = const [],
  });

  factory RendererConfigSection.fromJson(Map<String, dynamic> j) =>
      RendererConfigSection(
        path: (j['path'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        fields: [
          for (final f in (j['fields'] ?? const []) as List)
            RendererConfigField.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
      );
}

/// Schema and values together — one round trip is a whole settings page, with
/// the device list as fresh as the request.
class RendererConfigSnapshot {
  /// Changes whenever the shape or the options change. Not a write
  /// precondition; it says whether a held page is still the right shape.
  final String configVersion;
  final List<RendererConfigSection> sections;

  const RendererConfigSnapshot({
    this.configVersion = '',
    this.sections = const [],
  });

  factory RendererConfigSnapshot.fromJson(Map<String, dynamic> j) =>
      RendererConfigSnapshot(
        configVersion: (j['config_version'] ?? '') as String,
        sections: [
          for (final s in (j['sections'] ?? const []) as List)
            RendererConfigSection.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
      );
}

/// What became of one requested change.
class RendererConfigOutcome {
  final String path;
  final bool applied;

  /// What is in effect now, which may not be what was asked.
  final String value;

  /// Set when [applied] is false.
  final String error;

  const RendererConfigOutcome({
    required this.path,
    required this.applied,
    this.value = '',
    this.error = '',
  });

  factory RendererConfigOutcome.fromJson(Map<String, dynamic> j) =>
      RendererConfigOutcome(
        path: (j['path'] ?? '') as String,
        applied: (j['applied'] ?? false) as bool,
        value: (j['value'] ?? '') as String,
        error: (j['error'] ?? '') as String,
      );
}

/// Reply to `PUT /renderer/{id}/config`.
class RendererConfigResult {
  final String configVersion;

  /// The worst cost among the settings that were *actually* applied — what
  /// just happened, not what might.
  final RendererApplyCost effect;
  final List<RendererConfigOutcome> outcomes;

  const RendererConfigResult({
    this.configVersion = '',
    this.effect = RendererApplyCost.unknown,
    this.outcomes = const [],
  });

  Iterable<RendererConfigOutcome> get rejected =>
      outcomes.where((o) => !o.applied);

  factory RendererConfigResult.fromJson(Map<String, dynamic> j) =>
      RendererConfigResult(
        configVersion: (j['config_version'] ?? '') as String,
        effect: RendererApplyCost.fromName(j['effect'] as String?),
        outcomes: [
          for (final o in (j['outcomes'] ?? const []) as List)
            RendererConfigOutcome.fromJson(Map<String, dynamic>.from(o as Map)),
        ],
      );
}
