//
// Created by BLACKGENE on 24/01/2018.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation
import QuartzCore
import Photos
import UIKit

public class TransformAppConfigValue: NSObject, PropertyWatchable, AppConfigAdoptableValuable {
    @objc dynamic
    public var transform: ImageEditStateValue?

    public func adoptValues(fromOther: AppConfigValuable) {
        if let other = fromOther as? TransformAppConfigValue, let transform = other.transform{
            self.transform = transform
        }
    }
}

public class TransformApp: NSObject, BApp, PropertyWatchable
        , ConfigurableApp, _ConfigurableApp, EditableApp, AppDockApp, PHAssetFinalizableApp
        , PhotoPickerViewControllerAppearanceDelegatableApp, PhotoPickerCollectionViewDelegatableApp
        , PhotoEditViewControllerDelegatableApp {

    public static let taskType: AppTaskable.Type = _TransfromAppTask.self

    public static let paramType: AppTaskParamable.Type = _TransformAppAsset.self

    public static var defaultConfigValue: AppConfigValuable {
        let config = TransformAppConfigValue()
        return config
    }

    @objc dynamic
    public private(set) lazy var config: TransformAppConfigValue? = type(of:self).defaultConfigValue as? TransformAppConfigValue

    public private(set) lazy var content: AppDockContent? = TransformAppDockContent()
    public private(set) lazy var editViewDockContent: AppDockContent? = TransformAppDockContent()

    public static let info = AppInfo(
            identifier: "com.stells.batch.transform"
            , version: "1.0"
            , phase: .release
            , appType: TransformApp.self
            , displayName: "Rotation".localized.localizedCapitalized
            , description: "This straightforward but large-scale batch image transform tool lets you quickly rotate and flip a lot of media files including Live Photos. There is no limit to the number of photos to edit them.".localized
            , keywords: ["Transformation", "Rotation","Flip","Vertical","Editor"]
            , icon: AppIcon(source: R.image.transformBAppIcon.name, style: .original)
            , themeColor: UIColor(red:0.75, green:0.31, blue:0.8, alpha:1)
                        , policy: AppPolicy.default
            , minOSVersion: nil
    )

    required public override init(){
        super.init()
    }

    public private(set) var doneButtonTitle: String? = "Rotate".localized

    public static var fixedContentLayout: Bool {
        return true
    }

    public func setConfigValues<T: AppConfigValuable>(_ config:T){
        self.config?.adoptValues(fromOther: config)
    }

    public var finalizingActions: [PHAssetFinalizingAction] {
        return [.actions]
    }

    public func shouldSelect(item: AppAsset) -> Bool {
        return item.asset.imageType != .animatedGIF
    }

    public func selectEditState(value: ImageEditStateValue?, in content: AppDockContent?) {}
}

fileprivate class TransformAppDockContent: NSObject, AppDockContent {
    private var config: TransformAppConfigValue? {
        return AppCenter.default.currentInstanceAs(TransformApp.self)?.config
    }

    lazy var items = [
        AppUICollectionView.CollectionItem(title: nil, image: R.image.flipVertical()?.withRenderingMode(.alwaysTemplate), action: {
            self.config?.transform = VerticalFlipTransformItem()
        }),
        AppUICollectionView.CollectionItem(title: nil, image: R.image.flipHorizontal()?.withRenderingMode(.alwaysTemplate), action: {
            self.config?.transform = HorizontalFlipTransformItem()
        }),
        AppUICollectionView.CollectionItem(title: nil, image: R.image.rotateLeft()?.withRenderingMode(.alwaysTemplate), action: {
            self.config?.transform = RotationTransformItem(degrees: -90)
        }),
        AppUICollectionView.CollectionItem(title: nil, image: R.image.rotateRight()?.withRenderingMode(.alwaysTemplate), action: {
            self.config?.transform = RotationTransformItem(degrees: 90)
        })
    ]

    lazy var view: UIView = {
        let view = AppUICollectionStackView(items: items)
        view.cellAppearance.size = CGSize(width: 44, height: 44)
        view.cellAppearance.spacing = 2
        view.cellAppearance.imageInsets = UIEdgeInsets(top: 8, left: 10, bottom: 10, right: 10)
        return view
    }()

    var preferences: AppDockContentPreferable? {
        var preferences = AppDockContentPreferences()
        preferences.preferredHeight = 52
        return preferences
    }

    var contentScrollable: AppDockContentScrollable? {
        guard let view = view as? AppUICollectionStackView else { return nil }
        return AppDockScrollableContent(view.collectionView)
    }

    func willSetContentView(_ view: UIView, dock: AppDock) {

    }

    func didSetContentView(_ view:UIView, dock:AppDock) {
        view.tintColor = TransformApp.info.themeColor ?? view.colorTheme.tintColor
    }
}

//TODO: retrictful conforms param type
private class _TransfromAppTask: AppTaskPrototype, AppTaskable {

    public typealias ParamType = _TransformAppAsset
    public typealias ResultType = PHAssetResultItem

    public func cancel(_ param: AppTaskParamable, _ async: AsyncWaitSignalable){

        (param as? _TransformAppAsset)?.cancelAllRequestIDs()
    }

    public func perform(_ param: AppTaskParamable, _ async: AsyncWaitSignalable) throws -> AppTaskResultable? {
        assert(param is _TransformAppAsset, "TaskParamable type of this app is \(_TransformAppAsset.self)")
        guard let _param = param as? _TransformAppAsset else{
            throw AppTaskError.invalidParam
        }
        return try self._perform(_param, async)
    }

    private func _perform(_ assetItem: _TransformAppAsset, _ async: AsyncWaitSignalable) throws -> PHAssetResultItem?  {
        var result: PHAssetResultItem?

        async.begin()

        DispatchQueue(label: "com.stells.internal."+fileName(), qos: .utility).async {
            assetItem.runEditing({ (progress) in
                AppAssetItemProgressNotification.update(item: assetItem, progress: progress)
            }) { (asset, editingResultItems, contentEditingOutput) in
                if let asset = asset, let contentEditingOutput = contentEditingOutput {
                    contentEditingOutput.adjustmentData = PAPAdjustmentData.createAdjustmentData(for: TransformApp.self, editInfo: ["transform": NSCoder.string(for: assetItem.editState.transform)], from: asset)

                    result = PHAssetResultItem(
                            asset: assetItem,
                            editingResultItems: editingResultItems,
                            contentEditingOutput: contentEditingOutput)
                }
                async.end()
            }
        }

        async.waitUntilEnd()
        return result


    }
}

import Intents

extension TransformApp:UIApplicationDelegateLaunchableApp{

}
