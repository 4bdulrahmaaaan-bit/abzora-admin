#!/bin/sh
set -ex

rm -rf ../flutter
git clone https://github.com/flutter/flutter.git --depth 1 -b stable ../flutter
export PATH="$PATH:../flutter/bin"

flutter --version
flutter config --enable-web
flutter pub get
flutter analyze lib/main_admin.dart lib/screens/admin/admin_categories_section.dart lib/screens/admin/admin_web_panel.dart lib/services/backend_commerce_service.dart lib/models/category_management_model.dart lib/services/storage_service.dart
flutter build web --release --no-wasm-dry-run -O1 -t lib/main_admin.dart --dart-define=BACKEND_BASE_URL=https://abzora-backend.onrender.com
