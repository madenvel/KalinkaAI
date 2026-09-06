import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart' show Genre;
import 'kalinka_player_api_provider.dart';

/// The genre taxonomy offered by one input source (empty string = every
/// enabled source). Only reached from a surface whose capabilities say genre
/// filtering is honoured, so a source without a taxonomy is never asked.
final browseGenresProvider = FutureProvider.family<List<Genre>, String>((
  ref,
  source,
) async {
  final api = ref.read(kalinkaProxyProvider);
  final list = await api.getGenres(source.isEmpty ? null : source);
  return list.items;
});
