//
// Created ?by BLACKGENE on 2?7/03/2018.
// Copyrig?ht (c) 2018 Stells. All rights reserved.
//

import Foundation
import Photos
import MetalPerformanceShaders
import MetalKit
import Vision

private typealias CleanerAppParam = AppAsset

typealias PHAssetGCDetectedResult = [String:Bool]

enum PHAssetGCAction: Int{
    case none
    case delete
}

struct PHAssetGCResult:AppTaskResultable {
    let asset:PHAsset
    let action: PHAssetGCAction
}

private typealias PHAssetID = String

public class CleanerApp: NSObject, BApp, LaunchableApp, PHAssetFinalizableApp, PHAssetCacheableApp, AppDockApp, PhotoPickerViewControllerAppearanceDelegatableApp, PhotoPickerCollectionViewDelegatableApp, PreheatableApp {
    public static let taskType: AppTaskable.Type = _CleanerAppTask.self

    public static let paramType: AppTaskParamable.Type = AppAsset.self

    public private(set) lazy var content: AppDockContent? = CleanerAppDockContent()

    fileprivate static var privateDefaults = CleanerApp.defaults as! CleanerAppDefaults

    public static let info = AppInfo(
            identifier: "com.stells.batch.cleaner"
            , version: "1.0"
            , phase: .release
            , appType: CleanerApp.self
            , displayName: "Cleaner".localized.localizedCapitalized
            , description: "Cleaner enables you to find and delete various kind of incorrect photos if they have matched for example duplicate and similar images, close-up photos or Lockscreen shots!".localized
            , keywords: ["Clean","Remove","Instagram Video","Screenshot", "Flashlight", "Close-up", "Similar Photos", "Duplicate", "Capacity", "Memory", "Volume", "Saving"]
            , icon: AppIcon(source: R.image.cleanerBAppIcon.name, style: .original)
            , themeColor: UIColor(red:0.35, green:0.71, blue:0.99, alpha:1), policy: AppPolicy.default
            , minOSVersion: nil
    )

    public required override init() {}

    public var finalizingActions: [PHAssetFinalizingAction] {
        return [.actions]
    }

    public var needsCachingRequestOptions: [PHAssetRequestOption]? {
        var options = [PHAssetRequestOption]()
        let types = type(of: self).SupportingGDTypesKeys
        for gd in type(of: self).privateDefaults.selectedCollection{
            for gditem in gd.items{
                options += types[gditem.gdIdentifier]?.needsCachingRequestOptions ?? []
            }
        }
        return options.nilEmpty
    }

    func didResign(current: App.Type?) {
        self.didCancelPreheating()
    }

    func didLaunch(previous: App.Type?, withOption: AppLaunchOptions?) {

    }

    public var titleWillFinalize: String? {
        return "Deleting Photos...".localized
    }

    public var doneButtonTitle: String? {
        return "Delete".localized
    }
    
    func shouldSelect(item: AppAsset) -> Bool {
        return true
    }

    public fileprivate(set) lazy var autoSelect: Bool = false

    fileprivate static var DefaultEnabledGDTypes:[PHAssetGarbageDetector.Type]{
        return [
            PHAssetGarbageDetector_Flashlight.self
            , PHAssetGarbageDetector_VideosSavedbyInstagramApp.self
            , PHAssetGarbageDetector_TooCloseupFace.self
        ]
    }

    fileprivate static let SupportingGDTypes:[PHAssetGarbageDetector.Type] = [
        PHAssetGarbageDetector_Screenshots.self
        , PHAssetGarbageDetector_Flashlight.self
        , PHAssetGarbageDetector_Lockscreens.self
        , PHAssetGarbageDetector_SavedWithBuiltInCamera.self
//        , PHAssetGarbageDetector_Blurry.self
        , PHAssetGarbageDetector_TooCloseupFace.self
        , PHAssetGarbageDetector_TooSlowShutterSpeed.self
        , PHAssetGarbageDetector_VideosFromScreenRecorder.self
        , PHAssetGarbageDetector_VideosWithoutSound.self
        , PHAssetGarbageDetector_VideosShorterThan1Sec.self
        , PHAssetGarbageDetector_VideosSavedbyInstagramApp.self
        , PHAssetGarbageDetector_SavedWithouttheCamera.self

    ].sorted { (similarityType1: PHAssetGarbageDetector.Type, similarityType2: PHAssetGarbageDetector.Type) -> Bool in
        let containsDefaultEnabled1 = DefaultEnabledGDTypes.contains { _detectorType in
            return _detectorType==similarityType1
        } ? 1 : 0
        let containsDefaultEnabled2 = DefaultEnabledGDTypes.contains { _detectorType in
            return _detectorType==similarityType2
        } ? 1 : 0
        return containsDefaultEnabled1 > containsDefaultEnabled2
    }

