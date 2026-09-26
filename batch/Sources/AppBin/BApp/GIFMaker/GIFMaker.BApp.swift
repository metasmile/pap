//
//  GIFMaker.App.swift
//  batch
//
//  Created by HYOJIN MO on 2018. 4. 23..
//  Copyright © 2018년 Stells. All rights reserved.
//

import UIKit
import Photos

//INFO: feature reference: https://ezgif.com

class _GIFMakerAppAsset: AppAsset {}

private struct GIFMakerPHAssetResult: AppTaskResultable {
    var asset: PHAsset
    var result: [PHAssetEditingResultItem]?
    var orderedIndex: Int?
}

//MARK: -

protocol GIFMakerDefaults: AppDefaults{
    var sourceType: Int {get set}
    var aspectRatio: Double {get set}
    var contentMode: PHImageContentMode {get set}
    var frameDelay: Double {get set}
    var size: Double {get set}
    var direction: Int {get set}
    var gifQuality: Double {get set}
    var loopCount: Int {get set}
    var stabilization: ImageAlignment.StabilizationMode {get set}
}

extension Defaults: GIFMakerDefaults {
    var sourceType: Int {
        set { set(newValue); papLog.app.defaults.log(value:newValue) }
        get { return get(or: 0) }
    }

    var aspectRatio: Double {
        set{ set(newValue); papLog.app.defaults.log(value:newValue) }
        get{ return get(or: 1) }
    }

    var contentMode: PHImageContentMode {
        set{ set(newValue.rawValue); papLog.app.defaults.log(value:newValue) }
        get{ return PHImageContentMode(rawValue: get(or: PHImageContentMode.aspectFit.rawValue)) ?? PHImageContentMode.aspectFit }
    }

    var frameDelay: Double {
        set { set(newValue); papLog.app.defaults.log(value:newValue) }
        get { return get(or: 0.05)}
    }

    var size: Double {
        set{ set(newValue); papLog.app.defaults.log(value:newValue) }
        get{ return get(or: 640 ) }
    }

    var direction: Int {
        set { set(newValue); papLog.app.defaults.log(value:newValue) }
        get { return get(or: 0) }
    }

    var gifQuality: Double {
        set{ set(newValue); papLog.app.defaults.log(value:newValue) }
        get{ return get(or: 0.8) }
    }

    var loopCount: Int {
        set { set(newValue); papLog.app.defaults.log(value:newValue) }
        get { return get(or: 0)}
    }

    var stabilization: ImageAlignment.StabilizationMode {
        set { set(newValue.rawValue); papLog.app.defaults.log(value:newValue.rawValue) }
        get { return ImageAlignment.StabilizationMode(rawValue: get(or: 0)) }
    }
}

struct GIFMakerSettings {
    struct sourceType {
        enum type: Int {
            case photo
            case burst
            case livePhoto
            case video
        }

        static let labels: [type: String] = [
            .photo: "Photos".localized,
            .burst: "Burst".localized,
            .livePhoto: "Live Photo".localized,
            .video: "Video".localized
        ]

        static let orderedLabels: [String?] = [
            labels[.photo],
            labels[.burst],
            labels[.livePhoto],
//            labels[.video]
        ]

        static func key(with value: String) -> Int {
            return (labels.first(where: { value == $0.value })?.key ?? .photo).rawValue
        }
    }

    struct aspectRatio {
        struct labels {
            static let square = "Square".localized
            static let w4h3 = "4:3"
            static let w16h9 = "16:9"
            static let w3h4 = "3:4"
            static let w9h16 = "9:16"
        }

        static let values: [String: Double] = [
            labels.square: 1.0,
            labels.w3h4: 3.0 / 4.0,
            labels.w9h16: 9.0 / 16.0,
            labels.w4h3: 4.0 / 3.0,
            labels.w16h9: 16.0 / 9.0
        ]

        static let orderedLabels: [String] = [
            labels.w9h16,
            labels.w3h4,
            labels.square,
            labels.w4h3,
            labels.w16h9
        ]

        static func value(_ key: String) -> Double {
            return values[key] ?? 1.0
        }
    }

