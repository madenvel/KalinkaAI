// Dart mirror of `presentation_schema.py` on the backend.
//
// The backend describes the entire settings UI declaratively (pages → sections
// → fields, or pages → modules → sections → fields). The frontend only has
// to render what it receives — no re-mapping, no name-based heuristics, no
// hard-coded labels or banners.

enum Importance {
  normal,
  advanced,
  expert;

  static Importance fromName(String? s) => switch (s) {
    'advanced' => Importance.advanced,
    'expert' => Importance.expert,
    _ => Importance.normal,
  };
}

enum Severity {
  info,
  warning,
  danger;

  static Severity fromName(String? s) => switch (s) {
    'warning' => Severity.warning,
    'danger' => Severity.danger,
    _ => Severity.info,
  };
}

enum WidgetKind {
  text,
  password,
  path,
  url,
  toggle,
  numberInput,
  numberSlider,
  enumPills,
  enumDropdown,
  listEditor,
  folderList;

  static WidgetKind fromName(String? s) => switch (s) {
    'password' => WidgetKind.password,
    'path' => WidgetKind.path,
    'url' => WidgetKind.url,
    'toggle' => WidgetKind.toggle,
    'number_input' => WidgetKind.numberInput,
    'number_slider' => WidgetKind.numberSlider,
    'enum_pills' => WidgetKind.enumPills,
    'enum_dropdown' => WidgetKind.enumDropdown,
    'list_editor' => WidgetKind.listEditor,
    'folder_list' => WidgetKind.folderList,
    _ => WidgetKind.text,
  };
}

class BannerSpec {
  final String text;
  final Severity severity;
  final String? title;

  const BannerSpec({required this.text, required this.severity, this.title});

  factory BannerSpec.fromJson(Map<String, dynamic> j) => BannerSpec(
    text: j['text'] as String? ?? '',
    severity: Severity.fromName(j['severity'] as String?),
    title: j['title'] as String?,
  );
}

class Constraints {
  final double? ge;
  final double? le;
  final int? minLength;
  final int? maxLength;
  final double? step;
  final String? pattern;
  final String? unit;
  final double? sliderMin;
  final double? sliderMax;

  const Constraints({
    this.ge,
    this.le,
    this.minLength,
    this.maxLength,
    this.step,
    this.pattern,
    this.unit,
    this.sliderMin,
    this.sliderMax,
  });

  factory Constraints.fromJson(Map<String, dynamic> j) => Constraints(
    ge: (j['ge'] as num?)?.toDouble(),
    le: (j['le'] as num?)?.toDouble(),
    minLength: j['min_length'] as int?,
    maxLength: j['max_length'] as int?,
    step: (j['step'] as num?)?.toDouble(),
    pattern: j['pattern'] as String?,
    unit: j['unit'] as String?,
    sliderMin: (j['slider_min'] as num?)?.toDouble(),
    sliderMax: (j['slider_max'] as num?)?.toDouble(),
  );
}

class FieldSpec {
  final String path;
  final String label;
  final WidgetKind widget;
  final String type;
  final String? help;
  final dynamic defaultValue;
  final bool readonly;
  final Importance importance;
  final List<String>? enumValues;
  final Constraints? constraints;

  const FieldSpec({
    required this.path,
    required this.label,
    required this.widget,
    required this.type,
    this.help,
    this.defaultValue,
    this.readonly = false,
    this.importance = Importance.normal,
    this.enumValues,
    this.constraints,
  });

  factory FieldSpec.fromJson(Map<String, dynamic> j) => FieldSpec(
    path: j['path'] as String,
    label: j['label'] as String,
    widget: WidgetKind.fromName(j['widget'] as String?),
    type: j['type'] as String,
    help: j['help'] as String?,
    defaultValue: j['default'],
    readonly: j['readonly'] as bool? ?? false,
    importance: Importance.fromName(j['importance'] as String?),
    enumValues: (j['enum_values'] as List?)?.map((e) => e.toString()).toList(),
    constraints: j['constraints'] is Map
        ? Constraints.fromJson((j['constraints'] as Map).cast<String, dynamic>())
        : null,
  );
}

class SectionSpec {
  final String id;
  final String title;
  final String? icon;
  final Importance importance;
  final List<BannerSpec> banners;
  final List<FieldSpec> fields;
  final List<SectionSpec> sections;

  const SectionSpec({
    required this.id,
    required this.title,
    this.icon,
    this.importance = Importance.normal,
    this.banners = const [],
    this.fields = const [],
    this.sections = const [],
  });

  factory SectionSpec.fromJson(Map<String, dynamic> j) => SectionSpec(
    id: j['id'] as String,
    title: j['title'] as String,
    icon: j['icon'] as String?,
    importance: Importance.fromName(j['importance'] as String?),
    banners: ((j['banners'] as List?) ?? [])
        .map((e) => BannerSpec.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    fields: ((j['fields'] as List?) ?? [])
        .map((e) => FieldSpec.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    sections: ((j['sections'] as List?) ?? [])
        .map((e) => SectionSpec.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

class ModuleSpec {
  final String id;
  final String kind; // "input_module" | "device"
  final String title;
  final String? icon;
  final String? iconColor;
  final String? status; // "ready" | "error" | "disabled" | null
  final String? errorMessage;
  final List<String> previewFields;
  final List<BannerSpec> banners;
  final List<SectionSpec> sections;

  const ModuleSpec({
    required this.id,
    required this.kind,
    required this.title,
    this.icon,
    this.iconColor,
    this.status,
    this.errorMessage,
    this.previewFields = const [],
    this.banners = const [],
    this.sections = const [],
  });

  factory ModuleSpec.fromJson(Map<String, dynamic> j) => ModuleSpec(
    id: j['id'] as String,
    kind: j['kind'] as String,
    title: j['title'] as String,
    icon: j['icon'] as String?,
    iconColor: j['icon_color'] as String?,
    status: j['status'] as String?,
    errorMessage: j['error_message'] as String?,
    previewFields: ((j['preview_fields'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    banners: ((j['banners'] as List?) ?? [])
        .map((e) => BannerSpec.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    sections: ((j['sections'] as List?) ?? [])
        .map((e) => SectionSpec.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

class PageSpec {
  final String id;
  final String title;
  final String? icon;
  final List<BannerSpec> banners;
  final List<SectionSpec> sections;
  final List<ModuleSpec> modules;

  const PageSpec({
    required this.id,
    required this.title,
    this.icon,
    this.banners = const [],
    this.sections = const [],
    this.modules = const [],
  });

  factory PageSpec.fromJson(Map<String, dynamic> j) => PageSpec(
    id: j['id'] as String,
    title: j['title'] as String,
    icon: j['icon'] as String?,
    banners: ((j['banners'] as List?) ?? [])
        .map((e) => BannerSpec.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    sections: ((j['sections'] as List?) ?? [])
        .map((e) => SectionSpec.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    modules: ((j['modules'] as List?) ?? [])
        .map((e) => ModuleSpec.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

class PresentationSchema {
  final String schemaVersion;
  final List<PageSpec> pages;

  const PresentationSchema({required this.schemaVersion, required this.pages});

  factory PresentationSchema.fromJson(Map<String, dynamic> j) =>
      PresentationSchema(
        schemaVersion: j['schema_version'] as String,
        pages: ((j['pages'] as List?) ?? [])
            .map((e) => PageSpec.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