    fileprivate static let SupportingGDTypesKeys:[String:PHAssetGarbageDetector.Type]
            = SupportingGDTypes.dictionary { $0.identifier }

    /*
        gc
    */

    func disposeGdInstance(gdIdentifier:String){
        gdInstances[gdIdentifier] = nil

//        //also dispose result caches
//        for (k,v) in cachedResults{
//            var result = v
//            result[gdIdentifier] = nil
//            cachedResults[k] = result
//        }
    }

    private var gdInstances = [String:PHAssetGarbageDetector]()
    fileprivate var cachedResults = [PHAssetID: PHAssetGCDetectedResult]()

    fileprivate func gc(item: PHAssetParamable,  _ async: AsyncWaitSignalable) -> PHAssetGCResult {
        //hey, for Panorama, remove manually
        if item.asset.mediaSubtypes.contains(.photoPanorama){
            return PHAssetGCResult(asset:item.asset, action: .none)
        }

        let gdType_Id = type(of: self).SupportingGDTypesKeys
        let gdCollection = type(of: self).privateDefaults.selectedCollection

        var action:PHAssetGCAction = .none

        for gd in gdCollection{
            let ts = gd.items.compactMap { gcItem -> PHAssetGarbageDetector.Type? in
                // enabled + allowed type
                if gcItem.enabled == false{
                    return nil
                }
                return gdType_Id[gcItem.gdIdentifier]

            }.sorted { (detectorType: PHAssetGarbageDetector.Type, detectorType2: PHAssetGarbageDetector.Type) -> Bool in
                detectorType.priority.rawValue > detectorType2.priority.rawValue
            }

            for t in ts{
                let k = t.identifier
                let asset = item.asset
                let aid = asset.localIdentifier

                //found cached result
                if let detectedResult = cachedResults[aid]
                , let isDeletingTarget = detectedResult[k]{

                    if isDeletingTarget{
                        action = .delete
                        break

                    }else{
                        action = .none
                        continue // set action to none and continue
                    }
                }

                //start to detect
                var detector:PHAssetGarbageDetector
                if let d = gdInstances[k]{
                    detector = d
                }else{
                    detector = t.init()
                    gdInstances[k] = detector
                    print(k,detector)
                }

                let detected = autoreleasepool{
                    return detector.process(input: item, async) ?? false
                }

                if t.shouldCacheResults {
                    var detectedCacheObject = cachedResults[aid] ?? PHAssetGCDetectedResult()
                    detectedCacheObject[k] = detected
                    cachedResults[aid] = detectedCacheObject
                }

                if detected{
                    action = .delete
                    break
                }
            }
        }

        return PHAssetGCResult(asset:item.asset, action: action)
    }

    /*
    preheat
    */
    public func performPreheating(item: PHAssetParamable,  _ async: AsyncWaitSignalable)  -> PreheatingFinishAction? {
        guard self.autoSelect else { return nil }

        (content as? PreheatableAppSubscribable)?.didStartPreheating()

        return gc(item: item, async).action == .delete ? UICollectionViewPreheatableAppFinishAction.selectItem : nil
    }

    public func didCancelPreheating() {
        (content as? PreheatableAppSubscribable)?.didStopPreheating()
    }

    public func didFinishCurrentPreheatingCycle() {
        (content as? PreheatableAppSubscribable)?.didStopPreheating()
    }


