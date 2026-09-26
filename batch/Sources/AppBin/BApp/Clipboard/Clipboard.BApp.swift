//
//  Clipboard.BApp.swift
//  pap
//
//  Created by HYOJIN MO on 2018. 10. 18..
//  Copyright © 2018년 Stells. All rights reserved.
//

import UIKit
import Photos


private typealias ClipboardAppParam = AppAsset
private struct ClipboardAppResult: AppTaskResultable {
    var image: UIImage
}
private class _ClipboardAppTask: AppTaskPrototype, AppTaskable {
    public func cancel(_ param: AppTaskParamable, _ async: AsyncWaitSignalable){}
    
    public func perform(_ param: AppTaskParamable, _ async: AsyncWaitSignalable) throws -> AppTaskResultable? {
        assert(param is ClipboardAppParam, "TaskParamable type of this app is \(ClipboardAppParam.self)")
        guard let _param = param as? ClipboardAppParam else{
            throw AppTaskError.invalidParam
        }
        return try self._perform(_param, async)
    }
    
    private func _perform(_ clipboardParam: ClipboardAppParam, _ async: AsyncWaitSignalable) throws -> ClipboardAppResult?  {
        async.begin()
        
        var result: ClipboardAppResult?
        DispatchQueue(label: "com.stells.internal."+fileName(), qos: .utility).async {
            if let image = clipboardParam.asset.asUIImage {
                result = ClipboardAppResult(image: image)
            }
            async.end()
        }
        
        async.waitUntilEnd()
        return result
    }
}

class ClipboardApp: NSObject, BApp, AppDockApp, PhotoPickerViewControllerAppearanceDelegatableApp, PhotoPickerCollectionViewDelegatableApp, FinalizableApp {
    public static let taskType: AppTaskable.Type = _ClipboardAppTask.self
    public static let paramType: AppTaskParamable.Type = ClipboardAppParam.self
    
    // support Universal Clipboard
    // https://support.apple.com/kb/PH25168?locale=en_US
    
    public static let info = AppInfo(
        identifier: "com.stells.batch.clipboard"
        , version: "1.0"
        , phase: .develop
        , appType: ClipboardApp.self
        , displayName: "Clipboard".localized.localizedCapitalized
        , description: "Paste images from your clipboards".localized
        , keywords: ["Clipboard","Pasteboard","Copy","Paste","Cut"]
        , icon: AppIcon(source: R.image.clipboardBAppIcon.name, style: .original)
        , themeColor: UIColor(red: 0.67, green: 0.73, blue: 0.67, alpha: 1)
        , policy: AppPolicy.default
        , minOSVersion: nil
    )
    
    public private(set) lazy var content: AppDockContent? = ClipboardAppDockContent()
    
    required override init() {
        super.init()
    }
    
    public var titleWillBegin: String? {
        return "Starting to copy photos...".localized
    }
    
    public var titleWillFinalize: String? {
        return "Copying Photos...".localized
    }
    
    public var doneButtonTitle: String?{
        return "Copy".localized
    }
    
    func shouldSelect(item: AppAsset) -> Bool {
        return true
    }
    
    var numberOfItemsShouldSelect: Int? {
        return 4
    }
    
    public func finalize(result: [AppTaskRespondable], _ asyncSignal: AsyncWaitSignalable) -> [AppTaskRespondable] {
        let items = result
            .filter { respondable in respondable.info.state == .completed }
            .compactMap { $0.result as? ClipboardAppResult }
        
        asyncSignal.begin()
        DispatchQueue(label: fileName() + "exportImagesToClipboard", qos: .utility).async {
            UIPasteboard.general.images = items.compactMap { $0.image }
            asyncSignal.end()
        }
        asyncSignal.waitUntilEnd()
        
        return result
    }
}

