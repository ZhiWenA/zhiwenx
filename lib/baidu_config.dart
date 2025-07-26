class BaiduConfig {
  static const String clientId = 'CdCKdNJApHUvVwRJpjvn9AxH';
  static const String clientSecret = 'pwllRwVqTILxqnImfHbQ7MzklLgxSqmU';
  static const String tokenUrl = 'https://aip.baidubce.com/oauth/2.0/token';
  static const String imageUnderstandingUrl = 'https://aip.baidubce.com/rest/2.0/image-classify/v1/image-understanding';
  
  // 访问令牌缓存
  static String? _accessToken;
  static DateTime? _tokenExpireTime;
  
  static String? get accessToken => _accessToken;
  static DateTime? get tokenExpireTime => _tokenExpireTime;
  
  static void setAccessToken(String token, int expiresIn) {
    _accessToken = token;
    _tokenExpireTime = DateTime.now().add(Duration(seconds: expiresIn));
  }
  
  static bool get isTokenValid {
    if (_accessToken == null || _tokenExpireTime == null) {
      return false;
    }
    return DateTime.now().isBefore(_tokenExpireTime!.subtract(Duration(minutes: 5)));
  }
}
