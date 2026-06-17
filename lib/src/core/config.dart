class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.33:8080',
  );
}

class StorageKeys {
  static const authToken = 'auth_token';
  static const userId = 'user_id';
  static const username = 'username';
  static const onboardingCompleted = 'onboarding_completed';
}
