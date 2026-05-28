import 'secure_session_storage_stub.dart';
import 'secure_session_storage_io.dart'
    if (dart.library.html) 'secure_session_storage_web.dart'
    as impl;

SecureSessionStorage createSecureSessionStorage() {
  return impl.createSecureSessionStorage();
}