fileprivate class ClipboardAppDockContent: NSObject, AppDockContent {
    lazy var view: UIView = {
        return tableView
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        return tableView
    }()
    
    var contentScrollable: AppDockContentScrollable? {
        return AppDockScrollableContent(tableView)
    }
    
    var preferences: AppDockContentPreferable? {
        var preferences = AppDockContentPreferences()
        preferences.preferredHeight = tableView.estimatedRowHeight * 5
        return preferences
    }
    
    func willSetContentView(_ view: UIView, dock: AppDock) {
        tableView.dataSource = delegator
        tableView.delegate = delegator
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
        tableView.allowsSelection = false
        tableView.allowsMultipleSelection = false
        tableView.tintColor = view.tintColor
    }
    
    func didSetContentView(_ view:UIView, dock:AppDock) {
        view.tintColor = view.colorTheme.tintColor
        
        if self.delegator.group.isEmpty {
            reloadData()
        }
        
        registerClipboardObservingTimer()
    }
    
    func willRemoveContentView() {
        unregisterClipboardObservingTimer()
    }
    
    private var clipboardObservingTimerId: String {
        return "\(fileName())_clipboardObservingTimer"
    }
    
    private var fetchedChangeCount: Int = 0
    private var hasClipboardChanges: Bool {
        return fetchedChangeCount != UIPasteboard.general.changeCount
    }
    
    internal func registerClipboardObservingTimer() {
        Timer.scheduledTimer(identifier: clipboardObservingTimerId, withTimeInterval: 1, repeats: true) { timer in
            if self.hasClipboardChanges {
                self.reloadData()
            }
        }
    }
    
    internal func unregisterClipboardObservingTimer() {
        Timer.removeScheduledTimer(identifier: clipboardObservingTimerId)
    }
    
    lazy var delegator = ClipboardTableViewContentDelegator()
    
    fileprivate func reloadData(completion: (() -> Void)? = nil) {
        DispatchQueue(label: fileName() + "fetchPasteboardItems", qos: .utility).async {
            self.delegator.group = self.fetchPasteboardItems()
            
            DispatchQueue.main.async {
                for group in self.delegator.group{
                    if let groupDesc = group.groupHeaderCellDescriber{
                        self.tableView.register(describer: groupDesc)
                    }
                    for intentCellDescriber in group.itemCellDescribers {
                        self.tableView.register(describer: intentCellDescriber)
                    }
                }
                
                self.tableView.reloadData()
                
                completion?()
            }
        }
    }
    
    private var localPasteboard: UIPasteboard? {
        return UIPasteboard(name: UIPasteboard.Name(Bundle.main.bundleIdentifier ?? "com.stells.batch"), create: true)
    }
    
    private var isSafariOpened = false
    
    private func cellDescriberGroupFor(pasteboard: UIPasteboard, title: String, footerText: String? = nil) -> CellDescriberGroup {
        var cellDescribers = [UITableViewButtonCellDescriber]()
        
        if pasteboard.hasImages, let images = pasteboard.images {
            for (idx, image) in images.enumerated() {
                let cell = UITableViewButtonCellDescriber()
                cell.itemIdentifier = "image \(idx)".hashValue
                cell.iconImage = image
                cell.label = "Image".localized
                cell.buttonTitle = "Save".localized
                cell.valueHandler = { _ in
                    if let data = image.jpegData(compressionQuality: 0.7) {
                        cell.indicating = true
                        DispatchQueue.main.async { self.tableView.reloadData() }
                        
                        self.createAssetFromData(data, uti: data.detectedUTI()) {
                            cell.indicating = false
                            DispatchQueue.main.async { self.tableView.reloadData() }
                        }
                    }
                }
                
                cellDescribers.append(cell)
            }
        }
        
        if pasteboard.hasURLs, let urls = pasteboard.urls {
            for (idx, url) in urls.enumerated() {
                
                let cell = UITableViewButtonCellDescriber()
                cell.itemIdentifier = "url \(idx)".hashValue
                cell.label = url.host ?? (url.lastPathComponent.isEmpty ? url.scheme ?? url.relativeString : url.lastPathComponent)
                cell.buttonTitle = "Download".localized
                let uti = UTI(withURL: url)
                if uti.conforms(to: UTI.image) {
                    cell.buttonDetailTitle = "Image".localized
                }
                else if uti.conforms(to: UTI.movie) {
                    cell.buttonDetailTitle = "Video".localized
                }
                else {
                    cell.buttonDetailTitle = "URL".localized
                    cell.buttonTitle = "Open".localized
                }
                cell.valueHandler = { _ in
                    cell.indicating = true
                    DispatchQueue.main.async { self.tableView.reloadData() }
                    
                    self.saveImageFromURL(url, completion: {
                        cell.indicating = false
                        DispatchQueue.main.async { self.tableView.reloadData() }
                    })
                }
                
                cellDescribers.append(cell)
            }
        }
        else if pasteboard.hasStrings, let urls = pasteboard.strings?.compactMap({ URL(string: $0) }).filter({ !$0.absoluteString.urls().isEmpty }), !urls.isEmpty {
            for (idx, url) in urls.enumerated() {
                let cell = UITableViewButtonCellDescriber()
                cell.itemIdentifier = "url \(idx)".hashValue
                cell.label = url.host ?? (url.lastPathComponent.isEmpty ? url.scheme ?? url.relativeString : url.lastPathComponent)
                cell.buttonTitle = "Download".localized
                let uti = UTI(withURL: url)
                if uti.conforms(to: UTI.image) {
                    cell.buttonDetailTitle = "Image".localized
                }
                else if uti.conforms(to: UTI.movie) {
                    cell.buttonDetailTitle = "Video".localized
                }
                else {
                    cell.buttonDetailTitle = "URL".localized
                    cell.buttonTitle = "Open".localized
                }
                cell.valueHandler = { _ in
                    cell.indicating = true
                    DispatchQueue.main.async { self.tableView.reloadData() }
                    
                    self.saveImageFromURL(url, completion: {
                        cell.indicating = false
                        DispatchQueue.main.async { self.tableView.reloadData() }
                    })
                }
                
                cellDescribers.append(cell)
            }
        }
        else if pasteboard.hasStrings, let strings = pasteboard.strings {
            for (idx, string) in strings.enumerated() {
                let cell = UITableViewButtonCellDescriber()
                cell.itemIdentifier = "text \(idx)".hashValue
                cell.label = string.trimmed
                
                cellDescribers.append(cell)
            }
        }
        
        var detailedLabel: String? = nil
        if cellDescribers.isEmpty {
            let cell = UITableViewButtonCellDescriber()
            cell.itemIdentifier = "empty".hashValue
            cell.label = "Clipboard is empty".localized
            
            cellDescribers.append(cell)
            
            detailedLabel = "Select the content you want to copy, then copy it on your iPhone or Mac with Handoff".localized
        }
        else {
            if pasteboard.contains(pasteboardTypes: ["com.apple.is-remote-clipboard"]) {
                detailedLabel = "From remote clipboard".localized
            }
            else {
                detailedLabel = "From clipboard on iOS".localized
            }
        }
        
        let groupDescriber = UITableViewCellDescriber()
        groupDescriber.itemIdentifier = pasteboard.hashValue
        groupDescriber.label = title
        
        let group = CellDescriberGroup(label: title, detailedLabel: footerText ?? detailedLabel, groupHeaderCellDescriber: groupDescriber, itemCellDescribers: cellDescribers)
        return group
    }
    
    fileprivate var currentClipboardGroup: CellDescriberGroup?
    
    private func fetchPasteboardItems() -> [CellDescriberGroup] {
        self.fetchedChangeCount = UIPasteboard.general.changeCount
        
        var groups = [CellDescriberGroup]()
        
        let clipboardGroup = cellDescriberGroupFor(pasteboard: UIPasteboard.general, title: "Clipboard".localized)
        currentClipboardGroup = clipboardGroup
        groups.append(clipboardGroup)
        
//        if let localPasteboard = self.localPasteboard, localPasteboard.strings != UIPasteboard.general.strings {
//            groups.append(cellDescriberGroupFor(pasteboard: localPasteboard, title: Bundle.main.displayName ?? "", footerText: "Restore from previous clipboard".localized))
//        }
//
//        self.localPasteboard?.items = UIPasteboard.general.items
        
        return groups
    }
    
    private func saveImageFromURL(_ url: URL, completion: (() -> Void)?) {
        DispatchQueue(label: fileName() + #function, qos: .utility).async {
            if let data = try? Data(contentsOf: url), let uti = data.detectedUTI(sourceURL: url), (uti.conforms(to: UTI.image) || uti.conforms(to: UTI.movie)) {
                self.createAssetFromData(data, uti: uti, completion: completion)
            }
            else {
                guard !self.isSafariOpened else {
                    completion?()
                    return
                }
                self.isSafariOpened = true
                
                let async = AsyncSignal()
                async.begin()
                
                DispatchQueue.mainAsyncIfNot {
                    UIApplication.openSafari(with: url, didPresent: {
                    
                    }, didLoad:{ loaded in
                    
                    }, didDismiss: {
                        async.end()
                        completion?()
                        self.isSafariOpened = false
                    })
                }
                async.waitUntilEnd()
            }
        }
    }
    
    private func createAssetFromData(_ data: Data, uti: UTI?, completion: (() -> Void)?) {
        DispatchQueue(label: fileName() + #function, qos: .utility).async {
            let signal = AsyncSignal()
            signal.begin()
            PHPhotoLibrary.shared().performChanges({
                let url = FileURL.temp("\(UUID().uuidString)", uti, group: ClipboardApp.info.displayName)
                try? data.write(to: url)
                
                let creationRequest = PHAssetCreationRequest.forAsset()
                if uti?.conforms(to: UTI.image) == true {
                    creationRequest.addResource(with: .photo, fileURL: url, options: nil)
                }
                else if uti?.conforms(to: UTI.movie) == true {
                    creationRequest.addResource(with: .video, fileURL: url, options: nil)
                }
            }, completionHandler: { (success, info) in
                signal.end()
                completion?()
            })
            signal.waitUntilEnd()
        }
    }
}

