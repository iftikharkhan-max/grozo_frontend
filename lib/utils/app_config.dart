class AppConfig {
  // Final exposed URLs for your application to consume
  // 1. Paste your clean Render URL here (with /api at the end)
  static String get baseUrl => 'https://grozo-backend-sdfc.onrender.com/api';

  // 2. Point your WebSockets to Render as well (Use wss:// and remove /api)
  static String get wsUrl => 'wss://grozo-backend-sdfc.onrender.com';
}