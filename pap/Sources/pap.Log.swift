//
// Created by BLACKGENE on 06.06.18.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation

//INFO: It is recommended that inserted into only UI actions.

struct papLog: Loggable {
    private static var kOption:String{ return #function }
    private static var kValue:String{ return #function }

    //common
    static func appSelected(){ log() }
    static func cancelWhileSelecting(){ log() }
    static func cancelWhilePerforming(){ log() }
    static func performFromUser(){ log() }
    static func performWhenPhotoLibraryDidChanged(){ log() }
    static func allTasksAreFinished(){ log() }

    struct charge: Loggable {
        private static var kChargeIdentifier:String{ return #function }

        static func opened(){ log() }
        static func cancelled(){ log() }
        static func openedInWelcomeTutorial(){ log() }
        static func openedInAllPaid(){ log() }
        static func openedInNeedToPay(){ log() }
        static func paid(charge:Charge){
            log(parameters: [
                kChargeIdentifier:String(describing: charge.identifier)
            ])
        }
        static func unpaid(charge:Charge){
            log(parameters: [
                kChargeIdentifier:String(describing: charge.identifier)
            ])
        }

        static func userHasShownInAppPromptRating(){ log() }

        static func restoredStorePayables(){ log() }

        struct scp: Loggable {
            static func activationStarted(){ log() }
            static func activationTimeout(){ log() }

            static func triedToAccess(){ log() }
            static func cancelledToAccess(){ log() }

            static func accessDenied(recordName:String?){ log(parameters:["recordName": recordName ?? "nil"]) }
            static func accessGranted(recordName:String?){ log(parameters:["recordName": recordName ?? "nil"]) }
            static func accessError(){ log() }
        }

        struct ads: Loggable{
            static func offlineModeWarning(){ log() }
            static func offlineModeDenied(){ log() }

            static func movedToSettingsUnableReceivingAds(){ log() }
            static func occurredShowedUnableReceivingAds(){ log() }
        }
    }

    struct app: Loggable {
        // app common
        static func launch(with option: AppLaunchOptions?){
            if let option = option, let identifierToReturn = option.identifierToReturn {
                log(parameters:["identifierToReturn":identifierToReturn])
            }else{
                log()
            }
        }

        static func minimizeAppDockDrawer(){ log() }
        static func maximizeAppDockDrawer(){ log() }

        static func userCalledCameraInApp(){ log() }

        static func userEnablesASB(){ log() }
        static func userDisablesASB(){ log() }

        struct defaults: Loggable {}
    }

    struct error {
        static func recordedError(_ e:Error, parameters:[String:Any]?=nil){
            var paramToCommit = [
                "errorDescription": e.localizedDescription
            ] as [String:Any]

            if let parameters = parameters{
                for o in parameters{
                    paramToCommit[o.key] = o.value
                }
            }

            log(parameters: paramToCommit)
        }
    }
}


private struct LoggableVar {
    static var latestDate = [String:Date]()
}

extension Loggable {
    static func log(_ functionName:String=#function, parameters:[String:Any]?=nil){
        let identifier = createIdentifier(withFunction: functionName)

        let logginDate = Date()
        if let latest = LoggableVar.latestDate[identifier], logginDate.timeIntervalSince(latest) <= 1.0 {
            return
        }
        LoggableVar.latestDate[identifier] = logginDate

        DispatchQueue.global(qos: .background).async {
            guard let app = AppCenter.default.current else{
                return
            }

            var paramToCommit = [
                "appIdentifier": app.info.identifier
            ] as [String:Any]

            if let parameters = parameters{
                for o in parameters{
                    paramToCommit[o.key] = o.value
                }
            }

            papAnalytics.log(name:createIdentifier(withFunction: functionName), parameters: paramToCommit)
        }
    }
}

enum papAnalytics {

    /// Logs an app event.
    /// 1. The event can have up to 25 parameters.
    /// 2. Events with the same name must have the same parameters.
    /// 3. Up to 500 event names are supported.
    /// 4. Using predefined events and/or parameters is recommended for optimal reporting.

    /// @param name The name of the event.
    //NAME --->>
    // 1. Should contain 1 to 40 alphanumeric characters or underscores.
    // 2. The name must start with an alphabetic character.
    // 3. Some event names are reserved. Use AnalyticsPredefinedLogNames.
    // 4. for the list of reserved event names. The "firebase_", "google_", and "ga_" prefixes are reserved and should not be used.
    // 5. Note that event names are case-sensitive
    private static let _errLength = "WL"

    private static func resolveLogName(for name:String) -> String{
        let resolvedName = name
                .replaceIfMatched(withPattern: "^[^A-Za-z0-9]", replace: "")
                .replaceIfMatched(withPattern: "[^\\w]", replace: "_")
                .trunc(maxLength: 40, trailing: _errLength)
//        assert(resolvedName == name, "\"\(name)\" is violated for FB's logging rules: \(zip(resolvedName.characters, name.characters).filter{$0 != $1})")
        return resolvedName
    }

    //PARAM -->>
    /// @param parameters The dictionary of event parameters.
    // 1. Passing nil indicates that the event has no parameters.
    // 2. names can be up to 40 characters long
    // 3. names must start with an alphabetic character and contain only alphanumeric characters and underscores.
    // 4. value type must be Only NSString and NSNumber (signed 64-bit integer and 64-bit floating-point number) parameter types are supported.
    // 5. values, if they are NSString, can be up to 100 characters long.
    // 6. The "firebase_","google_", and "ga_" prefixes are reserved and should not be used for parameter names.
    private static let _errParamValue = "ERR_PV"

    fileprivate static func log(name: String, parameters: [String: Any]?) {
        let name = resolveLogName(for:name)
        var params = [String:Any]()
        for item in parameters ?? [String:Any](){
            let k = resolveLogName(for:item.key)
            if let v = (item.value as? NSString) ?? (item.value as? NSNumber){
                params[k] = v
            }else{
                params[k] = _errParamValue
            }
        }
        print("[i] Logged: ",name, params)
    }

    static let names = AnalyticsPredefinedLogNames()
}

struct AnalyticsPredefinedLogNames {
    var ad_activeview:String { return #function }
    var ad_click:String { return #function }
    var ad_exposure:String { return #function }
    var ad_impression:String { return #function }
    var ad_query:String { return #function }
    var adunit_exposure:String { return #function }
    var app_clear_data:String { return #function }
    var app_remove:String { return #function }
    var app_update:String { return #function }
    var error:String { return #function }
    var first_open:String { return #function }
    var in_app_purchase:String { return #function }
    var notification_dismiss:String { return #function }
    var notification_foreground:String { return #function }
    var notification_open:String { return #function }
    var notification_receive:String { return #function }
    var os_update:String { return #function }
    var screen_view:String { return #function }
    var session_start:String { return #function }
    var user_engagement:String { return #function }
}