import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class FileUtils {
  // Just in case manageExternalStorage should be needed
  static Future<bool> checkExternalStoragePermissions(
      Future<bool> Function() showDialogCallback) async {
    PermissionStatus status = PermissionStatus.denied;
    bool permissionGranted = false;
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    final AndroidDeviceInfo info = await deviceInfoPlugin.androidInfo;

    // Starting at compileSdkVersion 30, storage permissions changed
    // MANAGE_EXTERNAL_STORAGE was introduced in API 30, READ_EXTERNAL_STORAGE & WRITE_EXTERNAL_STORAGE deprecated
    // READ_EXTERNAL_STORAGE & WRITE_EXTERNAL_STORAGE where removed in API 33
    // Instead, MANAGE_EXTERNAL_STORAGE is required for any access outside apps own storage.
    if ((info.version.sdkInt) < 30) {
      status = await Permission.storage.request();
    } else {
      status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        if (await showDialogCallback()) {
          status = await Permission.manageExternalStorage.request();
        } else {
          return false;
        }
      }
    }

    if (status.isGranted || status.isLimited) {
      permissionGranted = true;
    } else if (status.isPermanentlyDenied && await showDialogCallback()) {
      permissionGranted = await openAppSettings();
    }

    return permissionGranted;
  }

  static Future<bool> checkStoragePermission() async {
    bool permissionGranted = false;
    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    AndroidDeviceInfo android = await deviceInfoPlugin.androidInfo;
    if (android.version.sdkInt < 30) {
      if (await Permission.storage.request().isGranted) {
        permissionGranted = true;
      } else if (await Permission.storage.request().isPermanentlyDenied) {
        permissionGranted = await openAppSettings();
      } else if (await Permission.storage.request().isDenied) {
        permissionGranted = false;
      }
    } else {
      /* In case we want to access shared audio from other apps
      if (await Permission.audio.request().isGranted) {
        permissionGranted = true;
      } else if (await Permission.audio.request().isPermanentlyDenied) {
        await openAppSettings();
      } else if (await Permission.audio.request().isDenied) {
        permissionGranted = false;
      }*/
      // From sdk version 33 (android 13) and up, storage permissions are implicitly granted for own files
      permissionGranted = true;
    }
    return permissionGranted;
  }
}
