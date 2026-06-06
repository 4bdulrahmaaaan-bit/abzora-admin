bool shouldForceLogoutAfterUnauthorizedRecovery({
  required bool isRestoringSession,
  required bool firebaseUserPresent,
  required bool localUserPresent,
}) {
  if (isRestoringSession) {
    return false;
  }
  if (firebaseUserPresent) {
    return false;
  }
  if (localUserPresent) {
    return false;
  }
  return true;
}