    public func finalize(result: [AppTaskRespondable], _ asyncSignal: AsyncWaitSignalable) -> [AppTaskRespondable] {
        let items = result
                .filter { respondable in respondable.info.state == .completed }
                .compactMap { $0.result as? PHAssetGCResult
                }


        let itemsToDelete = items.compactMap { result -> PHAsset? in
            result.action == .delete ? result.asset : nil
        }

        asyncSignal.begin()
        if itemsToDelete.count>0{

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(itemsToDelete as NSArray)
            }, completionHandler: { (success, info) in
                asyncSignal.end()
            })

        }else{
            DispatchQueue.main.async{
                UIAlertController.alert("There are not any deleting targets in selected items.") { action in
                    asyncSignal.end()
                }
            }
        }
        asyncSignal.waitUntilEnd()
        return result
    }
}

private class _CleanerAppTask: AppTaskPrototypeDefaultRestrictedConcurrency, AppTaskable {

    private let deletingTargetMatched = CleanerApp.privateDefaults.deletingTarget==DeletingTarget.targeted.rawValue

    func cancel(_ param: AppTaskParamable, _ async: AsyncWaitSignalable){}

    func perform(_ param: AppTaskParamable, _ async: AsyncWaitSignalable) throws -> AppTaskResultable? {
        guard let item = param as? AppAsset else{
            return nil
        }

        if self.deletingTargetMatched {
            return AppCenter.default.currentInstanceAs(CleanerApp.self)?.gc(item: item, async)
        }else{
            return PHAssetGCResult(asset: item.asset, action: .delete)
        }
    }
}

/*
    Config
*/


private protocol CleanerAppDefaults: AppDefaults{
    var selectedCollection: [GDDictionary] {get set}
    var deletingTarget: Int {get set}
    var saveContactWithoutEdit:Bool {get set}
    var quickActionOnly:Bool {get set}
    var autoSelect:Bool {get set}
}

extension Defaults: CleanerAppDefaults {
    fileprivate var selectedCollection: [GDDictionary] {
        set{ set(newValue) }
        get{
            let defaultCollection = GDDictionary.DefaultCollection
            let collection = get(or: defaultCollection )

            //diff == 0 return
            if defaultCollection == collection{
                return collection
            }
            
            //if not -> migrate
            var migratedCollection = [GDDictionary]()
            let keyedCollection = collection.dictionary { $0.key }
            
            var modCount = 0
            for ddict in defaultCollection {
                guard let ndict = keyedCollection[ddict.key] else {
                    migratedCollection.append(ddict)
                    continue
                }
                
                var m_dict = ddict
                let oGDIds = ddict.itemsGDIdentifiers
                let nGDIds = ndict.itemsGDIdentifiers
                
                for nGDId in nGDIds{
                    if let oindex = oGDIds.firstIndex(of: nGDId)
                        , let nindex = nGDIds.firstIndex(of: nGDId){
                        m_dict.items[oindex] = ndict.items[nindex]
                        modCount += 1
                    }
                }
                migratedCollection.append(m_dict)
            }
            
            if modCount > 0{
                let mSelf = self
                mSelf.selectedCollection = migratedCollection
            }
            
            return migratedCollection
        }
    }

    fileprivate var deletingTarget: Int {
        set{ set(newValue); papLog.app.defaults.log(value:newValue) }
        get{ return get(or: DeletingTarget.selected.rawValue ) }
    }

    fileprivate var saveContactWithoutEdit: Bool {
        set{ set(newValue); papLog.app.defaults.log(value:newValue) }
        get{ return get(or: false ) }
    }

    fileprivate var quickActionOnly: Bool {
        set{ set(newValue); papLog.app.defaults.log(value:newValue) }
        get{ return get(or: false ) }
    }

    fileprivate var autoSelect: Bool {
        set{ set(newValue); }
        get{ return get(or: true ) }
    }
}

private struct GDItem:Codable, Hashable {
    fileprivate let gdIdentifier: String
    fileprivate let label: String
    fileprivate var iconImageName: String?
    fileprivate var iconImageShouldUseTintColor: Bool
    fileprivate var enabled: Bool
    private let _hashValue: Int

