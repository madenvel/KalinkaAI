import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/collections_provider.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/toast_provider.dart';
import '../../theme/app_theme.dart';
import '../kalinka_bottom_sheet.dart';
import '../kalinka_button.dart';

/// Asks for a name and makes the collection, reporting through the shared
/// toast. Returns the new collection's browse id, or null if it was dismissed
/// or the server refused.
///
/// Whatever showed the collections refetches on its own: the write bumps
/// [collectionsRevisionProvider] rather than handing a row back to a caller
/// that would then have to place it.
Future<String?> showNewCollectionSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final name = await showKalinkaBottomSheet<String>(
    context: context,
    contentBuilder: (_) => const _NewCollectionForm(),
  );
  if (name == null || !context.mounted) return null;

  final api = ref.read(kalinkaProxyProvider);
  final toast = ref.read(toastProvider.notifier);
  try {
    final id = await api.createCollection(name);
    ref.read(collectionsRevisionProvider.notifier).bump();
    toast.show('$name created');
    return id;
  } catch (e) {
    toast.show('Could not create the collection: $e', isError: true);
    return null;
  }
}

/// The sheet body: one field and the two ways out. Pops its own name.
class _NewCollectionForm extends StatefulWidget {
  const _NewCollectionForm();

  @override
  State<_NewCollectionForm> createState() => _NewCollectionFormState();
}

class _NewCollectionFormState extends State<_NewCollectionForm> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // CREATE follows what is typed.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name => _controller.text.trim();

  void _submit() {
    if (_name.isEmpty) return;
    Navigator.of(context).pop(_name);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Clears the keyboard the field itself raises.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('NEW COLLECTION', style: KalinkaTextStyles.sectionLabel),
            const SizedBox(height: 6),
            Text(
              'Tracks from any source, in the order you choose.',
              style: KalinkaTextStyles.trackRowSubtitle,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              // The sheet exists to be typed into.
              autofocus: true,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
              onSubmitted: (_) => _submit(),
              style: KalinkaTextStyles.cardTitle,
              decoration: InputDecoration(
                hintText: 'Name it',
                counterText: '',
                hintStyle: KalinkaTextStyles.trackRowSubtitle,
                filled: true,
                fillColor: KalinkaColors.surfaceElevated,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: KalinkaColors.borderDefault,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: KalinkaColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                KalinkaButton(
                  label: 'CANCEL',
                  variant: KalinkaButtonVariant.neutral,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                KalinkaButton(
                  label: 'CREATE',
                  enabled: _name.isNotEmpty,
                  onTap: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
