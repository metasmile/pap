//
//  AppDelegate.swift
//  batch
//
//  Created by Hyojin Mo on 2017. 7. 11..
//  Copyright © 2017년 Codeful. All rights reserved.
//

import UIKit


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    let spotlightSearchAppDelegate = SpotlightSearchAppDelegate()
    let shortcutItemAppDelegate = ShortcutItemAppDelegate()
    let intentsAppDelegate = IntentsAppDelegate()

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if DEBUG
        NSSetUncaughtExceptionHandler { (exception) in
            print(String(describing: exception))
            for s in exception.callStackSymbols{
                print(s)
            }
        }
        #endif

        Defaults.shared.initVersionInfo()
        print("Version: ", Bundle.main.shortVersionString ?? "No version info")
        print("Version Distance: ",Defaults.shared.shortVersionDistance ?? "nil")
        print("Version Description: ",Defaults.shared.shortVersionDescription)

        let selfAny:AnyObject = self
        (selfAny as? AppDelegateExternalDelegate)?.willFinishLaunching()

        return false
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        DispatchQueue.global(qos: .background).async{
            self.spotlightSearchAppDelegate.indexDefaultSearchableItems()

            DispatchQueue.main.async{
                self.spotlightSearchAppDelegate.application(application, didFinishLaunchingWithOptions: launchOptions)
                self.shortcutItemAppDelegate.application(application, didFinishLaunchingWithOptions: launchOptions)
                self.intentsAppDelegate.application(application, didFinishLaunchingWithOptions: launchOptions)
            }
        }

#if DEBUG
        //INFO: Reset all receipt for testing
//        for c in AppCenter.charge.getChargesHasReceipt(){
//            if let r = AppCenter.charge.bank.getReceipt(for: c){
//                ChargeableReceipt.reserveShouldFailVerification(uuid: r.uuid)
//            }
//        }
//        AppCenter.charge.synchronize()

//        //INFO: Unlock all for app testing.
//        let paymentsToTest = [
//            AllTimeAllAppsPayment.self
//        ]
//        for p in paymentsToTest{
//            AppCenter.charge.pay(for: p, skipTransaction: true)
//        }
#endif

        let anySelf:AnyObject = self
        (anySelf as? AppDelegateExternalDelegate)?.didFinishLaunching()

        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        spotlightSearchAppDelegate.application(application, userActivity: userActivity, restorationHandler: restorationHandler)
        intentsAppDelegate.application(application, userActivity: userActivity, restorationHandler: restorationHandler)
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        FileCollectableURL.discardAll()
        FileManager.default.clearTemporaryDirectory()
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

extension AppDelegate {
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async {
            self.shortcutItemAppDelegate.application(application, performActionFor: shortcutItem, completionHandler: completionHandler)
        }
    }
}
