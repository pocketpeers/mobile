class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.33:8080', // home
    //defaultValue: 'http://172.20.10.8:8080', // hotspot
    //defaultValue: 'http://192.168.1.179:8080', // office
    //defaultValue: 'http://10.11.136.82:8080', // upc
    //defaultValue: 'https://pocketpeers.ddns.net' //prod
  );
}

class StorageKeys {
  static const authToken = 'auth_token';
  static const userId = 'user_id';
  static const username = 'username';
  static const onboardingCompleted = 'onboarding_completed';
}
