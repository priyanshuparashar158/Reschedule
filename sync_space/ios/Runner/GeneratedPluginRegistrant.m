//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<flutter_background_service_ios/FlutterBackgroundServicePlugin.h>)
#import <flutter_background_service_ios/FlutterBackgroundServicePlugin.h>
#else
@import flutter_background_service_ios;
#endif

#if __has_include(<flutter_local_notifications/FlutterLocalNotificationsPlugin.h>)
#import <flutter_local_notifications/FlutterLocalNotificationsPlugin.h>
#else
@import flutter_local_notifications;
#endif

#if __has_include(<permission_handler_apple/PermissionHandlerPlugin.h>)
#import <permission_handler_apple/PermissionHandlerPlugin.h>
#else
@import permission_handler_apple;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [FlutterBackgroundServicePlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterBackgroundServicePlugin"]];
  [FlutterLocalNotificationsPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterLocalNotificationsPlugin"]];
  [PermissionHandlerPlugin registerWithRegistrar:[registry registrarForPlugin:@"PermissionHandlerPlugin"]];
}

@end
