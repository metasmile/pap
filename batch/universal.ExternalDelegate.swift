//
// Created by BLACKGENE on 2018-11-14.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation


extension AppCenter{

    static var defaultConfigWholeUniversal: AppManagerConfig {
        let defaultAppCollection:[App.Type] = [
            TransformApp.self
            , FiltersApp.self
            , ConverterApp.self
            , ArtistApp.self
            , GIFMakerApp.self
            , RevertApp.self
            , CameraApp.self
            , AutoEditorApp.self
            , ExifGhostApp.self
            , SiriApp.self
            , ClipboardApp.self
            , ResizerApp.self
            , AdjustmentsApp.self
            , DepthEditorApp.self
            , RawEditorApp.self
            , CurveEditorApp.self
            , MergerApp.self

        ].sorted { (appType1: App.Type, appType2: App.Type) -> Bool in

            if appType1.info.phase.rawValue > appType2.info.phase.rawValue{
                return true
            }

            if papDefaults.app.countPerformed(app: appType1) > papDefaults.app.countPerformed(app: appType2){
                return true
            }

            if appType1 is SApp.Type && appType2 is BApp.Type {
                return true
            }

            if appType1 is AVCaptureDeviceApp.Type == false && appType2 is AVCaptureDeviceApp.Type{
                return true
            }

            return false
        }

        print("[i] App Internal Collection: ",defaultAppCollection)

        #if DEBUG
        for app in defaultAppCollection{
            print(app.info.displayName)
            print(app.info.description ?? "")
//            print(app.info.keywords?.joined(separator: ",") ?? "")
        }
        #endif

        return AppManagerConfig(
                appCollection: defaultAppCollection
                , initialApp: TransformApp.self
                , taskManager: nil
        )
    }

}
