#import "RNEasyPushNotificationsModule.h"
#import <React/RCTConvert.h>
#import "FirebaseMessaging.h"
#import <Firebase/Firebase.h>

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@import UserNotifications;
#endif
extern NSString *device_id = NULL;
extern NSDictionary *remoteNotification = NULL;

@implementation RNEasyPushNotificationsModule

RCT_EXPORT_MODULE(BlitzNotifications);

+ (id)allocWithZone:(NSZone *)zone {
    static RNEasyPushNotificationsModule *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [super allocWithZone:zone];
    });
    return sharedInstance;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"notificationReceived",@"onNotificationTap"];
}

RCT_EXPORT_METHOD(removeAllDeliveredNotifications) {
    if (@available(iOS 10.0, *)) {
        UNUserNotificationCenter *notificationCenter = [UNUserNotificationCenter currentNotificationCenter];
        if (notificationCenter != nil) {
            [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
        }
    }
}

RCT_EXPORT_METHOD(getLastNotificationData:(RCTResponseSenderBlock)callback)
{
    NSLog(@"notificationReceived getLastNotificationData %@",remoteNotification);
    if(remoteNotification != NULL){
        callback(@[remoteNotification]);
        remoteNotification = NULL;
    }
}

RCT_EXPORT_METHOD(hasPermission:
                  (RCTPromiseResolveBlock) resolve
                  :(RCTPromiseRejectBlock) reject
                  ) {
    if (@available(iOS 10.0, *)) {
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *_Nonnull settings) {

            NSNumber *authorizedStatus = @-1;
            if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined) {
                authorizedStatus = @-1;
            } else if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
                authorizedStatus = @0;
            } else if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                authorizedStatus = @1;
            }

            if (@available(iOS 12.0, *)) {
                if (settings.authorizationStatus == UNAuthorizationStatusProvisional) {
                    authorizedStatus = @2;
                }
            }

            resolve(authorizedStatus);
        }];
    }
}

RCT_EXPORT_METHOD(requestPermission:
                  (NSDictionary *) permissions
                  :(RCTPromiseResolveBlock) resolve
                  :(RCTPromiseRejectBlock) reject
                  ) {
    if (RCTRunningInAppExtension()) {
        //    [RNFBSharedUtils rejectPromiseWithUserInfo:reject userInfo:[@{
        //        @"code": @"unavailable-in-extension",
        //        @"message": @"requestPermission can not be called in App Extensions"} mutableCopy]];
        return;
    }


    if (@available(iOS 10.0, *)) {
        UNAuthorizationOptions options = UNAuthorizationOptionNone;

        if ([permissions[@"alert"] isEqual:@(YES)]) {
            options |= UNAuthorizationOptionAlert;
        }

        if ([permissions[@"badge"] isEqual:@(YES)]) {
            options |= UNAuthorizationOptionBadge;
        }

        if ([permissions[@"sound"] isEqual:@(YES)]) {
            options |= UNAuthorizationOptionSound;
        }

        if ([permissions[@"provisional"] isEqual:@(YES)]) {
            if (@available(iOS 12.0, *)) {
                options |= UNAuthorizationOptionProvisional;
            }
        }

        if ([permissions[@"announcement"] isEqual:@(YES)]) {
            if (@available(iOS 13.0, *)) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
                options |= UNAuthorizationOptionAnnouncement;
#endif
            }
        }

        if ([permissions[@"carPlay"] isEqual:@(YES)]) {
            options |= UNAuthorizationOptionCarPlay;
        }

        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError *_Nullable error) {
            if (error) {
                //        [RNFBSharedUtils rejectPromiseWithNSError:reject error:error];
            } else {
                [self hasPermission:resolve :reject];
            }
        }];
    } else {
        //    [RNFBSharedUtils rejectPromiseWithUserInfo:reject userInfo:[@{
        //        @"code": @"unsupported-platform-version",
        //        @"message": @"requestPermission call failed; minimum supported version requirement not met (iOS 10)."} mutableCopy]];
    }
}

RCT_EXPORT_METHOD(getToken:
                  (NSString *) authorizedEntity
                  :(NSString *) scope
                  :(RCTPromiseResolveBlock) resolve
                  :(RCTPromiseRejectBlock) reject
                  ) {
#if !(TARGET_IPHONE_SIMULATOR)
    if ([UIApplication sharedApplication].isRegisteredForRemoteNotifications == NO) {
        //    [RNFBSharedUtils rejectPromiseWithUserInfo:reject userInfo:(NSMutableDictionary *) @{
        //        @"code": @"unregistered",
        //        @"message": @"You must be registered for remote messages before calling getToken, see messaging().registerDeviceForRemoteMessages().",
        //    }];
        return;
    }
#endif

    FIRApp *firApp = [FIRApp defaultApp];
    FIROptions *firOptions = [firApp options];


    if ([scope isEqualToString:@"FCM"] && [firOptions.GCMSenderID isEqualToString:[FIRApp defaultApp].options.GCMSenderID]) {
        [[FIRInstanceID instanceID] instanceIDWithHandler:^(FIRInstanceIDResult *_Nullable result, NSError *_Nullable error) {
            if (error) {
                //        [RNFBSharedUtils rejectPromiseWithNSError:reject error:error];
            } else {
                resolve(result.token);
            }
        }];
    } else {
        NSDictionary *options = nil;
        if ([FIRMessaging messaging].APNSToken) {
            options = @{@"apns_token": [FIRMessaging messaging].APNSToken};
        }

        [[FIRInstanceID instanceID] tokenWithAuthorizedEntity:firOptions.GCMSenderID scope:scope options:options handler:^(NSString *_Nullable identity, NSError *_Nullable error) {
            if (error) {
                //        [RNFBSharedUtils rejectPromiseWithNSError:reject error:error];
            } else {
                resolve(identity);
            }
        }];
    }
}

