//
// Created by BLACKGENE on 02/05/2018.
// Copyright (c) 2018 Stells. All rights reserved.
//

//INFO: mainly focusing on GIF, at first.

import Foundation
import UIKit
import Photos

private protocol ConverterAppDefaults: AppDefaults{
    var convertingDirection: ConvertingDirection {get set}
    var convertingQuality: ConvertingQuality {get set}
    var autoSelect: Bool {get set}

}

extension Defaults: ConverterAppDefaults {
    fileprivate var convertingDirection: ConvertingDirection {
        set { set(newValue); papLog.app.defaults.log(value:newValue.identifier) }
        get { return get(or: ConvertingDirection(from: .livephoto, to: .gif)) }
    }

    fileprivate var convertingQuality: ConvertingQuality {
        set { set(newValue, key:"convertingQualityFor_\(newValue.convertingDirection.identifier)") }
        get { return get(key:"convertingQualityFor_\(convertingDirection.identifier)") ?? ConvertingQuality(convertingDirection: convertingDirection, qualityType: .high) }
    }

    fileprivate var autoSelect: Bool {
        set { set(newValue) }
        get { return get(or:false) }
    }
}


public class ConverterAppConfigValue: NSObject, PropertyWatchable, AppConfigValuable {
    @objc dynamic
    public var convertingDirectionIdentifier:String = ConverterApp.defaultConverter.direction.identifier
}

public class ConverterApp: NSObject, PropertyWatchable,
        BApp,
        AppDockApp,
        ConfigurableApp, _ConfigurableApp,
        FinalizableApp,
        PreheatableApp,
        LaunchableApp,
        PHAssetFinalizableApp,
        PhotoPickerCollectionViewDelegatableApp,
        PhotoPickerViewControllerAppearanceDelegatableApp {

    public static let taskType: AppTaskable.Type = ConverterAppTask.self
    public static let paramType: AppTaskParamable.Type = AppAsset.self

    public static var defaultConfigValue: AppConfigValuable {
        return ConverterAppConfigValue()
    }

    @objc dynamic
    public private(set) lazy var config: ConverterAppConfigValue? = type(of:self).defaultConfigValue as? ConverterAppConfigValue

    public private(set) lazy var content: AppDockContent? = ConverterAppDockContent(app:self)

    @objc dynamic
    public lazy var autoSelect: Bool = false

    public static let info = AppInfo(
            identifier: "com.stells.batch.converter"
            , version: "1.0"
            , phase: .release
            , appType: ConverterApp.self
            , displayName: "Converter".localized.localizedCapitalized
            , description: "Converter enables you to convert every media formats such as Videos, Live Photos, GIFs into every each other.".localized
            , keywords: ["GIF Converter", "Live Photos", "GIF Editor", "GIF", "Video Converter", "Mp4", "MOV", "Movie File", "Video Quality","Burst Photos","Animated GIF", "Animation"]
            , icon: AppIcon(source: R.image.converterBAppIcon.name, style: .original)
            , themeColor: UIColor(red:0.99, green:0.51, blue:0.15, alpha:1)
            , policy: AppPolicy(lifeCycle: AppLifecyclePolicy(instance: .availability), task: AppTaskPolicy.default)
            , minOSVersion: nil
    )

    override required public init() {
        super.init()
    }

    public var doneButtonTitle: String? {
        return "Convert".localized
    }

    public func shouldSelect(item: AppAsset) -> Bool {
        return currentConverter?.canPerformWith(asset: item.asset) ?? true
    }

    public var numberOfItemsShouldSelect: Int? {
        return nil
    }

    func didResign(current: App.Type?) {

    }

    func didLaunch(previous: App.Type?, withOption: AppLaunchOptions?) {
        currentLaunchOption = withOption
    }

    fileprivate var currentLaunchOption: AppLaunchOptions?{
        didSet {

            if let convertingDirection = currentLaunchOption?.options?[.ConvertingDirection] as? ConvertingDirection{
                var mutableDefaults = self.defaults
                mutableDefaults.autoSelect = false
                mutableDefaults.convertingDirection = convertingDirection
            }
        }
    }

    public func setConfigValues<T: AppConfigValuable>(_ config:T){

    }

    public func finalize(result: [AppTaskRespondable], _ asyncSignal: AsyncWaitSignalable) -> [AppTaskRespondable] {
        let resultItems:[ConverterAppResult]? = result
                .filter { respondable in respondable.info.state == .completed }
                .compactMap{ $0.result as? ConverterAppResult }
                .sorted { (result1: ConverterAppResult?, result2: ConverterAppResult?) -> Bool in
                    (result1?.orderedIndex ?? 0) < (result2?.orderedIndex ?? 0)
                }
//                .compactMap { ($0.result as? ConverterVoidReturnType) == ConverterVoidReturnValue ? nil : $0.result }

        guard let items = resultItems, items.count > 0 else {
            return result
        }
        
        let success = showingActionsAndWait(targetResultAssets: items.map({ PHAssetResultItem(asset: AppAsset($0.asset), editingResultItems: $0.result) }), excludedActions: [.modify], asyncSignal)
        result.forEach {
            $0.info.userInfo[AppTaskInfo.UserInfo.Key.removedOnCompletion] = success
        }

        return result
    }

    public func performPreheating(item: PHAssetParamable, _ async: AsyncWaitSignalable) -> PreheatingFinishAction? {
        let autoSelect = self.defaults.autoSelect && self.shouldSelect(item: AppAsset(item.asset, indexPath: nil))
        return autoSelect ? UICollectionViewPreheatableAppFinishAction.selectItem : nil
    }

    func shouldSelectWhenInserted(indexPaths: [IndexPath]?) -> [IndexPath]? {
        if let _ = currentLaunchOption{
            return indexPaths
        }
        return nil
    }

    func didSelectWhenInserted(callee: PhotoPickerViewControllerUniversalOperations, indexPaths: [IndexPath]) {
        if let _ = currentLaunchOption{
            callee.performInSelectionContext()
        }
    }

    var photoPickerCallee:PhotoPickerViewControllerUniversalOperations?

    func didAppear(callee: PhotoPickerViewControllerUniversalOperations) {
        self.photoPickerCallee = callee
    }
}

