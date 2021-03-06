//
//  SGAppDelegate.m
//  SpotAndGo
//
//  Created by Truman, Christopher on 4/28/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SGAppDelegate.h"
#import "SVHTTPClient.h"
#import "SGConstants.h"
#import "OpenUDID.h"


@implementation SGAppDelegate
// Dispatch period in seconds
static const NSInteger kGANDispatchPeriodSec = 10;

static NSString* const kAnalyticsAccountId = @"UA-31324397-1";

@synthesize window = _window;
/*
 My Apps Custom uncaught exception catcher, we do special stuff here, and TestFlight takes care of the rest
 **/
void HandleExceptions(NSException *exception) {
  NSLog(@"This is where we save the application data during a exception");
  // Save application data on crash
}
/*
 My Apps Custom signal catcher, we do special stuff here, and TestFlight takes care of the rest
 **/
void SignalHandler(int sig) {
  NSLog(@"This is where we save the application data during a signal");
  // Save application data on crash
}

-(BOOL)application:(UIApplication *)application 
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions { 

  // installs HandleExceptions as the Uncaught Exception Handler
  NSSetUncaughtExceptionHandler(&HandleExceptions);
  // create the signal action structure 
  struct sigaction newSignalAction;
  // initialize the signal action structure
  memset(&newSignalAction, 0, sizeof(newSignalAction));
  // set SignalHandler as the handler in the signal action structure
  newSignalAction.sa_handler = &SignalHandler;
  // set SignalHandler as the handlers for SIGABRT, SIGILL and SIGBUS
  sigaction(SIGABRT, &newSignalAction, NULL);
  sigaction(SIGILL, &newSignalAction, NULL);
  sigaction(SIGBUS, &newSignalAction, NULL);
    [[SVHTTPClient sharedClient] setBasePath:kBaseURL];
  // start of your application:didFinishLaunchingWithOptions 
  // ...
  // The rest of your application:didFinishLaunchingWithOptions method
  [MixpanelAPI sharedAPIWithToken:@"8ed4b958846a5a4f2336e6ed19687a20"];
  [[MixpanelAPI sharedAPI] identifyUser:[OpenUDID value]];
  [FlurryAnalytics startSession:@"FJX9G2A6P8VGCM5736M7"];
  [FlurryAnalytics setUserID:[OpenUDID value]];
  
  [TestFlight takeOff:@"30d92a896df4ab4b4873886ea58f8b06_NzE0NzIyMDEyLTAzLTE0IDEzOjQ0OjU4Ljk3MDAxOQ"];

  [TestFlight setDeviceIdentifier:[OpenUDID value]];
  [[MixpanelAPI sharedAPI] track:@"Launched"];
  [[GANTracker sharedTracker] startTrackerWithAccountID:kAnalyticsAccountId
                                         dispatchPeriod:kGANDispatchPeriodSec
                                               delegate:nil];
  NSError *error;
  
  if (![[GANTracker sharedTracker] trackEvent:@"Application iOS"
                                       action:@"Launched iOS"
                                        label:@"Example iOS"
                                        value:99
                                    withError:&error]) {
    NSLog(@"error in trackEvent");
  }
  
  if (![[GANTracker sharedTracker] trackPageview:@"/app_entry_point"
                                       withError:&error]) {
    NSLog(@"error in trackPageview");
  }

    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
  // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
  // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  
  NSError *error;
  if (![[GANTracker sharedTracker] trackEvent:@"Application iOS"
                                      action:@"Background iOS"
                                       label:@"Example iOS"
                                       value:99
                                   withError:&error]) {
  NSLog(@"error in trackEvent");
  }
  [[MixpanelAPI sharedAPI] track:@"Sent to Background"];
  // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
  // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  NSError *error;
  if (![[GANTracker sharedTracker] trackEvent:@"Application iOS"
                                       action:@"Foreground iOS"
                                        label:@"Example iOS"
                                        value:99
                                    withError:&error]) {
    NSLog(@"error in trackEvent");
  }
  [[MixpanelAPI sharedAPI] track:@"Brought to foreground"];

  // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
  // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
  NSError *error;
  if (![[GANTracker sharedTracker] trackEvent:@"Application iOS"
                                       action:@"Quit iOS"
                                        label:@"Example iOS"
                                        value:99
                                    withError:&error]) {
    NSLog(@"error in trackEvent");
  }
  // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}



@end
