//----------------------------------------------------------------
//  Copyright (c) Microsoft Corporation. All rights reserved.
//----------------------------------------------------------------

#import <objc/runtime.h>

#import "MSNotificationHub.h"
#import "MSUserNotificationCenterDelegate.h"

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

// Singleton
static MSUserNotificationCenterDelegate *sharedInstance = nil;
static IMP originalSetDelegateImp = nil;
static dispatch_once_t onceToken;

@implementation MSUserNotificationCenterDelegate

@synthesize enabled;

+ (void)load {
    if (@available(iOS 10.0, tvOS 10.0, watchOS 3.0, macOS 10.14, *)) {
        [[MSUserNotificationCenterDelegate sharedInstance] setEnabledFromPlistForKey:@"NHUserNotificationCenterDelegateForwarderEnabled"];
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [[MSUserNotificationCenterDelegate sharedInstance] swizzleSetDelegate];
        });
    }
}

- (instancetype)init {
    self = [super init];

    return self;
}

+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
      if (sharedInstance == nil) {
          sharedInstance = [self new];
      }
    });
    return sharedInstance;
}

- (void)custom_setDelegate:(id<UNUserNotificationCenterDelegate>)delegate  API_AVAILABLE(ios(10.0), tvos(10.0), watchos(3.0), macos(10.14)) {

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      [[MSUserNotificationCenterDelegate sharedInstance] swizzleImplForMethod:@selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)
                                                                  inClass:[delegate class]];
      [[MSUserNotificationCenterDelegate sharedInstance] swizzleImplForMethod:@selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)
                                                                  inClass:[delegate class]];
    });

    ((void (*)(id, SEL, id<UNUserNotificationCenterDelegate>))originalSetDelegateImp)(self, _cmd, delegate);
}

- (void)swizzleSetDelegate API_AVAILABLE(ios(10.0), tvos(10.0), watchos(3.0), macos(10.14)) {
    SEL setDelegateSelector = @selector(setDelegate:);
    Class appClass = [UNUserNotificationCenter class];
    originalSetDelegateImp = class_getMethodImplementation(appClass, setDelegateSelector);
    [[MSUserNotificationCenterDelegate sharedInstance] swizzleImplForMethod:setDelegateSelector inClass:appClass];
}

- (void)swizzleImplForMethod:(SEL)originalSelector inClass:(Class)class API_AVAILABLE(ios(10.0), tvos(10.0), watchos(3.0)) {
    if (self.enabled) {
        Class swizzledClass = [MSUserNotificationCenterDelegate class];
        Method originalMethod = class_getInstanceMethod(class, originalSelector);

        SEL swizzledSelector = NSSelectorFromString([@"custom_" stringByAppendingString:NSStringFromSelector(originalSelector)]);
        Method swizzledMethod = class_getInstanceMethod(swizzledClass, swizzledSelector);

        BOOL didAddMethod =
            class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));

        if (didAddMethod && originalMethod) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    }
}

- (void)setEnabledFromPlistForKey:(NSString *)plistKey {
    NSNumber *forwarderEnabledNum = [NSBundle.mainBundle objectForInfoDictionaryKey:plistKey];
    BOOL forwarderEnabled = forwarderEnabledNum ? [forwarderEnabledNum boolValue] : YES;
    self.enabled = forwarderEnabled;
    if (self.enabled) {
        NSLog(@"Delegate forwarder for info.plist key '%@' enabled. It may use swizzling.", plistKey);
    } else {
        NSLog(@"Delegate forwarder for info.plist key '%@' disabled. It won't use swizzling.", plistKey);
    }
}

- (void)custom_userNotificationCenter:(UNUserNotificationCenter *)center
          willPresentNotification:(UNNotification *)notification
                withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler API_AVAILABLE(ios(10.0), tvos(10.0), watchos(3.0), macos(10.14)) {
    [MSNotificationHub didReceiveRemoteNotification:notification.request.content.userInfo];
    completionHandler(UNNotificationPresentationOptionNone);
}

- (void)custom_userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler API_AVAILABLE(ios(10.0), tvos(10.0), watchos(3.0), macos(10.14)) {
    [MSNotificationHub didReceiveRemoteNotification:response.notification.request.content.userInfo];
    completionHandler();
}

@end