extension ConverterApp{
    fileprivate var defaults:ConverterAppDefaults{
        return ConverterApp.defaults as! ConverterAppDefaults
    }

    var currentConverter:Converter.Type?{
        return ConverterApp.availableConverters.first { converterType in
            return converterType.direction==defaults.convertingDirection
        }
    }

    static let availableConverters:[Converter.Type] = [
        MovConverter_Burst.self,
        MovConverter_LivePhoto.self,
        MovConverter_Gif.self,
        MP4Converter_Timelapse.self,

        LivePhotoConverter_Burst.self,
        LivePhotoConverter_Gif.self,
        LivePhotoConverter_Mov.self,
        LivePhotoConverter_Timelapse.self,

        GifConverter_Burst.self,
        GifConverter_LivePhoto.self,
        GifConverter_Timelapse.self,
        GifConverter_Mov.self,

        JpgConverter_ScreenshotPng.self,
        MP4Converter_Mov.self
    ]

    static var availableDirections:[ConvertingDirection] {
        return ConverterApp.availableConverters.map { converterType -> ConvertingDirection in
            return converterType.direction
        }
    }

    static var availableConverterNames:[String] {
        return Array(Set(availableDirections.map { $0.from.rawValue })).sorted()
    }

    static func getAvailableConverters(fromRawValue:String) -> [Converter.Type]{
        return availableConverters.filter { converterType in
            return converterType.direction.from.rawValue == fromRawValue
        }
    }

    static func getAvailableConverters(toRawValue:String) -> [Converter.Type]{
        return availableConverters.filter { converterType in
            return converterType.direction.to.rawValue == toRawValue
        }
    }

    static func getAvailableConverters(by direction:ConvertingDirection) -> [Converter.Type]{
        return availableConverters.filter { converterType in
            return converterType.direction == direction
        }
    }

    static func getAvailableConvertersNamesTo(fromRawValue:String) -> [String]{
        return Array(Set(self.getAvailableConverters(fromRawValue: fromRawValue).map { converter -> String in  converter.direction.to.rawValue }))
    }

    static func getAvailableConvertersNamesFrom(toRawValue:String) -> [String]{
        return Array(Set(self.getAvailableConverters(toRawValue: toRawValue).map { converter -> String in  converter.direction.from.rawValue }))
    }

    static var defaultConverter:Converter.Type{
        return GifConverter_LivePhoto.self
    }
}