    struct contentMode {
        static let fit = PHImageContentMode.aspectFit.rawValue
        static let fill = PHImageContentMode.aspectFill.rawValue

        static let labels: [PHImageContentMode: String] = [
            PHImageContentMode.aspectFit: "No Crop".localized,
            PHImageContentMode.aspectFill: "Crop".localized
        ]

        static let orderedLabels: [String?] = [
            labels[PHImageContentMode.aspectFill],
            labels[PHImageContentMode.aspectFit],
        ]

        static func key(with value: String) -> PHImageContentMode {
            return labels.first(where: { value == $0.value })?.key ?? PHImageContentMode.aspectFill
        }
    }

    // https://en.wikipedia.org/wiki/Graphics_display_resolution
    struct size {
        struct labels {
            static let nhd = "nHD (640×360)"
            static let qhd = "qHD (960×540)"
            static let hd = "HD (1280×720)"
            static let fhd = "1080p (1920×1080)"
            static let qvga = "QVGA (320×240)"
            static let hvga = "HVGA (480×320)"
        }

        static let values: [String: Double] = [
            labels.nhd: 640,
            labels.qhd: 960,
            labels.hd: 1280,
            labels.fhd: 1920,
            labels.qvga: 320,
            labels.hvga: 480
        ]

        static let orderedLabels: [String] = [
            labels.qvga,
            labels.hvga,
            labels.nhd,
            labels.qhd,
            labels.hd,
            labels.fhd,
        ]

        static func value(_ key: String) -> Double {
            return values[key] ?? 640
        }

        static func sizeWithAspectRatio() -> CGSize {
            let size = (GIFMakerApp.defaults as! GIFMakerDefaults).size
            let aspectRatio = (GIFMakerApp.defaults as! GIFMakerDefaults).aspectRatio
            if aspectRatio < 1 {
                return CGSize(width: Int(size * aspectRatio), height: Int(size))
            }
            else {
                return CGSize(width: Int(size), height: Int(size / aspectRatio))
            }
        }
    }

    struct direction {
        enum type: Int {
            case forward
            case reverse
            case rewind
        }

        static let labels: [type: String] = [
            .forward: "Forward".localized,
            .reverse: "Reverse".localized,
            .rewind: "Rewind".localized
        ]

        static let orderedLabels: [String?] = [
            labels[.forward],
            labels[.reverse],
            labels[.rewind]
        ]

        static func key(with value: String) -> Int {
            return (labels.first(where: { value == $0.value })?.key ?? .forward).rawValue
        }
    }

    struct stabilization {
        static let none: ImageAlignment.StabilizationMode = .none
        static let translation: ImageAlignment.StabilizationMode = [.translation, .crop]
        static let homographic: ImageAlignment.StabilizationMode = [.homographic, .crop]

        static let labels: [ImageAlignment.StabilizationMode: String] = [
            stabilization.none: "None".localized,
            stabilization.translation: "Mode T".localized,
            stabilization.homographic: "Mode H".localized
        ]

        static let orderedLabels: [String?] = [
            labels[stabilization.none],
            labels[stabilization.translation],
            labels[stabilization.homographic],
        ]

        static func key(with value: String) -> ImageAlignment.StabilizationMode {
            return labels.first(where: { value == $0.value })?.key ?? stabilization.none
        }
    }
}

//MARK: -

public class GIFMakerAppConfigValue: NSObject, PropertyWatchable, AppConfigUIAttributeValuable, AppConfigAdoptableValuable {
    @objc dynamic
    public var tintColor: UIColor?

    @objc dynamic
    public var sourceType: Int = Int.max

    public func adoptValues(fromOther: AppConfigValuable) {
        if let other = fromOther as? AppConfigUIAttributeValuable {
            self.tintColor = other.tintColor
        }
    }
}

