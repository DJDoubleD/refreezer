import 'package:get_it/get_it.dart';

import 'audio_service.dart';

GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // services
  if (!GetIt.I.isRegistered<AudioPlayerHandler>()) {
    getIt.registerSingleton<AudioPlayerHandler>(await initAudioService());
  }
}