private struct ConverterAppResult: AppTaskResultable {
    var asset: PHAsset
    var result:[PHAssetEditingResultItem]?
    var orderedIndex: Int?
}

private class ConverterAppTask: AppTaskPrototype, AppTaskable {
    public typealias ParamType = AppAsset
    public typealias ResultType = ConverterAppResult

    let defaults = ConverterApp.defaults as! ConverterAppDefaults

    override var info: AppTaskInfo {
        let info = super.info

        //default is undefined.
        info.policy.estimatedConcurrencyCount = nil

        if let currentConverterType = ConverterApp.availableConverters.first(where:{
            $0.direction == defaults.convertingDirection
        }) {

            if currentConverterType is LivePhotoConverter.Type{
                //override concurrencyCount if currentConverterType is LivePhotoConverter
                info.policy.estimatedConcurrencyCount = 1
            }
        }

        return info

    }

    public func cancel(_ param: AppTaskParamable, _ async: AsyncWaitSignalable){

        (param as? AppAsset)?.cancelAllRequestIDs()
    }

    public func perform(_ param: AppTaskParamable, _ async: AsyncWaitSignalable) throws -> AppTaskResultable? {
        guard let appAsset = param as? AppAsset else { return nil }
        return try _perform(appAsset, async)
    }

    private func _perform(_ assetItem: AppAsset, _ async: AsyncWaitSignalable) throws -> ConverterAppResult?  {
        let direction = defaults.convertingDirection
        let needsConverter = ConverterSpec.acquireInstance(collection: ConverterApp.availableConverters, direction: direction, asset: assetItem)

        guard let converter = needsConverter else {
            throw AppTaskError.rejectedParam
        }

        //TODO: integrate someday remove IFs
        if let converter = converter as? OptionableConverterBase<GifConverterDefaultOption> {
            converter.options = GifConverterDefaultOption.preset(defaults.convertingQuality.qualityType, with: assetItem.asset)
        }
        else if let converter = converter as? OptionableConverterBase<MovConverterOption> {
            converter.options = MovConverterOption.preset(defaults.convertingQuality.qualityType, with: assetItem.asset)
        }
        else if let converter = converter as? OptionableConverterBase<JpgConverterOption> {
            converter.options = JpgConverterOption.preset(defaults.convertingQuality.qualityType, with: assetItem.asset)
        }
        else if let converter = converter as? OptionableConverterBase<MP4ConverterOption> {
            converter.options = MP4ConverterOption.optionBy(defaults.convertingQuality.qualityType, with: assetItem.asset)
        }
        
        let result = converter.convert(source: assetItem, cancellation: { self.info.state == .cancelled }, progressHandler: { progress in
            AppAssetItemProgressNotification.update(item: assetItem, progress: progress)
        }, async)
        let index = AppAssets.selected.index(of: assetItem)

        return ConverterAppResult(asset: assetItem.asset, result: result, orderedIndex: index)
    }
}

import Intents