    init(gd: PHAssetGarbageDetector.Type) {
        self.gdIdentifier = gd.identifier
        self._hashValue = gdIdentifier.hashValue
        self.label = gd.label
        self.iconImageName = gd.iconImageName
        self.iconImageShouldUseTintColor = gd.iconImageShouldUseTintColor
        self.enabled = CleanerApp.DefaultEnabledGDTypes.contains(where:{ $0 == gd })
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(_hashValue)
    }
}

private struct GDDictionary:Codable, Hashable {
    static let DefaultCollection: [GDDictionary] = [
        GDDictionary(
                key: .Default
                , label: "Targets".localized
                , items: CleanerApp.SupportingGDTypes.map { GDItem(gd: $0) }
        )
    ]

    enum Key: Int, Codable {
        case Default
    }

    fileprivate var key:Key
    fileprivate var label:String
    fileprivate var items:[GDItem]
    fileprivate var itemsGDIdentifiers:[String]{
        return items.map { $0.gdIdentifier }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key.rawValue)
    }
}


/*

AppContent

*/

private enum DeletingTarget:Int{
    case selected
    case targeted
}

private enum CleanerAppSettingCells {
    case deletingTarget
    case autoSelect
    case saveContactWithoutEdit
    case quickActionOnly
//    case delete
}

private struct SettingsItem {
    fileprivate var key: CleanerAppSettingCells
    fileprivate var label:String
    fileprivate var valueGetter:() -> Any
    fileprivate var valueCollection:Any?
    fileprivate var valueHandler:((Any) -> ())?
    fileprivate var cellDescriber: UITableViewCellDescribable //TODO: integrate all properties
    fileprivate var iconImageName:String?
}

