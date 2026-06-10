#!/bin/sh
set -ex

rm -rf ../flutter
git clone https://github.com/flutter/flutter.git --depth 1 -b stable ../flutter
export PATH="$PATH:../flutter/bin"

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release --no-wasm-dry-run -O0 -v -t lib/main_admin.dart --dart-define=BACKEND_BASE_URL=https://abzora-backend.onrender.com > flutter-build.log 2>&1 || {
  cat flutter-build.log
  exit 1
}
