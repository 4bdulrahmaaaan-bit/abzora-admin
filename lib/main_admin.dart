import 'app_shell.dart';

Future<void> main() async {
  await bootstrapAndRunWithInitialRoute(
    AbzioAppMode.unified,
    initialRoute: '/admin-login',
  );
}
