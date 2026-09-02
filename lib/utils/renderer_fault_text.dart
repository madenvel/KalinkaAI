/// Substitutes renderer names for ids in [text], given [namesById], taking the
/// log-style `renderer` label in front of an id with it.
///
/// The server names renderers by id, which is on no screen the user has seen.
/// An entry whose name is its own id — the picker's fallback for a renderer
/// that reported none — is left alone, label and all.
String nameRenderersIn(String text, Map<String, String> namesById) {
  var out = text;
  for (final MapEntry(key: id, value: name) in namesById.entries) {
    if (id.isEmpty || name.isEmpty || name == id || !out.contains(id)) continue;
    out = out.replaceAll('renderer $id', name).replaceAll(id, name);
  }
  return out;
}

/// What to tell the user when the server refuses to move playback to a
/// renderer, from the [status] it answered with and the [detail] it gave.
String rendererSwitchRefusal({
  required int? status,
  String? detail,
  String? rendererId,
  String? rendererName,
}) {
  // The picker shows a nameless renderer's id, so an id can arrive as the name.
  final named =
      rendererName != null &&
      rendererName.isNotEmpty &&
      rendererName != rendererId;
  final label = named ? rendererName : 'That output';
  // 409 here is a claimed renderer and nothing else, so the detail adds only
  // the id.
  if (status == 409) return '$label is playing through another Kalinka server';
  // The server separates reasons the statuses below cannot — an output merely
  // offline from one too old to be driven.
  if (detail != null && detail.isNotEmpty) {
    return nameRenderersIn(detail, {
      if (named && rendererId != null) rendererId: rendererName,
    });
  }
  return switch (status) {
    404 => '$label is no longer available',
    503 => '$label isn’t connected',
    504 => '$label didn’t respond',
    _ => 'Couldn’t switch output',
  };
}
