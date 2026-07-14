class ApiConfig {
  static const String mode = 'local';
  static const String baseUrl = 'http://localhost:8080/v1';
  static const String model = 'deepseek-r1-distill-qwen-7b';
  static const int localCtxSize = 4096;
  static const int localThreads = 4;
  static const int maxTokens = 1024;
  static const int maxContextRounds = 20;
}
