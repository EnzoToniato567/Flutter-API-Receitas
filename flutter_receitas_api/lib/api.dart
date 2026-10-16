class Api {
  static const String baseUrl = 'https://backend-receitas-flutter.vercel.app/';
  static String getEndPoint(String endpoint) {
    return '$baseUrl$endpoint';
  }
}