public class GIFMakerApp: BApp,
        ConfigurableApp, _ConfigurableApp
        , AppDockApp
        , FinalizableApp
        , PHAssetFinalizableApp
        , PhotoPickerCollectionViewDelegatableApp
        , PhotoPickerViewControllerAppearanceDelegatableApp
        , PreheatableApp
         {

    public static let taskType: AppTaskable.Type = _GIFMakerAppTask.self
    public static let paramType: AppTaskParamable.Type = _GIFMakerAppAsset.self

    public static var defaultConfigValue: AppConfigValuable {
        let config = GIFMakerAppConfigValue()
        config.tintColor = .black
        return config
    }

    @objc dynamic
    public private(set) lazy var config: GIFMakerAppConfigValue? = type(of: self).defaultConfigValue as? GIFMakerAppConfigValue

    public private(set) lazy var content: AppDockContent? = GIFMakerAppDockContent()

    public static let info = AppInfo(
        identifier: "com.stells.batch.gifmaker"
        , version: "1.1"
        , phase: .release
        , appType: GIFMakerApp.self
        , displayName: "GIF Maker".localized
        , description: "GIF Maker allows for easily and quickly making GIF images from Photos or Live Photos with various options! And then you can open the converter app to convert into everything such as Live Photos or Videos.".localized
        , keywords: ["GIF Maker", "Live Photos", "GIF Editor", "GIF", "Video Converter", "Burst Photos","Animated GIF", "Animation", "Aspect Ratio","Repeatation"]
        , icon: AppIcon(source: R.image.gifMakerBAppIcon.name, style: .original)
        , themeColor: UIColor(red:0.22, green:0.75, blue:0.31, alpha:1), policy: AppPolicy.default
        , minOSVersion: nil
    )

    required public init() {}

    public var doneButtonTitle: String? {
        return "Make GIF".localized
    }

    public func shouldSelect(item: AppAsset) -> Bool {
        return (content as? GIFMakerAppDockContent)?.shouldImport(asset: item.asset) ?? false
    }

    public func performPreheating(item: PHAssetParamable,  _ async: AsyncWaitSignalable)  -> PreheatingFinishAction? {
        return nil
    }

    public var numberOfItemsShouldSelect: Int? {
        switch GIFMakerSettings.sourceType.type(rawValue: (GIFMakerApp.defaults as! GIFMakerDefaults).sourceType) {
        case .photo?: return Int.max
        case .burst?: return Int.max
        case .livePhoto?: return Int.max
        default: return Int.max
        }
    }

    public func setConfigValues<T: AppConfigValuable>(_ config:T){
        self.config?.adoptValues(fromOther: config)
    }

    public func finalize(result: [AppTaskRespondable], _ asyncSignal: AsyncWaitSignalable) -> [AppTaskRespondable] {
        let resultItems = result
            .filter { respondable in respondable.info.state == .completed }
            .compactMap { ($0.result as? GIFMakerPHAssetResult) }
            .sorted { ($0.orderedIndex ?? 0) < ($1.orderedIndex ?? 0) }

        let defaults =  (GIFMakerApp.defaults as! GIFMakerDefaults)
        var results = [PHAssetResultItem]()

        switch GIFMakerSettings.sourceType.type(rawValue: (GIFMakerApp.defaults as! GIFMakerDefaults).sourceType) {
            case .photo?:
                let targetSize = GIFMakerSettings.size.sizeWithAspectRatio()

                var referenceImage: UIImage?

                let urls = resultItems.compactMap({ item -> URL? in
                    return autoreleasepool {
                        guard let url = item.result?.url(for: .photo), let image = UIImage(contentsOfFile: url.path)?.stabilize(with: referenceImage, mode: defaults.stabilization) else { return nil }
                            referenceImage = image

                        let cachedAsset = LocalCachedAsset(item.asset, image: image, targetSize: targetSize, imageQuality: CGFloat(defaults.gifQuality))
                        return cachedAsset.imageFileURL
                    }
                })

                if let url = UIImageGIFRepresentationURL(with: GifConverterDefaultOption.URLs(urls: urls, with: defaults.direction), loopCount: defaults.loopCount, frameDelay: defaults.frameDelay, cancellation: { result.contains(where: { $0.info.state == .cancelled }) == true }, progressHandler: { progress in AppAssetItemProgressNotification.update(progress: progress) }) {
                    results.append(PHAssetResultItem(asset: AppAsset(PHAsset()), editingResultItems: [PHAssetEditingResultItem(url, .photo)]))
                }
            default: results.append(contentsOf: resultItems.map({ PHAssetResultItem(asset: AppAsset($0.asset), editingResultItems: $0.result) }))
        }

        let success = showingActionsAndWait(targetResultAssets: results, excludedActions: [.modify], asyncSignal)
        result.forEach {
            $0.info.userInfo[AppTaskInfo.UserInfo.Key.removedOnCompletion] = success
        }

        return result
    }
}

