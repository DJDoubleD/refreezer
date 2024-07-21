import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../utils/cookie_manager.dart';
import '../utils/env.dart';

class DeezerLogin {
  static final Map<String, String> defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36',
    'X-User-IP': '1.1.1.1',
    'x-deezer-client-ip': '1.1.1.1',
    'Accept': '*/*'
  };
  static final cookieManager = CookieManager();

  //Login with email
  static Future<String?> getArlByEmailAndPassword(String email, String password) async {
    cookieManager.reset();
    // Get initial cookies (sid) from empty getUser call
    String url =
        'https://www.deezer.com/ajax/gw-light.php?method=deezer.getUserData&input=3&api_version=1.0&api_token=null';
    cookieManager.updateCookie(await http.get(Uri.parse(url)));
    // Fuck the Bearer Token...
    //cookieManager.updateCookie(await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $accessToken'}));

    // Try to get AccessToken by login with email & password, which sets authentication cookies
    String? accessToken = await _getAccessToken(email, password);
    if (accessToken == null) return '';

    // Get ARL
    Map<String, String> requestheaders = {...defaultHeaders, ...cookieManager.cookieHeader};
    url = 'https://www.deezer.com/ajax/gw-light.php?method=user.getArl&input=3&api_version=1.0&api_token=null';
    http.Response response = await http.get(Uri.parse(url), headers: requestheaders);
    Map<dynamic, dynamic> data = jsonDecode(response.body);
    return data['results'];
  }

  static Future<String?> _getAccessToken(String email, String password) async {
    final clientId = Env.deezerClientId;
    final clientSecret = Env.deezerClientSecret;
    String? accessToken;

    Map<String, String> requestheaders = {...defaultHeaders, ...cookieManager.cookieHeader};
    requestheaders.addAll(cookieManager.cookieHeader);
    final hashedPassword = md5.convert(utf8.encode(password)).toString();
    final hashedParams = md5.convert(utf8.encode('$clientId$email$hashedPassword$clientSecret')).toString();
    final url = Uri.parse(
        'https://connect.deezer.com/oauth/user_auth.php?app_id=$clientId&login=$email&password=$hashedPassword&hash=$hashedParams');

    await http.get(url, headers: requestheaders).then((res) {
      cookieManager.updateCookie(res);
      final responseJson = jsonDecode(res.body);
      if (responseJson.containsKey('access_token')) {
        accessToken = responseJson['access_token'];
      } else if (responseJson.containsKey('error')) {
        throw DeezerLoginException(responseJson['error']['type'], responseJson['error']['message']);
      }
    }).catchError((e) {
      Logger.root.severe('Login Error (E): $e');
      if (e is DeezerLoginException) {
        // Throw the login exception for custom error dialog
        throw e;
      }
      // All other errors will just use general invalid ARL error dialog
      accessToken = null;
    });

    return accessToken;
  }
}

class DeezerLoginException implements Exception {
  final String type;
  final dynamic message;

  DeezerLoginException(this.type, [this.message]);

  @override
  String toString() {
    if (message == null) {
      return 'DeezerLoginException: $type';
    } else {
      return 'DeezerLoginException: $type\nCaused by: $message';
    }
  }
}
