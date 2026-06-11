import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Git-derived version embedded at build time by scripts/build_release.sh
/// (`git describe --tags --always --dirty`). Exact tag builds get "v0.1.0";
/// untagged builds get "v0.1.0-3-gabc1234" (commits since tag + hash).
/// Empty for plain `flutter build`/`flutter run`.
const gitDescribe = String.fromEnvironment('GIT_DESCRIBE');

/// App version from the platform package metadata (pubspec `version`).
final appVersionProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});