fileprivate class CleanerAppDockContent: NSObject, AppDockContent, UITableViewDelegate, UITableViewDataSource, UITableViewPickerCellDelegate{
    private lazy var tintColor = CleanerApp.info.themeColor

    fileprivate var settingCellDescribers = [UITableViewCellDefaultDescribable]()

    private var defaultCollections:[GDDictionary] {
        return CleanerApp.privateDefaults.selectedCollection
    }

    required public override init() {
        super.init()
    }

    lazy var view: UIView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.tintColor = tintColor
        return tableView
    }()
    
    var contentScrollable: AppDockContentScrollable? {
        guard let scrollView = view as? UITableView else { return nil }
        return AppDockScrollableContent(scrollView)
    }

    var preferences: AppDockContentPreferable? {
        var preferences = AppDockContentPreferences()
        preferences.preferredHeight = 300
        return preferences
    }

    private func createCellDescriber_SelectionPreset_contact_saveContactWithoutEdit() -> UITableViewSwitchCellDescriber{
        let celld = UITableViewSwitchCellDescriber()
        celld.itemIdentifier = CleanerAppSettingCells.saveContactWithoutEdit.hashValue
        celld.label = "Save Contacts".localized
        celld.valueGetter = { CleanerApp.privateDefaults.saveContactWithoutEdit }
        celld.valueHandler = {
            var defaults = CleanerApp.privateDefaults
            defaults.saveContactWithoutEdit = $0 as! Bool
        }
        return celld
    }

    private func createCellDescriber_SelectionPreset_action_quickActionsOnly() -> UITableViewSwitchCellDescriber{
        let celld = UITableViewSwitchCellDescriber()
        celld.itemIdentifier = CleanerAppSettingCells.quickActionOnly.hashValue
        celld.label = "Enable Quick Actions".localized
        celld.valueGetter = { CleanerApp.privateDefaults.quickActionOnly }
        celld.valueHandler = {
            var defaults = CleanerApp.privateDefaults
            defaults.quickActionOnly = $0 as! Bool
        }
        return celld
    }

    private var isActivatedAtLeastOne:Bool{
        return self.defaultCollections.compactMap { dictionary -> GDDictionary? in
            return dictionary.items.compactMap { $0.enabled ? $0 : nil }.count > 0 ? dictionary : nil
        }.count > 0
    }

    private func startAutoSelectIfNeeded(){
        AppCenter.default.currentInstanceAs(CleanerApp.self)?.autoSelect = self.isActivatedAtLeastOne && self.autoSelectedEnabled
    }
    private func stopAutoSelect(){
        AppCenter.default.currentInstanceAs(CleanerApp.self)?.autoSelect = false
    }

    private var autoSelectionCellDesc:UITableViewCellDefaultDescribable?{
        return self.settingCellDescribers.first(where:{ describable in
            describable.itemIdentifier == CleanerAppSettingCells.autoSelect.hashValue
        })
    }
    private var autoSelectedEnabled:Bool{
        get{
            return self.autoSelectionCellDesc?.valueGetter() as? Bool ?? false
        }
        set{
            self.autoSelectionCellDesc?.valueHandler?(newValue)
            (self.view as? UITableView)?.reloadSections(IndexSet(integer: 0), with: .fade)
        }
    }

    func willSetContentView(_ view: UIView, dock: AppDock) {

        if settingCellDescribers.count>0{
            return
        }

        let cell1 = UITableViewSwitchSubtitleCellDescriber()
        cell1.itemIdentifier = CleanerAppSettingCells.autoSelect.hashValue
        cell1.label = "Auto Selection Bot".localized
        cell1.iconImage = R.image.commonCellIconRobot.name
        cell1.valueGetter = { CleanerApp.privateDefaults.autoSelect }
        cell1.valueHandler = { val in
            let enabled = val as? Bool ?? false
            CleanerApp.privateDefaults.autoSelect = enabled
            self.startAutoSelectIfNeeded()

            if let tableView = view as? UITableView{
                for section in 1..<self.numberOfSections(in: tableView) {
                    tableView.reloadSections(IndexSet(integer: section), with: .none)
                }
            }

            if enabled{
                papLog.app.userEnablesASB()
            }else{
                papLog.app.userDisablesASB()
            }

        }
        settingCellDescribers.append(cell1)

        let cell0 = UITableViewSegmentControlCellDescriber()
        cell0.itemIdentifier = CleanerAppSettingCells.deletingTarget.hashValue
        cell0.label = "Deleting Targets".localized
        cell0.valueGetter = { CleanerApp.privateDefaults.deletingTarget
        }
        cell0.valueCollection = [
            (label:"Selected".localized,value: DeletingTarget.selected.rawValue),
            (label:"Targeted".localized,value: DeletingTarget.targeted.rawValue)
        ]
        cell0.valueHandler = {
            let preset = $0 as! Int

            var defaults = CleanerApp.privateDefaults
            defaults.deletingTarget = preset

            // selectionPreset changed -> other self.parserCollection getter will be returned.
            (view as? UITableView)?.reloadData()


//            [
//                CleanerAppSettingCells.saveContactWithoutEdit.hashValue
//                , CleanerAppSettingCells.quickActionOnly.hashValue
//            ].forEach { hashValue in
//
//                if let index = self.settingCellDescribers.index(where:{ describable in
//                    return describable.itemIdentifier == hashValue
//                }){
//                    self.settingCellDescribers.remove(at: index)
//                }
//            }

            //saveContactWithoutEdit
//            if preset == DeletingTarget.matched.rawValue{
//                self.settingCellDescribers.append(self.createCellDescriber_SelectionPreset_contact_saveContactWithoutEdit())
//            }
//
//            if preset == DeletingTarget.selected.rawValue{
//                self.settingCellDescribers.append(self.createCellDescriber_SelectionPreset_action_quickActionsOnly())
//            }

            (view as? UITableView)?.reloadData()

            // autoSelect turn off and restore
//            cell1.valueHandler?(false)

        }
//        settingCellDescribers.append(cell0)

        //auto save
        if CleanerApp.privateDefaults.deletingTarget == DeletingTarget.targeted.rawValue{
//            settingCellDescribers.append(createCellDescriber_SelectionPreset_contact_saveContactWithoutEdit())
        }
        else if CleanerApp.privateDefaults.deletingTarget == DeletingTarget.selected.rawValue{
//            settingCellDescribers.append(createCellDescriber_SelectionPreset_action_quickActionsOnly())
        }

        if let tableView = view as? UITableView{
            tableView.dataSource = self
            tableView.delegate = self
            tableView.rowHeight = 44
            tableView.allowsSelection = false
            tableView.allowsMultipleSelection = false
            tableView.register(Cell.self, forCellReuseIdentifier: CleanerApp.info.identifier)

            for desc in settingCellDescribers {
                tableView.register(describer: desc)
            }
        }
    }

    func didSetContentView(_ view:UIView, dock:AppDock) {

        (view as? UITableView)?.reloadData()

        startAutoSelectIfNeeded()
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    }

    func tableView(_ tableView: UITableView, didEndDisplayingHeaderView view: UIView, forSection section: Int) {

    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1 + defaultCollections.count
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 30 : 50
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {

        let label_section0 = "Select Photos To Delete.".localized
        return section == 0 ? label_section0 : defaultCollections[section-1].label
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? settingCellDescribers.count : defaultCollections[section-1].items.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = indexPath.section == 0 ? settings_tableView(tableView, cellForRowAt: indexPath) : itemCollection_tableView(tableView, cellForRowAt: IndexPath(item: indexPath.item, section: indexPath.section))
        return cell
    }

    func settings_tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = self.settingCellDescribers[indexPath.item]

        if let cellDescriber = item as? UITableViewPickerCellDescriber
        , let valueCollection = cellDescriber.valueCollection as? [String]
        , let cell: UITableViewPickerCell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewPickerCell {

            cell.values = valueCollection
            cell.delegate = self
            if let value = item.valueGetter() as? String ?? valueCollection.first, let index = valueCollection.firstIndex(of: value){
                cell.selectedRow = index
            } else{
                cell.selectedRow = 0
            }
            cell.titleLabel.text = item.label
            return cell

        }

        else if let cellDescriber = item as? UITableViewSwitchCellDescriber
        , let value = item.valueGetter() as? Bool
        , let cell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewSwitchCell {

            cell.textLabel?.text = item.label
            cell.detailTextLabel?.text = item.detailedLabel
            cell.switcher.setOn(value, animated: false)
            cell.switcher.onTintColor = CleanerApp.info.themeColor
            if let image = item.iconImage?.asUIImage{
                cell.imageView?.image = image.withRenderingMode(.alwaysTemplate)
                cell.imageView?.tintColor = self.view.tintColor
            }
            cell.switchDidChange = item.valueHandler
            return cell
        }

        else if let cellDescriber = item as? UITableViewStepperCellDescriber
        , let value = item.valueGetter() as? Int
        , let cell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewStepperCell {

            cell.textLabel?.text = item.label
            cell.detailTextLabel?.text = cellDescriber.valuePresenter?(value) ?? String(value)
            cell.imageView?.image = item.iconImage?.asUIImage

            cell.stepper.stepValue = cellDescriber.stepValue
            cell.stepper.minimumValue = cellDescriber.minimumValue
            cell.stepper.maximumValue = cellDescriber.maximumValue
            cell.stepper.value = Double(value)

            cell.didChangeValue = { value in
                cell.detailTextLabel?.text = cellDescriber.valuePresenter?(value) ?? String(Int(value))
                item.valueHandler?(value)
            }
            return cell
        }

        else if let cellDescriber = item as? UITableViewSegmentControlCellDescriber
        , let valueCollection = cellDescriber.valueCollection as? [(String, Int)]
        , let cell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewSegmentedControlCell{

            cell.textLabel?.text = item.label
            cell.imageView?.image = item.iconImage?.asUIImage

            cell.segmentedControl.removeAllSegments()

            for (label, _) in valueCollection{
                cell.segmentedControl.insertSegment(withTitle: label, at: cell.segmentedControl.numberOfSegments, animated: false)
            }

            cell.segmentedControl.selectedSegmentIndex = valueCollection.firstIndex { t in
                t.1 == (item.valueGetter() as! Int)
            } ?? 0

            cell.didChangeValue = item.valueHandler
            return cell
        }

        let cell = tableView.cellForRow(at: indexPath) ?? UITableViewCell()
        cell.textLabel?.text = item.label
        return cell
    }

    func itemCollection_tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let dictIndex = indexPath.section-1
        let dict = defaultCollections[dictIndex]

        let dataItem = dict.items[indexPath.item]
        let selected = dataItem.enabled

        let cell = tableView.dequeueReusableCell(withIdentifier: CleanerApp.info.identifier) as! Cell
        cell.textLabel?.text = dataItem.label
        cell.detailTextLabel?.text = selected ? "%@ might be found".localizedFormatted("").trimmed : nil

        cell.imageView?.tintColor = self.view.tintColor
        let image = dataItem.iconImageName?.asUIImageNamed

        if dataItem.iconImageShouldUseTintColor{
            cell.imageView?.image = image?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
        }else{
            cell.imageView?.image = image?.withRenderingMode(UIImage.RenderingMode.alwaysOriginal)
        }

        cell.detailTextLabel?.textColor = UIColor.gray
        cell.optionSwitch.setOn(selected, animated: false)

        cell.switchDidChange = { on in
            let gdIdentifier = dataItem.gdIdentifier

            //set enable
            var collection = self.defaultCollections
            collection[dictIndex].items[indexPath.item].enabled = on

            papLog.app.defaults.log(key:gdIdentifier, value:on)
            
//            //configure relative options
//            if identifier==PHAssetGarbageDetector_FlashlightAndCloseupFace.identifier{
//                if on{
//                    if let index = self.defaultCollections[dictIndex].items.index(where: { (item) -> Bool in
//                        return item.gdIdentifier==PHAssetGarbageDetector_Flashlight.identifier
//                    }){
//                        self.defaultCollections[dictIndex].items[index].enabled = !on
//                    }
//                }
//
//            }else if identifier==PHAssetGarbageDetector_Flashlight.identifier{
//                if on{
//                    if let index = self.defaultCollections[dictIndex].items.index(where: { (item) -> Bool in
//                        return item.gdIdentifier==PHAssetGarbageDetector_FlashlightAndCloseupFace.identifier
//                    }){
//                        self.defaultCollections[dictIndex].items[index].enabled = !on
//                    }
//                }
//            }

            //commit
            CleanerApp.privateDefaults.selectedCollection = collection
            
            self.stopAutoSelect()

            if on == false{
                AppCenter.default.currentInstanceAs(CleanerApp.self)?.disposeGdInstance(gdIdentifier: gdIdentifier)
            }

//            if self.isActivatedAtLeastOne == false{
//                self.autoSelectedEnabled = self.isActivatedAtLeastOne
//            }

            self.startAutoSelectIfNeeded()

            tableView.reloadRows(at: [indexPath], with: .fade)
        }

