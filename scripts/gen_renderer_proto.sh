#!/usr/bin/env bash
# Regenerate the renderer-protocol Dart bindings from protos/.
#
# protos/kalinka/renderer/v1/renderer.proto is a verbatim copy of the schema
# owned by the kalinka-server repo (packages/kalinka-renderer/proto/...);
# update it by copying, never by editing here.
#
# Needs protoc and the Dart plugin: dart pub global activate protoc_plugin
set -euo pipefail
cd "$(dirname "$0")/.."
PATH="$PATH:$HOME/.pub-cache/bin"
protoc -I protos --dart_out=lib/generated protos/kalinka/renderer/v1/renderer.proto
# Descriptor mirror; nothing imports it.
rm -f lib/generated/kalinka/renderer/v1/renderer.pbjson.dart