private class _GIFMakerAppTask: AppTaskPrototype, AppTaskable {
    public typealias ParamType = _GIFMakerAppAsset
    public typealias ResultType = PHAssetResultItem

    public func cancel(_ param: AppTaskParamable, _ async: AsyncWaitSignalable){
        (param as? _GIFMakerAppAsset)?.cancelAllRequestIDs()
    }

    public func perform(_ param: AppTaskParamable, _ async: AsyncWaitSignalable) throws -> AppTaskResultable? {
        guard let appAsset = param as? AppAsset else { return nil }
        return try _perform(appAsset, async)
    }

    private func _perform(_ assetItem: AppAsset, _ async: AsyncWaitSignalable) throws -> GIFMakerPHAssetResult?  {
        var result: GIFMakerPHAssetResult?

        let defaults = (GIFMakerApp.defaults as! GIFMakerDefaults)

        switch GIFMakerSettings.sourceType.type(rawValue: (GIFMakerApp.defaults as! GIFMakerDefaults).sourceType) {
        case .photo?:
            let targetSize = GIFMakerSettings.size.sizeWithAspectRatio()
            let contentMode = defaults.contentMode

            let response = assetItem.asset.requestImage(targetSize: targetSize, contentMode: contentMode, async)

            if let image = response.1 {
                var data: Data?
                var fileExtension = "jpg"
                switch assetItem.asset.uniformTypeIdentifier {
                case UTCoreTypes.PNG:
                    data = image.pngData()
                    fileExtension = "png"
                default:
                    data = image.jpegData(compressionQuality: CGFloat(defaults.gifQuality))
                }

                let identifier = UUID().uuidString
                let url = FileURL.temp("\(identifier).\(fileExtension)", group:String(describing: LocalCachedAsset.self)+FileURL.queuePrivateGroup())

                try? data?.write(to: url)

                result = GIFMakerPHAssetResult(asset: assetItem.asset, result: [PHAssetEditingResultItem(url, .photo)], orderedIndex: AppAssets.selected.index(of: assetItem))

                assetItem.appendRequestId(PHAssetRequestID(forImage:response.0))
            }
        case .burst?:
            let converter = GifConverter_Burst()
            converter.options = GifConverterDefaultOption(aspectRatio: defaults.aspectRatio, contentMode: defaults.contentMode, frameDelay: defaults.frameDelay, size: defaults.size, direction: defaults.direction, gifQuality: defaults.gifQuality, loopCount: defaults.loopCount, stabilizationMode: defaults.stabilization)

            if let convertedResult = converter.convert(source: assetItem, cancellation: { self.info.state == .cancelled }, progressHandler: { progress in AppAssetItemProgressNotification.update(item: assetItem, progress: progress) }, async) {
                result = GIFMakerPHAssetResult(asset: assetItem.asset, result: convertedResult, orderedIndex: AppAssets.selected.index(of: assetItem))
            }
        case .livePhoto?:
            let converter = GifConverter_LivePhoto()
            converter.options = GifConverterDefaultOption(aspectRatio: defaults.aspectRatio, contentMode: defaults.contentMode, frameDelay: defaults.frameDelay, size: defaults.size, direction: defaults.direction, gifQuality: defaults.gifQuality, loopCount: defaults.loopCount, stabilizationMode: defaults.stabilization)

            if let convertedResult = converter.convert(source: assetItem, cancellation: { self.info.state == .cancelled }, progressHandler: { progress in AppAssetItemProgressNotification.update(item: assetItem, progress: progress) }, async) {
                result = GIFMakerPHAssetResult(asset: assetItem.asset, result: convertedResult, orderedIndex: AppAssets.selected.index(of: assetItem))
            }
        default: break
        }

        return result
    }
}

