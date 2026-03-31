#!/bin/sh
set -ex

git clone https://github.com/flutter/flutter.git --depth 1 -b stable ../flutter
export PATH="$PATH:../flutter/bin"

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release --no-wasm-dry-run -t lib/main_admin.dart --dart-define=BACKEND_BASE_URL=https://abzora-backend.onrender.com
