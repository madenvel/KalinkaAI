/// Substitutes renderer names for ids in [text], given [namesById].
///
/// The server names renderers by id — "renderer 7f3a2c… is in use by another
/// Core" — because its logs read these first. No screen has ever shown that
/// id, so the picker's name replaces it, along with the label introducing it.
///
/// A renderer that reported no name is left alone: the picker falls back to
/// showing its id, and swapping an id for itself would only cost the label
/// that at least says what the id refers to.
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
  // The picker shows a nameless renderer's id, so an id can arrive here as the
  // name. It reads no better in our words than in the server's.
  final named =
      rendererName != null &&
      rendererName.isNotEmpty &&
      rendererName != rendererId;
  final label = named ? rendererName : 'That output';
  // 409 is a claimed renderer and nothing else, so the server's log-term
  // wording carries nothing the picker's own words don't.
  if (status == 409) return '$label is playing through another Kalinka server';
  // Elsewhere its words separate reasons the guesses below cannot — an output
  // merely offline from one too old to be driven — so they stand.
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
