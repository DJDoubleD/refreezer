import 'package:http/http.dart' as http;

class CookieManager {
  Map<String, String> cookieHeader = {};
  Map<String, String> cookies = {};

  void reset() {
    cookieHeader = {};
    cookies = {};
  }

  void updateCookie(http.Response response) {
    Map<String, List<String>> rawCookies = response.headersSplitValues;
    List<String>? setCookies = rawCookies['set-cookie'];

    if (setCookies?.isEmpty ?? true) return;

    for (String setCookie in setCookies!) {
      var cookies = setCookie.split(';');

      for (var cookie in cookies) {
        _setCookie(cookie);
      }
    }

    cookieHeader['cookie'] = _generateCookieHeader();
  }

  void _setCookie(String rawCookie) {
    if (rawCookie.isNotEmpty) {
      int idx = rawCookie.indexOf('=');
      if (idx >= 0) {
        var key = rawCookie.substring(0, idx).trim();
        var value = rawCookie.substring(idx + 1).trim();
        if (key == 'path' || key == 'expires' || key == 'domain' || key == 'sameSite') return;
        cookies[key] = value;
      }
    }
  }

  String _generateCookieHeader() {
    String cookie = '';

    for (var key in cookies.keys) {
      if (cookie.isNotEmpty) cookie += ';';
      cookie += key + '=' + cookies[key]!;
    }

    return cookie;
  }
}
