class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
}

class StorageKeys {
  static const authToken = 'auth_token';
  static const userId = 'user_id';
  static const username = 'username';
  static const onboardingCompleted = 'onboarding_completed';
}
