import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rider_signup_model.dart';

class RiderSignupNotifier extends StateNotifier<RiderSignupModel> {
  RiderSignupNotifier() : super(const RiderSignupModel());

  void update(RiderSignupModel next) => state = next;
}

final riderSignupProvider =
    StateNotifierProvider<RiderSignupNotifier, RiderSignupModel>(
      (ref) => RiderSignupNotifier(),
    );

final riderThemeModeProvider = StateProvider<bool>((ref) => true);