extension ConverterApp:UIApplicationDelegateLaunchableApp {
    static var intents: [INIntent] {
        if #available(iOS 12.0, *) {

            var intents = [INIntent]()

            let convertLatestLivePhotoIntent_gif = ConvertLatestLivePhotoIntent()
            convertLatestLivePhotoIntent_gif.appId = ConverterApp.info.identifier
            convertLatestLivePhotoIntent_gif.into = ConvertLatestLivePhotoLivePhotoConvertingType.gif
            convertLatestLivePhotoIntent_gif.suggestedInvocationPhrase = "Convert the last Live Photo Into a GIF.".localized
            intents.append(convertLatestLivePhotoIntent_gif)

            let convertLatestLivePhotoIntent_video = ConvertLatestLivePhotoIntent()
            convertLatestLivePhotoIntent_video.appId = ConverterApp.info.identifier
            convertLatestLivePhotoIntent_video.into = ConvertLatestLivePhotoLivePhotoConvertingType.video
            convertLatestLivePhotoIntent_video.suggestedInvocationPhrase = "Convert the last Live Photo Into a Video.".localized
            intents.append(convertLatestLivePhotoIntent_video)

            let convertLatestVideoIntent_into_livephoto = ConvertLatestVideoIntent()
            convertLatestVideoIntent_into_livephoto.appId = ConverterApp.info.identifier
            convertLatestVideoIntent_into_livephoto.into = ConvertLatestVideoVideoConvertingType.livephoto
            convertLatestVideoIntent_into_livephoto.suggestedInvocationPhrase = "Convert the last Video Into a Live Photo.".localized
            intents.append(convertLatestVideoIntent_into_livephoto)

            let convertLatestVideoIntent_into_mp4 = ConvertLatestVideoIntent()
            convertLatestVideoIntent_into_mp4.appId = ConverterApp.info.identifier
            convertLatestVideoIntent_into_mp4.into = ConvertLatestVideoVideoConvertingType.mp4
            convertLatestVideoIntent_into_mp4.suggestedInvocationPhrase = "Convert the last Video Into a MP4.".localized
            intents.append(convertLatestVideoIntent_into_mp4)

            let convertLatestVideoIntent_into_gif = ConvertLatestVideoIntent()
            convertLatestVideoIntent_into_gif.appId = ConverterApp.info.identifier
            convertLatestVideoIntent_into_gif.into = ConvertLatestVideoVideoConvertingType.gif
            convertLatestVideoIntent_into_gif.suggestedInvocationPhrase = "Convert the last Video Into a GIF.".localized
            intents.append(convertLatestVideoIntent_into_gif)

            let asb = AutoSelectIntent()
            asb.appId = info.identifier
            asb.appName = defaultIntentAppName
            asb.suggestedInvocationPhrase = "Auto Select on %@.".localizedFormatted(defaultIntentAppName)
            intents.append(asb)

            return defaultIntents + intents
        } else {
            return []
        }
    }

    func didLaunchHandling(with userActivity: NSUserActivity) {

        if #available(iOS 12.0, *) {
            guard let intent = userActivity.interaction?.intent else{
                return
            }

            /*
            ConvertIntent
            */

            var convertingDirection:ConvertingDirection?

            if let intentForLivePhoto = intent as? ConvertLatestLivePhotoIntent{

                switch(intentForLivePhoto.into){
                    case .gif:
                        convertingDirection = ConvertingDirection(from: .livephoto, to: .gif)
                    case .video:
                        convertingDirection = ConvertingDirection(from: .livephoto, to: .mov)
                    default:
                        convertingDirection = nil
                }

            }
            else if let intentForVideo = intent as? ConvertLatestVideoIntent{

                switch(intentForVideo.into){
                    case .livephoto:
                        convertingDirection = ConvertingDirection(from: .mov, to: .livephoto)
                    case .mp4:
                        convertingDirection = ConvertingDirection(from: .mov, to: .mp4)
                    case .gif:
                        convertingDirection = ConvertingDirection(from: .mov, to: .gif)
                    default:
                        convertingDirection = nil
                }
            }

            if let direction = convertingDirection, let converter = ConverterApp.getAvailableConverters(by: direction).first{

                //reload direction
                var mutableDefaults = self.defaults
                mutableDefaults.convertingDirection = direction
                (self.content as! ConverterAppDockContent).reloadData(reset: true)

                //find latest asset with matched converter
                DispatchQueue.global(qos: .userInteractive).async{

                    let foundAsset = PHAssets.fetched.searchLast{ i, asset in converter.canPerformWith(asset: asset) }
                    if let foundAsset = foundAsset{
                        DispatchQueue.main.async{
                            assert(self.photoPickerCallee != nil)
                            self.photoPickerCallee?.selectInCurrentContext(with: foundAsset, animated: true)
                            self.photoPickerCallee?.performInSelectionContext()
                        }
                    }
                }

            }else{
                UIAlertController.alert("Sorry, This converting option is not supporting currently.".localized)
            }

            /*
                AutoSelectIntent
            */

            if intent is AutoSelectIntent{
                let d = (self.content as? ConverterAppDockContent)?.cellDescribers.first { describable in
                    describable.itemIdentifier == Cells.autoSelect.hashValue
                }
                d?.valueHandler?(true)
                (self.content?.view as? UITableView)?.reloadData()
            }
        }
    }

    func didLaunchHandling(with shortcutItem: UIApplicationShortcutItem) {
    }
}

private enum Cells {
    case convertingDirection
    case exportQuality
    case autoSelect
}

private extension ConvertingDirection {
    var label:String{
        return "\(from.rawValue) To \(to.rawValue)"
    }
}

