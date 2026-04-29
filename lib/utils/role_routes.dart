import '../app_shell.dart';
import '../models/models.dart';
import 'app_mode_routes.dart';

String routeForUser(AppUser? user) {
  return routeForUserInMode(user, AbzioAppMode.unified);
}