private enum Cells {
    case sourceType
    case export
    case contentMode
    case aspectRatio
    case size
    case frameDelay
    case direction
    case gifQuality
    case loopCount
    case stabilization
}

class GIFMakerAppDockContent: NSObject, PropertyWatchable, AppDockContent, AppDockDelegate,
        UITableViewDelegate, UITableViewDataSource, UITableViewPickerCellDelegate {

    private var defaults = GIFMakerApp.defaults as! GIFMakerDefaults

    lazy var view: UIView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.tintColor = GIFMakerApp.info.themeColor
        return tableView
    }()

    var contentScrollable: AppDockContentScrollable? {
        guard let scrollView = view as? UITableView else { return nil }
        return AppDockScrollableContent(scrollView)
    }

    var preferences: AppDockContentPreferable? {
        guard let tableView = view as? UITableView else{
            return nil
        }
        var preferences = AppDockContentPreferences()
        preferences.preferredHeight = tableView.rowHeight * 5 + 27
        return preferences
    }

    func shouldImport(asset: PHAsset) -> Bool {
        switch GIFMakerSettings.sourceType.type(rawValue: defaults.sourceType) {
        case .photo?: return asset.mediaType == .image // live photo and burst as a photo
        case .burst?: return asset.imageType == .burst
        case .livePhoto?: return asset.imageType == .livePhoto
        default: return false
        }
    }

    var appDock:AppDock?

    func willSetContentView(_ view: UIView, dock: AppDock) {
        appDock = dock

        if sections.count==0{
            let cellDescribers = createCellDescribers()

            if let view = view as? UITableView{
                view.dataSource = self
                view.delegate = self
                view.rowHeight = 44

                for item in cellDescribers {
                    view.register(describer: item)
                }
            }
        }
    }

    private var sections = [(String, [UITableViewCellDefaultDescribable])]()

    private func createCellDescribers() -> [UITableViewCellDefaultDescribable] {
        var cellDescribers = [UITableViewCellDefaultDescribable]()

        let sourceTypeCell = UITableViewSegmentControlCellDescriber()
        sourceTypeCell.itemIdentifier = Cells.sourceType.hashValue
        sourceTypeCell.label = "Import".localized
        sourceTypeCell.valueGetter = { GIFMakerSettings.sourceType.labels[GIFMakerSettings.sourceType.type(rawValue: self.defaults.sourceType) ?? .photo] }
        sourceTypeCell.valueCollection = GIFMakerSettings.sourceType.orderedLabels
        sourceTypeCell.valueHandler = {
            if let index = $0 as? Int {
                let key = GIFMakerSettings.sourceType.key(with: GIFMakerSettings.sourceType.orderedLabels[index] ?? "")
                self.defaults.sourceType = key
                AppCenter.default.currentInstanceAs(GIFMakerApp.self)?.config?.sourceType = key
            }
        }
        cellDescribers.append(sourceTypeCell)

        let exportCell = UITableViewSegmentControlCellDescriber()
        exportCell.itemIdentifier = Cells.export.hashValue
        exportCell.label = "Export".localized
        exportCell.valueGetter = { "Animated GIF".localized }
        exportCell.valueCollection = ["Animated GIF".localized]
        cellDescribers.append(exportCell)

        let cell0 = UITableViewActionSheetCellDescriber()
        cell0.itemIdentifier = Cells.size.hashValue
        cell0.label = "Size".localized
        cell0.valueGetter =  {
            GIFMakerSettings.size.values.first(where: { $0.value == self.defaults.size })?.key
        }
        cell0.valueCollection = GIFMakerSettings.size.orderedLabels
        cell0.valueHandler = { value in
            if let key = value as? String, let sizeValue = GIFMakerSettings.size.values[key]{
                self.defaults.size = sizeValue

                guard let indexPath = self.indexPath(with: cell0.itemIdentifier) else { return }
                (self.view as? UITableView)?.reloadRows(at: [indexPath], with: .none)
            }
        }
        cellDescribers.append(cell0)

        let cell1 = UITableViewActionSheetCellDescriber()
        cell1.itemIdentifier = Cells.aspectRatio.hashValue
        cell1.label = "Aspect Ratio".localized
        cell1.valueGetter =  {
            GIFMakerSettings.aspectRatio.values.first(where: { $0.value == self.defaults.aspectRatio })?.key
        }
        cell1.valueCollection = GIFMakerSettings.aspectRatio.orderedLabels
        cell1.valueHandler = { value in
            if let key = value as? String, let sizeValue = GIFMakerSettings.aspectRatio.values[key]{
                self.defaults.aspectRatio = sizeValue
            }
        }
        cellDescribers.append(cell1)

        let cell2 = UITableViewSegmentControlCellDescriber()
        cell2.itemIdentifier = Cells.contentMode.hashValue
        cell2.label = "Crop to Fit".localized
        cell2.valueGetter = { GIFMakerSettings.contentMode.labels[self.defaults.contentMode] }
        cell2.valueCollection = GIFMakerSettings.contentMode.orderedLabels
        cell2.valueHandler = {
            if let index = $0 as? Int {
                let key = GIFMakerSettings.contentMode.key(with: GIFMakerSettings.contentMode.orderedLabels[index] ?? "")
                self.defaults.contentMode = key
            }
        }
        cellDescribers.append(cell2)


        let cell3 =  UITableViewStepperCellDescriber()
        cell3.label = "Frame Delay".localized
        cell3.itemIdentifier = Cells.frameDelay.hashValue
        cell3.valueGetter = { Int(self.defaults.frameDelay * 1000) }
        cell3.valueHandler = {
            self.defaults.frameDelay = ($0 as? Double ?? 50) / 1000
            self.updateFrameDelayPreview()
        }
        cell3.minimumValue = 50
        cell3.maximumValue = 3000
        cell3.stepValue = 50
        cell3.valuePresenter = { value in
            var label:String?
            if let val = value as? Double {
                label = String(format: "%.02f", val / 1000)
            }
            else if let val = value as? Int {
                label = String(format: "%.02f", Double(val) / 1000)
            }
            return (label ?? "-")+"s"
        }
        cellDescribers.append(cell3)

        let qualityCell =  UITableViewStepperCellDescriber()
        qualityCell.label = "Image Quality".localized
        qualityCell.itemIdentifier = Cells.gifQuality.hashValue
        qualityCell.valueGetter = { Int((self.defaults.gifQuality ) * 100) }
        qualityCell.valueHandler = {
            self.defaults.gifQuality = (($0 as? Double) ?? 1)/100
        }
        qualityCell.minimumValue = 10
        qualityCell.maximumValue = 100
        qualityCell.stepValue = 10
        qualityCell.valuePresenter = UITableViewStepperCellDescriber.percentageAsIntValuePresenter
        cellDescribers.append(qualityCell)

        let directionCell = UITableViewActionSheetCellDescriber()
        directionCell.itemIdentifier = Cells.direction.hashValue
        directionCell.label = "Direction".localized
        directionCell.valueGetter = {
            GIFMakerSettings.direction.labels[GIFMakerSettings.direction.type(rawValue: self.defaults.direction) ?? .forward]
        }
        directionCell.valueCollection = GIFMakerSettings.direction.orderedLabels
        directionCell.valueHandler = {
            if let value = $0 as? String {
                self.defaults.direction = GIFMakerSettings.direction.key(with: value)
            }
        }
        cellDescribers.append(directionCell)

        let loopCell =  UITableViewStepperCellDescriber()
        loopCell.label = "Repeat".localized
        loopCell.itemIdentifier = Cells.loopCount.hashValue
        loopCell.valueGetter = { self.defaults.loopCount }
        loopCell.valueHandler = { self.defaults.loopCount = Int($0 as? Double ?? 0) }
        loopCell.minimumValue = 0
        loopCell.maximumValue = 100
        loopCell.stepValue = 1
        loopCell.valuePresenter = { value in
            var count:Int = 0
            if let val = value as? Int {
                count = val
            }
            else if let val = value as? Double {
                count = Int(val)
            }

            if count > 0 {
                if count == 1 {
                    return "No loop".localized
                }
                else {
                    return "%d times".localizedFormatted(Int(count))
                }
            }
            else {
                return "Loop".localized
            }
        }
        cellDescribers.append(loopCell)

        let stabilizationCell = UITableViewSegmentControlCellDescriber()
        stabilizationCell.itemIdentifier = Cells.stabilization.hashValue
        stabilizationCell.label = "Shake Reduction".localized
        stabilizationCell.valueGetter = { GIFMakerSettings.stabilization.labels[self.defaults.stabilization] }
        stabilizationCell.valueCollection = GIFMakerSettings.stabilization.orderedLabels
        stabilizationCell.valueHandler = {
            if let index = $0 as? Int {
                let key = GIFMakerSettings.stabilization.key(with: GIFMakerSettings.stabilization.orderedLabels[index] ?? "")
                self.defaults.stabilization = key
            }
        }
        cellDescribers.append(stabilizationCell)

        sections.append(("GIF Maker".localized, [sourceTypeCell, exportCell]))
        sections.append(("Quality".localized, [cell0, cell1, qualityCell, cell2]))
        sections.append(("Animation".localized, [cell3, directionCell, loopCell]))
        sections.append(("Advanced".localized, [stabilizationCell]))

        return cellDescribers
    }

    var delegate: AppDockDelegate? {
        return self
    }

    func dockWillContract(_ dock: AppDock) {
        (self.view as? UITableView)?.contractAllVisiblePickerCells()
    }

    func didSetContentView(_ view:UIView, dock:AppDock) {
        (view as? UITableView)?.reloadData()
        updateFrameDelayPreview()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].1.count
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30/**/
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = tableView.cellForRow(at: indexPath)

        if let c = cell as? UITableViewPickerCell {
            return c.estimatedHeightForRowSelected
        }
        return tableView.rowHeight
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
        let item = self.sections[indexPath.section].1[indexPath.item]

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

            if item.itemIdentifier == Cells.size.hashValue {
                let size = GIFMakerSettings.size.sizeWithAspectRatio()
                cell.titleLabel.text = "\("Size".localized) (\(Int(size.width)) x \(Int(size.height)))"
            }
            else {
                cell.titleLabel.text = item.label
            }
            return cell
        }
        else if let cellDescriber = item as? UITableViewActionSheetCellDescriber
        , let cell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewActionSheetCell {

            if item.itemIdentifier == Cells.size.hashValue {
                let size = GIFMakerSettings.size.sizeWithAspectRatio()
                cell.textLabel?.text = "\("Size".localized) (\(Int(size.width)) x \(Int(size.height)))"
            }
            else {
                cell.textLabel?.text = item.label
            }

            cell.valueLabelText = cellDescriber.presentableValue
            cell.imageView?.image = cellDescriber.iconImage?.asUIImage
            cell.detailTextLabel?.textColor = UIColor.gray

            // valueCollection -> [String]
            if let collection = cellDescriber.valueCollection as? [String]{
                cell.valueLabels = collection
                cell.valueSelected = { action, index in
                    if let index = index{
                        cellDescriber.valueHandler?(collection[index])
                    }
                }
            }

            return cell
        }
        else if let cellDescriber = item as? UITableViewSegmentControlCellDescriber
            , let valueCollection = cellDescriber.valueCollection as? [String]
            , let cell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewSegmentedControlCell {

            cell.textLabel?.text = item.label
            cell.imageView?.image = item.iconImage?.asUIImage
            cell.detailTextLabel?.textColor = UIColor.gray

            cell.segmentedControl.apportionsSegmentWidthsByContent = true
            cell.segmentedControl.removeAllSegments()
            for k in valueCollection{
                cell.segmentedControl.insertSegment(withTitle: k, at: cell.segmentedControl.numberOfSegments, animated: false)
            }
            cell.segmentedControl.sizeToFit()

            if let label = item.valueGetter() as? String {
                cell.segmentedControl.selectedSegmentIndex = valueCollection.firstIndex(of: label) ?? 0
            }
            cell.didChangeValue = item.valueHandler
            return cell
        }
        else if let cellDescriber = item as? UITableViewStepperCellDescriber
            , let value = item.valueGetter() as? Int
            , let cell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewStepperCell {

            cell.textLabel?.text = item.label
            cell.detailTextLabel?.text = cellDescriber.valuePresenter?(value)
            cell.imageView?.image = item.iconImage?.asUIImage

            cell.stepper.stepValue = cellDescriber.stepValue
            cell.stepper.minimumValue = cellDescriber.minimumValue
            cell.stepper.maximumValue = cellDescriber.maximumValue
            cell.stepper.value = Double(value)

            cell.textLabel?.isEnabled = true
            cell.detailTextLabel?.isEnabled = true
            cell.stepper.isEnabled = true
            cell.stepper.tintColor = self.view.tintColor
            cell.isUserInteractionEnabled = true

            cell.didChangeValue = { value in
                cell.detailTextLabel?.text = cellDescriber.valuePresenter?(value)
                item.valueHandler?(value)
            }

            if item.itemIdentifier == Cells.frameDelay.hashValue {
                updateFrameDelayPreview(cell:cell)
            }

            return cell
        }
        else {
            return UITableViewCell()
        }
    }

    private func indexPath(with itemIdentifier: Int) -> IndexPath? {
        return sections.enumerated().compactMap({ (idx, section) -> IndexPath? in
            guard let row = section.1.firstIndex(where: { (describer) -> Bool in
                describer.itemIdentifier == itemIdentifier
            }), row != NSNotFound else { return nil }
            return IndexPath(row: row, section: idx)
        }).first
    }

    private func updateFrameDelayPreview(cell:UITableViewStepperCell?=nil) {
        guard let indexPath = indexPath(with: Cells.frameDelay.hashValue) else { return }
        guard let cell = cell ?? (view as? UITableView)?.cellForRow(at: indexPath) else { return }

        let frames = 4

        let durationNeeded = TimeInterval(Double(frames) * self.defaults.frameDelay)

        if let imageView = cell.imageView, imageView.image?.duration != durationNeeded {

            let images = [ // already cached by main bundle.
                R.image.gifmaker_preview_frame_0()!,
                R.image.gifmaker_preview_frame_1()!,
                R.image.gifmaker_preview_frame_2()!,
                R.image.gifmaker_preview_frame_3()!
            ]
            assert(images.count == frames)
            imageView.image = UIImage.animatedImage(with: images, duration: durationNeeded)
        }

        cell.imageView?.startAnimating()
        cell.setNeedsLayout()
    }

    func pickerCell(_ cell: UITableViewPickerCell, didPick row: Int, value: Any) {
        guard let indexPath = (view as? UITableView)?.indexPath(for: cell) else { return }

        let setting = sections[indexPath.section].1[indexPath.row]

        var needsToUpdateSizeCell = false

        if setting.itemIdentifier == Cells.aspectRatio.hashValue {
            defaults.aspectRatio = GIFMakerSettings.aspectRatio.values[cell.values[row]] ?? GIFMakerSettings.aspectRatio.value(GIFMakerSettings.aspectRatio.labels.square)

            needsToUpdateSizeCell = true

        }
        else if setting.itemIdentifier == Cells.size.hashValue {
            defaults.size = GIFMakerSettings.size.values[cell.values[row]] ?? GIFMakerSettings.size.value(GIFMakerSettings.size.labels.qhd)

            needsToUpdateSizeCell = true
        }

        if needsToUpdateSizeCell, let indexPathOfSizeSetting = self.indexPath(with: Cells.size.hashValue) {
            if let sizeCell = (view as? UITableView)?.cellForRow(at: indexPathOfSizeSetting) as? UITableViewPickerCell{
                let size = GIFMakerSettings.size.sizeWithAspectRatio()
                sizeCell.titleLabel.text = "\("Size".localized) (\(Int(size.width)) x \(Int(size.height)))"
            }
        }
    }
}

extension GIFMakerApp:UIApplicationDelegateLaunchableApp{}