class ConverterAppDockContent: NSObject, AppDockContent, AppDockDelegate
        , UITableViewDelegate, UITableViewDataSource {

    fileprivate var defaults = ConverterApp.defaults as! ConverterAppDefaults

    fileprivate var cellDescribers = [UITableViewCellDefaultDescribable]()
    fileprivate var cells = [(section: String, items: [UITableViewCellDefaultDescribable], description: String)]()

    weak var app:ConverterApp?

    required init(app:ConverterApp){
        self.app = app
    }

    lazy var view: UIView = UITableView(frame: .zero, style: .grouped)

    var contentScrollable: AppDockContentScrollable? {
        guard let scrollView = view as? UITableView else { return nil }
        return AppDockScrollableContent(scrollView)
    }

    lazy var footerView:UITextView = UITableView.createHeaderFooterViewForSmallMessage(text:"You can select only photos or videos that matched with starting format.".localized)

    var preferences: AppDockContentPreferable? {
        guard let tableView = view as? UITableView else{
            return nil
        }
        var preferences = AppDockContentPreferences()
        preferences.preferredHeight = tableView.rowHeight * 6
        return preferences
    }

    var delegate: AppDockDelegate? {
        return self
    }

    var appDock:AppDock?

    func willSetContentView(_ view:UIView, dock:AppDock) {
        appDock = dock

        view.tintColor = ConverterApp.info.themeColor

        if cellDescribers.count==0{
            reloadCellDescribers()
        }
    }

    private func createCellDescribers() -> [UITableViewCellDefaultDescribable]{
        var cellDescribers = [UITableViewCellDefaultDescribable]()

        let valueCollection = {
            return [
                UIPickerItem(component: "From", values: ConverterApp.availableConverterNames.sorted()),
                UIPickerItem(component: "To", values: ConverterApp.getAvailableConvertersNamesTo(fromRawValue:self.defaults.convertingDirection.from.rawValue).sorted()),
            ]
        }

        let from_to_cell = UITableViewMultiplePickerCellDescriber()
        from_to_cell.itemIdentifier = Cells.convertingDirection.hashValue
        from_to_cell.label = "Formats".localized
        from_to_cell.valueGetter = { (self.defaults.convertingDirection.from, self.defaults.convertingDirection.to) }
        from_to_cell.valueCollection = valueCollection
        from_to_cell.valueHandler = { value in
            guard let value = value as? (UITableViewMultiplePickerCell, Int, String) else { return }

            let cell = value.0
            let component = value.1
            let convertTypeRawValue = value.2

            if component == 0, let direction = ConverterApp.availableDirections.first(where:{ $0.from.rawValue == convertTypeRawValue }) {
                self.defaults.convertingDirection = direction
                self.app?.config?.convertingDirectionIdentifier = direction.identifier

                cell.values = valueCollection()
                cell.picker.reloadComponent(1)

                cell.setSelectedRow(cell.values[1].values.firstIndex(of: direction.to.rawValue) ?? 0, inComponent: 1, animated: true)
            }
            else if component == 1, let direction = ConverterApp.availableDirections.first(where:{ $0.from == self.defaults.convertingDirection.from && $0.to.rawValue == convertTypeRawValue }) {
                self.defaults.convertingDirection = direction
                self.app?.config?.convertingDirectionIdentifier = direction.identifier
            }
            self.reloadSection(at: 1)
        }
        cellDescribers.append(from_to_cell)

        let qualityPresets = [
            ConverterQualityPreset.low,
            ConverterQualityPreset.medium,
            ConverterQualityPreset.high,
            ConverterQualityPreset.original,
        ]

        let qualityCollection: (() -> [String]) = {
            var supportedPresets:[ConverterQualityPreset]
            if let converter = self.app?.currentConverter as? ConverterCapability.Type{
                supportedPresets = converter.supportedPresets
            }else{
                print("INFO: current converter is not defined supportedPresets")
                supportedPresets = ConverterQualityPreset.originalOnly
            }
            return supportedPresets.map { $0.rawValue }
        }

        let qualityCell = UITableViewSegmentControlCellDescriber()
        qualityCell.itemIdentifier = Cells.exportQuality.hashValue
        qualityCell.label = "Quality".localized
        qualityCell.valueCollection = qualityCollection
        qualityCell.valueGetter = { self.defaults.convertingQuality.qualityType.rawValue }
        qualityCell.valueHandler = {
            if let index = $0 as? Int {
                let direction = self.defaults.convertingDirection

                assert(qualityPresets.indices.contains(index), "given index of value in qualityPresets is not related with direction")
                let qualityType = qualityPresets.indices.contains(index) ? qualityPresets[index] : ConverterQualityPreset.original
                self.defaults.convertingQuality = ConvertingQuality(convertingDirection: direction, qualityType: qualityType)
            }
        }
        cellDescribers.append(qualityCell)


        let autoSelectCell = UITableViewSwitchSubtitleCellDescriber()
        autoSelectCell.itemIdentifier = Cells.autoSelect.hashValue
        autoSelectCell.label = "Auto Selection Bot".localized
        autoSelectCell.valueGetter = { self.defaults.autoSelect }
        autoSelectCell.iconImage = R.image.commonCellIconRobot.name
        autoSelectCell.valueHandler = { v in
            let on =  v as! Bool
            AppCenter.default.currentInstanceAs(ConverterApp.self)?.autoSelect = on
            self.defaults.autoSelect = on

            if self.defaults.autoSelect {
                papLog.app.userEnablesASB()
            }else{
                papLog.app.userDisablesASB()
            }
        }
        cellDescribers.append(autoSelectCell)

        cells = [
            ("Select Format To Convert".localized, [from_to_cell], ""),
            ("Settings".localized, [qualityCell, autoSelectCell], "")
        ]

        return cellDescribers
    }

    func didSetContentView(_ view:UIView, dock:AppDock) {
        reloadData()
    }

    func reloadCellDescribers(){
        cellDescribers = createCellDescribers()

        if let view = view as? UITableView{
            view.dataSource = self
            view.delegate = self
            view.rowHeight = 44
            view.allowsMultipleSelection = false

            for item in cellDescribers {
                view.register(describer: item)
            }
        }
    }

    func reloadData(reset:Bool=false){
        if reset{
            reloadCellDescribers()
        }
        (view as? UITableView)?.reloadData()
    }

    func reloadSection(at section: Int) {
        (self.view as? UITableView)?.reloadSections(IndexSet(integer: section), with: .automatic)
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return cells.count
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 30 : 50
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return cells[section].section
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return cells[section].description
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return section == 0 ? footerView.height : 0
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return section == 0 ? footerView : nil
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells[section].items.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = tableView.cellForRow(at: indexPath)

        if let c = cell as? UITableViewExpandableCell {
            return c.estimatedHeightForRowSelected
        }
        return tableView.rowHeight
    }


    func dockWillContract(_ dock: AppDock) {
        (self.view as? UITableView)?.contractAllVisiblePickerCells()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if let cell = tableView.cellForRow(at: indexPath) as? UITableViewExpandableCell {
            if cell.isExpanded {
                cell.contract(tableView, animated: true, completion: nil)
            } else{
                tableView.contractAllVisiblePickerCells()

                appDock?.expandDockIfNeeded(reloadContents: nil)
                DispatchQueue.main.async{
                    cell.expand(tableView, animated: true, completion: nil)
                }
            }
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = cells[indexPath.section].1[indexPath.row]

        if let cellDescriber = item as? UITableViewMultiplePickerCellDescriber
        , let valueCollection = cellDescriber.valueCollection as? (() -> [UIPickerItem])
        , let cell: UITableViewMultiplePickerCell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewMultiplePickerCell{

            cell.values = valueCollection()
            if let value = item.valueGetter() as? (ConvertingType, ConvertingType) {
                let row1 = cell.values[0].values.firstIndex(where: { $0 == value.0.rawValue }) ?? 0
                let row2 = cell.values[1].values.firstIndex(where: { $0 == value.1.rawValue }) ?? 0

                cell.setSelectedRow(row1, inComponent: 0, animated: true)
                cell.setSelectedRow(row2, inComponent: 1, animated: true)

                cell.valueLabel.text = "\(cell.values[0].values[row1]) ‣ \(cell.values[1].values[row2])"
            }
            cell.titleLabel.text = item.label
            cell.pickerDidChange = { cell, row, component, value in
                cellDescriber.valueHandler?((cell, component, value))

                cell.valueLabel.text = "\(cell.values[0].values[cell.selectedRow(for: 0)]) ‣ \(cell.values[1].values[cell.selectedRow(for: 1)])"
            }
            return cell

        }
        else if let cellDescriber = item as? UITableViewPickerCellDescriber
        , let valueCollection = cellDescriber.valueCollection as? [String]
        , let cell: UITableViewPickerCell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewPickerCell{

            cell.values = valueCollection
            cell.delegate = self as? UITableViewPickerCellDelegate
            if let value = item.valueGetter() as? String ?? valueCollection.first, let index = valueCollection.firstIndex(of: value){
                cell.selectedRow = index
            } else{
                cell.selectedRow = 0
            }
            cell.tintColor = tableView.tintColor
            cell.titleLabel.text = item.label
            cell.didPickHandler = { cell, row, value in
                cellDescriber.valueHandler?(value)
            }
            return cell

        }
        else if let cellDescriber = item as? UITableViewActionSheetCellDescriber
        , let cell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewActionSheetCell {

            cell.textLabel?.text = item.label
            cell.valueLabelText = cellDescriber.presentableValue
            cell.imageView?.image = cellDescriber.iconImage?.asUIImage
            cell.detailTextLabel?.textColor = UIColor.gray

            // valuePresenter ->
            if let presenter = cellDescriber.valuePresenter{

                //valueCollection [Any] -> [String]
                if let collection = cellDescriber.valueCollection as? [Any] {
                    cell.valueLabels = collection.map { value -> String in
                        return presenter(value)
                    }
                    cell.valueSelected = { action, index in
                        if let index = index{
                            cellDescriber.valueHandler?(collection[index])
                        }
                    }
                }
            }else{

                // valueCollection -> [String]
                if let collection = cellDescriber.valueCollection as? [String]{
                    cell.valueLabels = collection
                    cell.valueSelected = { action, index in
                        if let index = index{
                            cellDescriber.valueHandler?(collection[index])
                        }
                    }
                }
            }

            return cell
        }

        else if let cellDescriber = item as? UITableViewSwitchCellDescriber
        , let value = item.valueGetter() as? Bool
        , let cell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewSwitchCell {

            cell.textLabel?.text = item.label
            cell.detailTextLabel?.text = item.detailedLabel
            cell.switcher.setOn(value, animated: false)
            cell.switcher.onTintColor = ConverterApp.info.themeColor
            cell.imageView?.image = item.iconImage?.asUIImage?.withRenderingMode(.alwaysTemplate)
            cell.imageView?.tintColor = self.view.tintColor
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
        , let valueCollection = cellDescriber.valueCollection as? [String:Int]
        , let cell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewSegmentedControlCell{

            cell.textLabel?.text = item.label
            cell.imageView?.image = item.iconImage?.asUIImage

            cell.segmentedControl.removeAllSegments()
            for k in valueCollection{
                cell.segmentedControl.insertSegment(withTitle: k.key, at: cell.segmentedControl.numberOfSegments, animated: false)
            }

            cell.segmentedControl.selectedSegmentIndex = Array(valueCollection.values).firstIndex(of: item.valueGetter() as? Int ?? 0) ?? 0
            cell.didChangeValue = item.valueHandler
            return cell
        }
        else if let cellDescriber = item as? UITableViewSegmentControlCellDescriber
        , let valueCollection = cellDescriber.valueCollection as? (() -> [String])
        , let cell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewSegmentedControlCell {

            cell.textLabel?.text = item.label
            cell.imageView?.image = item.iconImage?.asUIImage
            cell.detailTextLabel?.textColor = UIColor.gray

            let values = valueCollection()
            cell.segmentedControl.apportionsSegmentWidthsByContent = true
            cell.segmentedControl.removeAllSegments()
            for k in values {
                cell.segmentedControl.insertSegment(withTitle: k, at: cell.segmentedControl.numberOfSegments, animated: false)
            }
            cell.segmentedControl.sizeToFit()

            if let label = item.valueGetter() as? String {
                cell.segmentedControl.selectedSegmentIndex = values.firstIndex(of: label) ?? 0
            }
            cell.didChangeValue = item.valueHandler
            return cell
        }

        let cell = tableView.cellForRow(at: indexPath) ?? UITableViewCell()
        cell.textLabel?.text = item.label
        return cell
    }
}
