import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/pocketpeers_api.dart';

final apiProvider = Provider<PocketPeersApi>((ref) => PocketPeersApi());
final onboardingCompletedProvider = FutureProvider<bool>((ref) {
  return ref.read(apiProvider).isOnboardingCompleted();
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  PocketPeersApi get _api => ref.read(apiProvider);

  @override
  Future<AuthSession?> build() => _api.restoreSession();

  Future<void> signIn(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _api.signIn(username, password));
  }

  Future<void> signUp({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String email,
  }) async {
    await _api.signUp(
      username: username,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      email: email,
    );
    await signIn(username, password);
  }

  Future<void> signOut() async {
    await _api.signOut();
    state = const AsyncData(null);
  }

  Future<void> completeOnboarding() async {
    await _api.completeOnboarding();
    ref.invalidate(onboardingCompletedProvider);
  }
}