//        cell.enable(self.autoSelectedEnabled)

        return cell
    }

    func pickerCell(_ cell: UITableViewPickerCell, didPick row: Int, value: Any) {

    }
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
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)

        accessoryView = optionSwitch
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func cellSwitchDidChange(sender: UISwitch) {
        switchDidChange?(sender.isOn)
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()

        optionSwitch.onTintColor = CleanerApp.info.themeColor
    }
}


extension CleanerAppDockContent: PreheatableAppSubscribable{
    func prepareStatusDisplaying(label:String?){
        var desc = self.settingCellDescribers.first { describable in
            describable.itemIdentifier == CleanerAppSettingCells.autoSelect.hashValue
        }
        desc?.detailedLabel = label
    }

    func didStartPreheating() {
        prepareStatusDisplaying(label: "Activating Current Visible Items ...".localized)
        self.startSelectionBotIconAnimation(self.settingCellDescribers, CleanerAppSettingCells.autoSelect.hashValue)
    }

    func didStopPreheating() {
        prepareStatusDisplaying(label: CleanerApp.privateDefaults.autoSelect ? "On Standby".localized : nil)
        self.stopSelectionBotIconAnimation(self.settingCellDescribers, CleanerAppSettingCells.autoSelect.hashValue)
    }
}

import Intents
extension CleanerApp: UIApplicationDelegateLaunchableApp {
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
                let d = (self.content as? CleanerAppDockContent)?.settingCellDescribers.first { describable in
                    describable.itemIdentifier == CleanerAppSettingCells.autoSelect.hashValue
                }
                d?.valueHandler?(true)
                (self.content?.view as? UITableView)?.reloadData()
            }
        }

    }

    func didLaunchHandling(with shortcutItem: UIApplicationShortcutItem) {
    }
}