private protocol Section{
    var label:String{get}
    var detailedLabel:String?{get}
    var itemsOfSection:[Any]{get}
}

private struct ClipboardGroup: Hashable, Equatable, Section {
    var type: String
    var values: [Any]
    
    var label: String {
        return ""
    }
    
    var detailedLabel: String? {
        return nil
    }
    
    var itemsOfSection: [Any] {
        return values
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(type.hashValue)
    }
    
    static func == (lhs: ClipboardGroup, rhs: ClipboardGroup) -> Bool{
        return lhs.hashValue == rhs.hashValue
    }
    
    init(type: String, values: [Any]) {
        self.type = type
        self.values = values
    }
}

private struct CellDescriberGroup: Section{
    fileprivate let label:String
    fileprivate var detailedLabel:String?
    fileprivate var groupHeaderCellDescriber:UITableViewCellDefaultDescribable?
    fileprivate var itemCellDescribers:[UITableViewCellDefaultDescribable]
    
    var itemsOfSection: [Any] {
        return itemCellDescribers
    }
}

private class ClipboardTableViewContentDelegator: NSObject, UITableViewDataSource, UITableViewDelegate {
    var group: [CellDescriberGroup] = []
    
    convenience init(group: [CellDescriberGroup]) {
        self.init()
        
        self.group = group
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return group.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = group[section]
        return section.itemsOfSection.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellDescriber = group[indexPath.section].itemCellDescribers[indexPath.row]
        
        if let cellDescriber = cellDescriber as? UITableViewButtonCellDescriber
            , let cell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewButtonCell {
            
            cell.imageView?.image = cellDescriber.iconImage?.asUIImage
            cell.textLabel?.text = cellDescriber.label
            
            if let buttonTitle = cellDescriber.buttonTitle{
                cell.setButtonTitle(title: buttonTitle, detailTitle: cellDescriber.buttonDetailTitle, for: .normal)
                cell.button.setTitleColor(tableView.tintColor, for: .normal)
            }
            cell.didTap = {
                cellDescriber.valueHandler?("tapped")
            }
            
            let _ = cellDescriber.indicating ? cell.startIndicating() : cell.stopIndicating()
            
            return cell
        }
        else {
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return group[section].label
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return group[section].detailedLabel
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    private lazy var iconImageCache:NSCache = NSCache<NSString,UIImage>()
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        if let cellDescriber = group[section].groupHeaderCellDescriber,
            let cell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier){
            
            var iconImage = iconImageCache.object(forKey: cellDescriber.label as NSString)
            if iconImage == nil{
                if let image = cellDescriber.iconImage?.asUIImage?/*.rounded()?*/.resize(aspectFit: CGSize(width: 34, height: 34)){
                    iconImage = image
                    iconImageCache.setObject(image, forKey: cellDescriber.label as NSString)
                }
            }
            
            cell.imageView?.image = iconImage
            cell.textLabel?.text = cellDescriber.label
            cell.textLabel?.textColor = UIColor.gray
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
            cell.backgroundColor = UIColor.clear
            return cell
        }
        
        return nil
    }
}

