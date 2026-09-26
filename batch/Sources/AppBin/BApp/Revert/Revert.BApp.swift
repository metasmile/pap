//
// Created by BLACKGENE on 20/02/2018.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation
import UIKit
import Photos

private typealias RevertAppParam = AppAsset
private struct RevertAppResult: AppTaskResultable {
    fileprivate let asset:PHAsset
    fileprivate let isAdjusted:Bool
}


private protocol RevertAppDefaults: AppDefaults{
    var autoSelect: Bool {get set}
}

extension Defaults: RevertAppDefaults {
    fileprivate var autoSelect: Bool {
        set{ set(newValue); }
        get{ return get(or: true) }
    }
}

public class RevertApp: NSObject, PropertyWatchable, BApp
        , AppDockApp
        , FinalizableApp
        , PhotoPickerViewControllerAppearanceDelegatableApp
        , PhotoPickerCollectionViewDelegatableApp
        , PreheatableApp {
    public static let taskType: AppTaskable.Type = _RevertAppTask.self

    public static let paramType: AppTaskParamable.Type = RevertAppParam.self

    public static let info = AppInfo(
            identifier: "com.stells.batch.revert"
            , version: "1.0"
            , phase: .release
            , appType: RevertApp.self
            , displayName: "Restorer".localized.localizedCapitalized
            , description: "Restorer allows restoring a bunch amount of edited photos to the original one quickly. Furthermore, it helps you with the automatic selection!".localized
            , keywords: ["Restore","Repair","Revert","recovery", "Restorer"]
            , icon: AppIcon(source: R.image.revertBAppIcon.name, style: .original)
            , themeColor: UIColor.lightGray, policy: AppPolicy.default
            , minOSVersion: nil
    )

    public private(set) lazy var content: AppDockContent? = RevertAppDockContent()

    private let appDefaults = RevertApp.defaults as! RevertAppDefaults

    @objc dynamic
    public fileprivate(set) lazy var autoSelect: Bool = appDefaults.autoSelect

    required public override init(){
        super.init()
    }

    public func shouldSelect(item: AppAsset) -> Bool {
        return true
    }

    public func performPreheating(item: PHAssetParamable,  _ async: AsyncWaitSignalable)  -> PreheatingFinishAction? {
        return appDefaults.autoSelect && item.asset.isAdjusted == true ? UICollectionViewPreheatableAppFinishAction.selectItem : nil
    }

    public func finalize(result: [AppTaskRespondable], _ asyncSignal: AsyncWaitSignalable) -> [AppTaskRespondable] {
        let adjustedAssets = result.compactMap { r -> PHAsset? in
            let result = r.result as? RevertAppResult
            return result?.isAdjusted == true ? result?.asset : nil
        }

        guard adjustedAssets.count > 0 else {

            asyncSignal.begin()
            DispatchQueue.main.async {
                UIAlertController.alert("Cannot revert. All selected items have not edited.".localized, completion:{ _ in
                    asyncSignal.end()
                })
            }
            asyncSignal.waitUntilEnd()

            return result
        }

        asyncSignal.begin()

        PHPhotoLibrary.shared().performChanges({
            for asset in adjustedAssets {
                PHAssetChangeRequest(for: asset).revertAssetContentToOriginal()
            }
        }, completionHandler: { success, error in
            if success {

            }else{
                print("[!] Can't revert asset: \(String(describing: error))")
            }
            asyncSignal.end()
        })

        asyncSignal.waitUntilEnd()
        return result
    }

    public var titleWillBegin: String? {
        return "Starting to check edited photos...".localized
    }

    public var titleWillFinalize: String? {
        return "Reverting Photos...".localized
    }

    public var doneButtonTitle: String? {
        return "Revert".localized
    }
}

private class _RevertAppTask: AppTaskPrototype, AppTaskable {
    public func cancel(_ param: AppTaskParamable, _ async: AsyncWaitSignalable){}

    public func perform(_ param: AppTaskParamable, _ async: AsyncWaitSignalable) throws -> AppTaskResultable? {
        assert(param is RevertAppParam, "TaskParamable type of this app is \(RevertAppParam.self)")
        guard let _param = param as? RevertAppParam else{
            throw AppTaskError.invalidParam
        }
        return try self._perform(_param, async)
    }
    
    private func _perform(_ revertParam: RevertAppParam, _ async: AsyncWaitSignalable) throws -> RevertAppResult?  {
        guard revertParam.asset.isAdjusted else { return RevertAppResult(asset: revertParam.asset, isAdjusted: revertParam.asset.isAdjusted) }
        
        async.begin()
        
        DispatchQueue(label: "com.stells.internal."+fileName(), qos: .utility).async {
            //INFO: prepare original version of asset
            // it may get original version from icloud to local
            PHImageManager.default().touchOriginalVersion(for: revertParam.asset, completion: {
                async.end()
            })
        }
        
        async.waitUntilEnd()
        return RevertAppResult(asset: revertParam.asset, isAdjusted: revertParam.asset.isAdjusted)
    }
}