RCT_EXPORT_METHOD(registerForToken)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"device_id : %@", device_id);
        if(device_id == NULL){
            if ([FIRApp defaultApp] == nil) {
                [FIRApp configure];
            }
            FIRApp *firApp = [FIRApp defaultApp];
            NSLog(@"firApp : %@", firApp);
            UIApplication *application = UIApplication.sharedApplication;
            [FIRMessaging messaging].delegate = self;

            if (@available(iOS 10.0, *)) {
                if ([UNUserNotificationCenter class] != nil) {
                    // iOS 10 or later
                    // For iOS 10 display notification (sent via APNS)
                    [UNUserNotificationCenter currentNotificationCenter].delegate = self;
                    UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert |
                    UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
                    [[UNUserNotificationCenter currentNotificationCenter]
                     requestAuthorizationWithOptions:authOptions
                     completionHandler:^(BOOL granted, NSError * _Nullable error) {
                        // ...
                    }];
                } else {
                    // iOS 10 notifications aren't available; fall back to iOS 8-9 notifications.
                    UIUserNotificationType allNotificationTypes =
                    (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
                    UIUserNotificationSettings *settings =
                    [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
                    [application registerUserNotificationSettings:settings];
                }
            } else {
                // Fallback on earlier versions
            }

            [application registerForRemoteNotifications];

            [FIRMessaging messaging].delegate = self;

            [[FIRInstanceID instanceID] instanceIDWithHandler:^(FIRInstanceIDResult * _Nullable result,
                                                                NSError * _Nullable error) {
                if (error != nil) {
                    NSLog(@"Error fetching remote instance ID: %@", error);
                } else {
                    NSLog(@"Remote instance ID token: %@", result.token);
                }
            }];

            [FIRMessaging messaging].autoInitEnabled = YES;
        }
    });
}

// [START receive_message]
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)notification {
    remoteNotification = notification;
    NSLog(@"notificationReceived didReceiveRemoteNotification : %@", remoteNotification);
    [self sendEventWithName:@"notificationReceived" body: remoteNotification];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
#if __has_include(<FirebaseAuth/FirebaseAuth.h>)
    if ([[FIRAuth auth] canHandleNotification:userInfo]) {
        completionHandler(UIBackgroundFetchResultNoData);
        return;
    }
#endif

    if (userInfo[@"gcm.message_id"]) {
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
            // TODO add support in a later version for calling completion handler directly from JS when user JS code complete
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (25 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                completionHandler(UIBackgroundFetchResultNewData);
            });

            // TODO investigate later - RN bridge gets invalidated at start when in background and a new bridge created - losing all events
            // TODO   so we just delay sending the event for a few seconds as a workaround
            // TODO   most likely Remote Debugging causing bridge to be invalidated
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self sendEventWithName:@"notificationReceived" body: userInfo];
                completionHandler(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge);
            });
        } else {
            [self sendEventWithName:@"notificationReceived" body: userInfo];
            completionHandler(UIBackgroundFetchResultNoData);
        }
    }
}

// [START ios_10_message_handling]
// Receive displayed notifications for iOS 10 devices.
// Handle incoming notification messages while app is in the foreground.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler  API_AVAILABLE(ios(10.0)){

    NSDictionary *userInfo = notification.request.content.userInfo;

    if (userInfo[@"gcm.message_id"]) {

        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // [[FIRMessaging messaging] appDidReceiveMessage:userInfo];

        // Print message ID.
        [self sendEventWithName:@"notificationReceived" body: userInfo];
        // Print full message.
        NSLog(@"%@", userInfo);

        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
            completionHandler(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge);
        } else if ([UIApplication sharedApplication].applicationState == UIApplicationStateInactive) {
            completionHandler(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge);
        } else {
            completionHandler(UNNotificationPresentationOptionNone);
        }
    }
}

// Handle notification messages after display notification is tapped by the user.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void(^)(void))completionHandler  API_AVAILABLE(ios(10.0)){
    NSDictionary *userInfo = response.notification.request.content.userInfo;
    [self sendEventWithName:@"notificationReceived" body: userInfo];
    // Print full message.
    NSLog(@"%@", userInfo);

    completionHandler();
}

// [END ios_10_message_handling]

// [START refresh_token]
- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken {
    device_id = fcmToken;
    NSLog(@"notificationReceived didReceiveMessage with device_id: %@", device_id);
}
// [END refresh_token]

-(void) setRemoteNotification:(NSDictionary *) notification
{   NSLog(@"setRemoteNotification %@",notification);
    remoteNotification = notification;
    [self sendEventWithName:@"onNotificationTap" body: remoteNotification];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"Unable to register for remote notifications: %@", error);
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"APNs device token retrieved: %@", deviceToken);
}
@end