import Intents

extension ClipboardApp: UIApplicationDelegateLaunchableApp {
    static var intents: [INIntent] {
        if #available(iOS 12.0, *) {
            var intents = [INIntent]()
            
            let openAppIntent = OpenIntent()
            openAppIntent.appId = ClipboardApp.info.identifier
            openAppIntent.appName = NSString.deferredLocalizedIntentsString(with: ClipboardApp.info.displayName) as String
            openAppIntent.suggestedInvocationPhrase = "Open %@.".localizedFormatted(defaultIntentAppName)
            intents.append(openAppIntent)
            
            let pasteImageIntent = PasteImageIntent()
            pasteImageIntent.appId = ClipboardApp.info.identifier
            pasteImageIntent.suggestedInvocationPhrase = "Save the copied image.".localized
            intents.append(pasteImageIntent)
            
            return [openAppIntent, pasteImageIntent]
        } else {
            return []
        }
    }
    
    func didLaunchHandling(with userActivity: NSUserActivity) {
        if #available(iOS 12.0, *) {
            guard let intent = userActivity.interaction?.intent
                , let content = self.content as? ClipboardAppDockContent else {
                    return
            }
            
            if intent is PasteImageIntent {
                content.reloadData {
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+1) {
                        content.currentClipboardGroup?.itemCellDescribers.compactMap { $0.valueHandler }.first?("")
                    }
                }
            }
        }
    }
    
    func didLaunchHandling(with shortcutItem: UIApplicationShortcutItem) {
    }
}