/*
RevertAppDockContent
*/

fileprivate class RevertAppDockContent: NSObject, PropertyWatchable, AppDockContent, UITableViewDelegate, UITableViewDataSource{
    private lazy var defaults = RevertApp.defaults as! RevertAppDefaults

    private let primaryColor = RevertApp.info.themeColor

    lazy var view: UIView = UITableView()
    
    var contentScrollable: AppDockContentScrollable? {
        guard let scrollView = view as? UITableView else { return nil }
        return AppDockScrollableContent(scrollView)
    }

    var preferences: AppDockContentPreferable? {
        guard let tableView = view as? UITableView else{
            return nil
        }
        var preferences = AppDockContentPreferences()
        preferences.preferredHeight = tableView.rowHeight * CGFloat(1)
        return preferences
    }

    func willSetContentView(_ view: UIView, dock: AppDock) {
        if let view = view as? UITableView{
            view.dataSource = self
            view.delegate = self
            view.rowHeight = 52
            view.allowsSelection = false
            view.register(Cell.self, forCellReuseIdentifier: RevertApp.info.identifier)
//            view.backgroundColor = UIColor(red: 31 / 255.0, green: 31 / 255.0, blue: 31 / 255.0, alpha: 1)
            view.tintColor = self.primaryColor
//            view.separatorInset.left = view.rowHeight
        }
    }

    func didSetContentView(_ view:UIView, dock:AppDock) {
        if options != nil{
            (view as? UITableView)?.reloadData()
        }
    }

    @objc dynamic
    var options:[String: Any]? // Bool may be other custom Codable type instead of Any

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RevertApp.info.identifier) as! Cell

//        cell.imageView?.image = nil
        cell.imageView?.tintColor = primaryColor
        cell.imageView?.contentMode = .scaleAspectFit

        cell.textLabel?.text = "Auto Selection Bot".localized
        cell.imageView?.image = R.image.commonCellIconRobot()?.withRenderingMode(.alwaysTemplate)
        cell.imageView?.tintColor = primaryColor

        cell.optionSwitch.setOn(defaults.autoSelect, animated: false)
        cell.optionSwitch.onTintColor = RevertApp.info.themeColor
        cell.switchDidChange = { on in
            self.defaults.autoSelect = on
            AppCenter.default.currentInstanceAs(RevertApp.self)?.autoSelect = on
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    private class Cell: UITableViewCell {
        lazy var optionSwitch: UISwitch = {
            let view = UISwitch()
            view.addTarget(self, action: #selector(self.cellSwitchDidChange), for: .valueChanged)
            return view
        }()

        var switchDidChange: ((Bool) -> Void)?

        override func prepareForReuse() {
            super.prepareForReuse()

            switchDidChange = nil
        }

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)

            accessoryView = optionSwitch
//            backgroundColor = .clear
//            textLabel?.font = UIFont.systemFont(ofSize: 14)
//            textLabel?.textColor = UIColor.white
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc func cellSwitchDidChange(sender: UISwitch) {
            switchDidChange?(sender.isOn)
        }

        override func layoutSubviews() {
            super.layoutSubviews()

//            imageView?.frame.size = CGSize(width: 30, height: 30)
//            imageView?.frame.origin = CGPoint(x: 10, y: (contentView.bounds.height - 30) / 2)

//            textLabel?.frame.origin.x = (imageView?.frame.maxX ?? 0) + 10
        }
    }
}

import Intents

extension RevertApp:UIApplicationDelegateLaunchableApp{
    static var intents: [INIntent] {
        if #available(iOS 12.0, *) {
            let asb = AutoSelectIntent()
            asb.appId = info.identifier
            asb.appName = defaultIntentAppName
            asb.suggestedInvocationPhrase = "Auto Select on %@.".localizedFormatted(defaultIntentAppName)

            return defaultIntents + [asb]
        } else {
            return []
        }
    }

    func didLaunchHandling(with userActivity: NSUserActivity) {

        if #available(iOS 12.0, *) {
            guard let intent = userActivity.interaction?.intent else {
                return
            }

            if intent is AutoSelectIntent{
                var mutableDefaults = self.appDefaults
                mutableDefaults.autoSelect = true
                (self.content?.view as? UITableView)?.reloadData()
            }
        }

    }

    func didLaunchHandling(with shortcutItem: UIApplicationShortcutItem) {
    }
}
