import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  
  /// Requests all necessary permissions at once.
  /// The OS will handle queuing the dialogs sequentially.
  Future<void> requestAllPermissions() async {
    
    // 1. Define the list of permissions we need
    List<Permission> permissions = [
      Permission.notification,
      Permission.locationWhenInUse,
      Permission.microphone,
    ];

    // 2. Add Storage/Photos based on Platform
    if (Platform.isAndroid) {
      // On Android 13+, 'photos' handles READ_MEDIA_IMAGES
      // On Android 12-, 'storage' handles READ_EXTERNAL_STORAGE
      // We add both; the plugin checks the SDK version and asks for the correct one.
      permissions.add(Permission.photos);
      permissions.add(Permission.storage);
    } 

    // 3. Request the entire list at once
    // This prevents the "only one dialog" bug by handing the full list to the OS.
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    // Optional: Log results to see what was granted
    statuses.forEach((permission, status) {
      print('$permission: $status');
    });
  }
}