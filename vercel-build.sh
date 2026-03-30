#!/bin/sh
set -e

git clone https://github.com/flutter/flutter.git --depth 1 -b stable ../flutter
export PATH="$PATH:../flutter/bin"

flutter config --enable-web
flutter pub get
flutter build web --release --dart-define=BACKEND_BASE_URL=https://abzora-backend.onrender.com
