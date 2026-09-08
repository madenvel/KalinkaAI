import 'package:flutter_test/flutter_test.dart';

import 'package:kalinka/data_model/data_model.dart';

/// Two flags older servers never send. Both default off: an item is not
/// editable and a source is not built in until the server says so.
void main() {
  test('an item without can_edit is not editable', () {
    final item = BrowseItem.fromJson({
      'id': 'kalinka:qobuz:playlist:1',
      'name': 'Theirs',
      'can_browse': true,
      'can_add': true,
    });

    expect(item.canEdit, isFalse);
  });

  test('an item the server will edit says so, and keeps saying so', () {
    final item = BrowseItem.fromJson({
      'id': 'kalinka:collections:playlist:1',
      'name': 'Mine',
      'can_browse': true,
      'can_add': true,
      'can_edit': true,
    });

    expect(item.canEdit, isTrue);
    expect(BrowseItem.fromJson(item.toJson()).canEdit, isTrue);
  });

  test('a module without the builtin field is a plugin', () {
    final module = ModuleInfo.fromJson({
      'name': 'qobuz',
      'title': 'Qobuz',
      'enabled': true,
      'state': 'ready',
    });

    expect(module.builtin, isFalse);
  });

  test('a built-in module says so', () {
    final module = ModuleInfo.fromJson({
      'name': 'collections',
      'title': 'Collections',
      'enabled': true,
      'state': 'ready',
      'builtin': true,
    });

    expect(module.builtin, isTrue);
    expect(ModuleInfo.fromJson(module.toJson()).builtin, isTrue);
  });
}
