#!/bin/sh
set -ex

FLUTTER_REVISION="ff37bef603"

git init ../flutter
git -C ../flutter remote add origin https://github.com/flutter/flutter.git
git -C ../flutter fetch --depth 1 origin "$FLUTTER_REVISION"
git -C ../flutter checkout FETCH_HEAD
export PATH="$PATH:../flutter/bin"

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release --no-wasm-dry-run -t lib/main_admin.dart --dart-define=BACKEND_BASE_URL=https://abzora-backend.onrender.com
