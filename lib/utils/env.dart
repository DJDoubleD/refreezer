// lib/env/env.dart
import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: 'lib/.env')
abstract class Env {
  // Deezer
  @EnviedField(varName: 'deezerClientId', obfuscate: true)
  static final String deezerClientId = _Env.deezerClientId;
  @EnviedField(varName: 'deezerClientSecret', obfuscate: true)
  static final String deezerClientSecret = _Env.deezerClientSecret;

  // LastFM
  @EnviedField(varName: 'lastFmApiKey', obfuscate: true)
  static final String lastFmApiKey = _Env.lastFmApiKey;
  @EnviedField(varName: 'lastFmApiSecret', obfuscate: true)
  static final String lastFmApiSecret = _Env.lastFmApiSecret;
}
