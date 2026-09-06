import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The two modes a community member can switch between on the home screen,
/// Grab-style. Resident Mode is for needing/triggering help; Responder Mode is
/// for giving help and receiving nearby SOS alerts.
enum UserMode {
  resident('Resident Mode', 'Get help'),
  responder('Responder Mode', 'Give help');

  const UserMode(this.label, this.tagline);

  final String label;
  final String tagline;

  UserMode get toggled =>
      this == UserMode.resident ? UserMode.responder : UserMode.resident;
}

/// Holds the currently-selected mode for the signed-in community member.
/// Defaults to Resident Mode (safest default — the app opens ready to call for
/// help). This is a client-side UI state, not a role or a server value.
class UserModeController extends StateNotifier<UserMode> {
  UserModeController() : super(UserMode.resident);

  void set(UserMode mode) => state = mode;
  void toggle() => state = state.toggled;
}

final StateNotifierProvider<UserModeController, UserMode> userModeProvider =
    StateNotifierProvider<UserModeController, UserMode>(
  (Ref ref) => UserModeController(),
);
