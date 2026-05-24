class DictionaryResult {
  final String translation;
  final String? error;

  bool get isSuccess => translation.isNotEmpty;
  bool get isNetworkError => error == 'network';
  bool get isNotFound => error == 'not_found';
  bool get isTimeout => error == 'timeout';
  bool get isApiError => error == 'api';

  DictionaryResult._({required this.translation, this.error});

  factory DictionaryResult.success(String translation) =>
      DictionaryResult._(translation: translation);

  factory DictionaryResult.networkError() =>
      DictionaryResult._(translation: '', error: 'network');

  factory DictionaryResult.timeout() =>
      DictionaryResult._(translation: '', error: 'timeout');

  factory DictionaryResult.notFound() =>
      DictionaryResult._(translation: '', error: 'not_found');

  factory DictionaryResult.apiError() =>
      DictionaryResult._(translation: '', error: 'api');

  String get displayText {
    if (translation.isNotEmpty) return translation;
    switch (error) {
      case 'network':
        return '网络错误，请检查网络连接';
      case 'timeout':
        return '查询超时，请稍后重试';
      case 'api':
        return 'API 返回异常';
      case 'not_found':
      default:
        return '未找到释义';
    }
  }
}