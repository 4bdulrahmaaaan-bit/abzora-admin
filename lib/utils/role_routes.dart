import '../models/models.dart';

String routeForUser(AppUser? user) {
  if (user == null) {
    return '/login';
  }
  if (user.role == 'vendor' || user.role == 'rider') {
    return '/ops';
  }
  return '/shop';
}
