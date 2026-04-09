import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import 'kalinka_player_api_provider.dart';

/// Fetches browse details (album tracks, artist albums) for inline expansion.
final browseDetailProvider = FutureProvider.family<BrowseItemsList, String>((
  ref,
  id,
) async {
  final api = ref.read(kalinkaProxyProvider);
  return api.browse(id, limit: 50);
});
