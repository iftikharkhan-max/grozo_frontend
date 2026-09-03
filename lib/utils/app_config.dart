class AppConfig {
  // Final exposed URLs for your application to consume
  // 1. Paste your clean Render URL here (without /api)
  static String get rootUrl => 'https://grozo-backend-sdfc.onrender.com';

  static String get baseUrl => '$rootUrl/api';

  // 2. Point your WebSockets to Render as well (Use wss:// and remove /api)
  static String get wsUrl => 'wss://grozo-backend-sdfc.onrender.com';
}
