import 'app_shell.dart';

Future<void> main() async {
  AbzioApp.isAdminApp = true;
  await bootstrapAndRunWithInitialRoute(
    AbzioAppMode.unified,
    initialRoute: '/admin-login',
  );
}
