class TrialStatusGuard {
  static const List<String> terminalStatuses = [
    'cancelled',
    'no_show',
    'converted_to_order',
  ];

  static bool isTerminalStatus(String status) {
    return terminalStatuses.contains(status);
  }

  static bool canTransition(String current, String next) {
    if (isTerminalStatus(current)) {
      return false; // Cannot transition out of a terminal status
    }

    // Terminal statuses can be reached from appropriate states
    if (next == 'cancelled') {
      return current == 'booked' ||
          current == 'rider_assigned' ||
          current == 'out_for_trial_delivery' ||
          current == 'arrived';
    }

    if (next == 'no_show') {
      return current == 'arrived';
    }

    switch (current) {
      case 'booked':
        return next == 'rider_assigned';
      case 'rider_assigned':
        return next == 'out_for_trial_delivery';
      case 'out_for_trial_delivery':
        return next == 'arrived';
      case 'arrived':
        return next == 'trial_in_progress';
      case 'trial_in_progress':
        return next == 'awaiting_final_payment';
      case 'awaiting_final_payment':
        return next == 'converted_to_order';
      default:
        return false;
    }
  }

  static void validateTransition(String current, String next) {
    if (!canTransition(current, next)) {
      throw StateError('Invalid trial session transition: $current -> $next');
    }
  }

  static void validateModifiable(String current) {
    if (isTerminalStatus(current) || current == 'awaiting_final_payment') {
      throw StateError('Trial session is locked and cannot be modified in status: $current');
    }
  }
}
