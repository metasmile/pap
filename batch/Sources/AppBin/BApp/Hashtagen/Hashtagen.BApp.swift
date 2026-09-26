//
// Created by BLACKGENE on 20/02/2018.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation
import Photos
import UIKit

private typealias HashtagenAppParam = AppAsset

private extension Array where Element==String{
    func getTaggedString(separator:String="#", allowWhiteSpace:Bool=false, prefix:Bool=false) -> String{
        var sourceStrings = self
        if allowWhiteSpace == false{
            sourceStrings = sourceStrings.map{ $0.remove(" ") }
        }

        if prefix{
            return "\(separator)\(sourceStrings.joined(separator: " "+separator))".trimmed
        }else{
            return "\(sourceStrings.joined(separator: separator+" "))".trimmed
        }
    }
}

private protocol HashtagenAppDefaults: AppDefaults{
    var autoSelect: Bool {get set}
    var taggingTemplate: Int {get set}
}

extension Defaults: HashtagenAppDefaults {
    fileprivate var autoSelect: Bool {
        set{ set(newValue); }
        get{ return get(or: true) }
    }

    fileprivate var taggingTemplate:Int{
        set{ set(newValue) }
        get{ return get(or: TaggingTemplate.hashtags.rawValue) }
    }
}


public class HashtagenApp: NSObject, PropertyWatchable, BApp
        , AppDockApp
        , FinalizableApp
        , PhotoPickerViewControllerAppearanceDelegatableApp
        , PhotoPickerCollectionViewDelegatableApp
        , PreheatableApp {
    public static let taskType: AppTaskable.Type = _HashtagenAppTask.self

    public static let paramType: AppTaskParamable.Type = HashtagenAppParam.self

    public static let info = AppInfo(
            identifier: "com.stells.batch.hashtagen"
            , version: "1.0"
            , phase: .release
            , appType: HashtagenApp.self
            , displayName: "HashTag".localized
            , description: "Finding and collecting hashtags from your photos you selected.".localized
            , keywords: ["#", "Instagram", "Tag List", "Tagging", "Hashtag", "Social Network", "Twitter", "Facebook", "Digial Marketing", "Keyword"]
            , icon: AppIcon(source: R.image.hashtagenBAppIcon.name, style: .original)
            , themeColor: UIColor(rgb: 0xFF76C1)
            , policy: AppPolicy.default
            , minOSVersion: nil
    )

    fileprivate lazy var labelDetector = HashtagenAppDetector()

    public private(set) lazy var content: AppDockContent? = HashtagenAppDockContent()

    private let appDefaults = HashtagenApp.defaults as! HashtagenAppDefaults

    @objc dynamic
    public fileprivate(set) lazy var autoSelect: Bool = appDefaults.autoSelect

    required public override init(){
        super.init()
    }

    public func shouldSelect(item: AppAsset) -> Bool {
        return true
    }

    func didDeselectAll(callee: PhotoPickerViewControllerUniversalOperations) {
        self.detectingSig.done()
        (content as? HashtagenAppDockContent)?.setLabelsIfNeeded([])
    }

    func didAppear(callee:PhotoPickerViewControllerUniversalOperations) {
        (content as? HashtagenAppDockContent)?.setLabelsIfNeeded([])
    }

    func didResign(current: App.Type?) {
        self.didCancelPreheating()
    }

    private let detectingSig = AsyncSignal()
    func didSelect(asset: PHAsset, indexPath: IndexPath, callee: PhotoPickerViewControllerUniversalOperations) {
        preheatCachedResultsRWQueue.async(flags:.barrier){
            self.performDetectingTags(for: PHAssetItem(asset: asset, indexPath: indexPath), self.detectingSig, exclude:false)
        }
    }

    func didDeselect(asset: PHAsset, indexPath: IndexPath, callee: PhotoPickerViewControllerUniversalOperations) {
        preheatCachedResultsRWQueue.async(flags:.barrier){
            self.performDetectingTags(for: PHAssetItem(asset: asset, indexPath: indexPath), self.detectingSig, exclude:true)
        }
    }

    fileprivate var preheatCachedResults = [String:VisionLabelPHAssetDetectResult]()
    fileprivate lazy var preheatCachedResultsRWQueue:DispatchQueue = DispatchQueue.global(qos: .utility) //default but changed to external queue with signal.

    func disposePreheatingCache(){
        preheatCachedResultsRWQueue.async(flags:.barrier){
            self.preheatCachedResults.removeAll()
        }
    }

    public func didCancelPreheating() {
        (content as? PreheatableAppSubscribable)?.didStopPreheating()
    }

    public func didFinishCurrentPreheatingCycle() {
        (content as? PreheatableAppSubscribable)?.didStopPreheating()
    }

    public func performPreheating(item: PHAssetParamable,  _ async: AsyncWaitSignalable)  -> PreheatingFinishAction? {
        if self.autoSelect == false{
            return nil
        }

        (content as? PreheatableAppSubscribable)?.didStartPreheating()

        preheatCachedResultsRWQueue = DispatchQueue(label:async.queueStack.first ?? DispatchQueue.currentLabel)

        performDetectingTags(for: item, async)

        return nil
    }

    @discardableResult
    private func performDetectingTags(for item: PHAssetParamable, _ async: AsyncWaitSignalable, exclude:Bool=false)  -> Bool {
        var detectedResult:VisionLabelPHAssetDetectResult?

        if let r = self.preheatCachedResults[item.asset.localIdentifier]{
            detectedResult = r

        }else{
            if let r = labelDetector.detectResult(asset: item.asset, async), r.labelTextsConfidenceDescending.count > 0{
                detectedResult = r
                preheatCachedResults[item.asset.localIdentifier] = detectedResult
            }
        }

        if let r = detectedResult{
            DispatchQueue.mainAsyncIfNot {
                (self.content as? HashtagenAppDockContent)?.setLabelsIfNeeded([r], remove:exclude)
            }
        }

        return detectedResult != nil
    }

    public func finalize(result: [AppTaskRespondable], _ asyncSignal: AsyncWaitSignalable) -> [AppTaskRespondable] {

        var exportingTagStrings:String?
        let tags = (content as? HashtagenAppDockContent)?.currentTags
        let template = appDefaults.taggingTemplate

        switch (template){
            case TaggingTemplate.hashtags.rawValue:
                exportingTagStrings = tags?.getTaggedString(separator: "#", allowWhiteSpace: true, prefix: true)
            case TaggingTemplate.taglist.rawValue:
                exportingTagStrings = tags?.getTaggedString(separator: ",", allowWhiteSpace: true, prefix: false)
            default:
                break
        }

        if let _ = UIViewController.presentable, let exportingTagStrings = exportingTagStrings{
            asyncSignal.begin()
            DispatchQueue.global().async {
                UIActivityViewController.share(activityItems: [exportingTagStrings]) { (activityType: UIActivity.ActivityType?, completed: Bool, returnedItems: [Any]?, activityError: Error?) in

                    (self.content as? HashtagenAppDockContent)?.setLabelsIfNeeded([])

                    asyncSignal.end()
                }
            }
            asyncSignal.waitUntilEnd()
        }

        return result
    }

    public var titleWillBegin: String? {
        return "Starting to find...".localized
    }

    public var titleWillFinalize: String? {
        return "Finding Hashtags In Photos...".localized
    }

    public var doneButtonTitle: String? {
        return "Get Tags".localized
    }
}

private struct HashtagenAppDetector{

    private let vision = Vision.vision()

    fileprivate func detectResult(asset:PHAsset, _ async: AsyncWaitSignalable) -> VisionLabelPHAssetDetectResult? {
        var results:VisionLabelPHAssetDetectResult?

        if let image = asset.asUIImage  {
            async.begin()

            vision.onDeviceImageLabeler().process(VisionImage(image: image), completion:{ (labels,e) in
                if e == nil, let labels:[VisionImageLabel] = labels?.nilEmpty{
                    results = VisionLabelPHAssetDetectResult(asset: asset, visionLabels: labels)
                }
                async.end()
            })
            async.waitUntilEnd()
        }

        return results
    }
}

private class _HashtagenAppTask: AppTaskPrototype, AppTaskable {
    public func cancel(_ param: AppTaskParamable, _ async: AsyncWaitSignalable){}

    public func perform(_ param: AppTaskParamable, _ async: AsyncWaitSignalable) throws -> AppTaskResultable? {
        assert(param is HashtagenAppParam, "TaskParamable type of this app is \(HashtagenAppParam.self)")
        guard let _param = param as? HashtagenAppParam else{
            throw AppTaskError.invalidParam
        }
        return try self._perform(_param, async)
    }

    private func _perform(_ param: HashtagenAppParam, _ async: AsyncWaitSignalable) throws -> VisionLabelPHAssetDetectResult?  {
        if let app = AppCenter.default.currentInstanceAs(HashtagenApp.self){
            let cachedResult = app.preheatCachedResultsRWQueue.sync{ return app.preheatCachedResults[param.asset.localIdentifier] }
            return cachedResult ?? app.labelDetector.detectResult(asset: param.asset, async)
        }
        return nil
    }
}


/*
HashtagenAppDockContent
*/

private enum TaggingTemplate:Int, Codable{
    case hashtags
    case taglist
}

extension HashtagenAppDockContent: PreheatableAppSubscribable{
    func prepareStatusDisplaying(label:String?){
        var desc = self.settingCellDescribers.first { describable in
            describable.itemIdentifier == settingCellDescribers.first?.itemIdentifier
        }
        desc?.detailedLabel = label
    }

    func didStartPreheating() {
        prepareStatusDisplaying(label: "Activating Current Visible Items ...".localized)
        self.startSelectionBotIconAnimation(self.settingCellDescribers, self.settingCellDescribers.first?.itemIdentifier ?? -1)
    }

    func didStopPreheating() {
        prepareStatusDisplaying(label: defaults.autoSelect ? "On Standby".localized : nil)
        self.stopSelectionBotIconAnimation(self.settingCellDescribers, self.settingCellDescribers.first?.itemIdentifier ?? -1)
    }
}

private class IntrinsicTableView: UITableView {
    override var contentSize:CGSize {
        didSet {
            self.invalidateIntrinsicContentSize()
        }
    }
    override var intrinsicContentSize: CGSize {
        self.layoutIfNeeded()
        return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
    }
}

//TODO: threshold for confidence
fileprivate class HashtagenAppDockContent: NSObject, UITableViewPickerCellDelegate, PropertyWatchable, AppDockContent, UITableViewDelegate, UITableViewDataSource, TagListViewDelegate{
    private lazy var defaults = HashtagenApp.defaults as! HashtagenAppDefaults

    private let primaryColor = HashtagenApp.info.themeColor

    fileprivate var settingCellDescribers = [UITableViewCellDefaultDescribable]()

    private var settedLabelResults = [VisionLabelPHAssetDetectResult]()

    fileprivate var currentTags:[String]{
        return self.tagsView.tagViews.compactMap { $0.titleLabel?.text }.uniq()
    }

    fileprivate func setLabelsIfNeeded(_ settingResults:[VisionLabelPHAssetDetectResult], remove:Bool=false){
        assert(DispatchQueue.currentIsMain, "Use main queue")
        let resultsAdding = Array<VisionLabelPHAssetDetectResult>(Set(settingResults).subtracting(Set(settedLabelResults)))
        let shouldRemoveAll = settingResults.count == 0 || resultsAdding.count==0 && settedLabelResults.count == 0

        if shouldRemoveAll{
            self.settedLabelResults = []

        }else if resultsAdding.count>0, remove == false{
            self.settedLabelResults += resultsAdding

        }else if settingResults.count>0, remove{
            self.settedLabelResults = Array(Set(self.settedLabelResults).subtracting(Set(settingResults)))
        }

        let removingTags = Set(settingResults.labelTextsConfidenceDescending).subtracting(Set(self.settedLabelResults.labelTextsConfidenceDescending))
        let currentTagsSet = Set(self.currentTags)
        let addingTags = resultsAdding.labelTextsConfidenceDescending.filter{ !currentTagsSet.contains($0) }

        UIView.animate(withDuration: 0.3){
            if shouldRemoveAll{
                self.tagsView.removeAllTags()

            }else if remove{
                for l in removingTags{
                    self.tagsView.removeTag(l)
                }

            }else{
                for l in addingTags{
                    self.tagsView.addTag(l)
                }
                (self.view as? UIScrollView)?.flashScrollIndicators()
            }
        }
    }

    fileprivate lazy var tableView:UITableView = {
        let tableView = IntrinsicTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isScrollEnabled = false
        tableView.rowHeight = 52
        tableView.allowsSelection = false
        tableView.register(Cell.self, forCellReuseIdentifier: HashtagenApp.info.identifier)
//            tableView.backgroundColor = UIColor(red: 31 / 255.0, green: 31 / 255.0, blue: 31 / 255.0, alpha: 1)
        tableView.tintColor = self.primaryColor

        return tableView
    }()

    private lazy var tagsView:TagListView = {
        let tagListView = TagListView()
        tagListView.enableRemoveButton = true
        tagListView.cornerRadius = 10
        tagListView.paddingY = 6
        tagListView.paddingX = 9
        tagListView.textFont = UIFont.systemFont(ofSize: UIFont.systemFontSize)
        tagListView.alignment = .center
        tagListView.tagBackgroundColor = tagListView.colorTheme.objectBackgroundColor
        tagListView.delegate = self

        return tagListView
    }()

    func tagPressed(_ title: String, tagView: TagView, sender: TagListView) {
        tagView.isSelected = !tagView.isSelected
    }

    func tagRemoveButtonPressed(_ title: String, tagView: TagView, sender: TagListView) {
        UIView.animate(withDuration: 0.2) {
            self.tagsView.removeTagView(tagView)
        }
    }

    lazy var view: UIView = {

        let scrollView = UIScrollView()

        let stackView = UIStackView()
        scrollView.addSubview(stackView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .equalSpacing
        stackView.spacing = 5

        stackView.topAnchor.constraint(equalTo:scrollView.topAnchor).isActive = true
        stackView.leadingAnchor.constraint(equalTo:scrollView.leadingAnchor).isActive = true
        stackView.trailingAnchor.constraint(equalTo:scrollView.trailingAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo:scrollView.bottomAnchor).isActive = true
        stackView.widthAnchor.constraint(equalTo:scrollView.widthAnchor).isActive = true
        //@_@ what the?: https://stackoverflow.com/questions/31668970/is-it-possible-for-uistackview-to-scroll

        stackView.addArrangedSubview(self.tableView)
        stackView.addArrangedSubview(self.tagsView)

        return scrollView
    }()

    var contentScrollable: AppDockContentScrollable? {
        guard let scrollView = view as? UIScrollView else { return nil }
        return AppDockScrollableContent(scrollView)
    }

    var preferences: AppDockContentPreferable? {
        var preferences = AppDockContentPreferences()
        preferences.preferredHeight = tableView.rowHeight * CGFloat(4)
        return preferences
    }

    func willSetContentView(_ view: UIView, dock: AppDock) {
        if settingCellDescribers.count>0{
            return
        }

        let cell1 = UITableViewSwitchSubtitleCellDescriber()
        cell1.label = "Auto Tagging Bot".localized
        cell1.itemIdentifier = cell1.label.hashValue
        cell1.valueGetter = { self.defaults.autoSelect }
        cell1.iconImage = R.image.commonCellIconRobot.name
        cell1.valueHandler = {
            let on = $0 as! Bool
            self.defaults.autoSelect = on
            AppCenter.default.currentInstanceAs(HashtagenApp.self)?.autoSelect = on

            if on{
                papLog.app.userEnablesASB()
            }else{
                papLog.app.userDisablesASB()
            }
        }
        settingCellDescribers.append(cell1)


        //TODO: hashtag expanding from suggest api like -- https://ritekit.com/pricing/
//        let cell122 = UITableViewSwitchSubtitleCellDescriber()
//        cell122.label = "Enable Suggestion".localized
//        cell122.itemIdentifier = cell122.label.hashValue
//        cell122.valueGetter = { self.defaults.autoSelect }
////        cell122.iconImage = R.image.commonCellIconRobot.name
//        cell122.valueHandler = {
//            let on = $0 as! Bool
//        }
//        settingCellDescribers.append(cell122)


        let cell1930 = UITableViewSegmentControlCellDescriber()
        cell1930.label = "Formats".localized
        cell1930.itemIdentifier = cell1930.label.hashValue
        cell1930.valueGetter = {
            return self.defaults.taggingTemplate
        }
        cell1930.valueCollection = [
            (label:"HashTags (#)", value: TaggingTemplate.hashtags.rawValue),
            (label:"Tag List (,)", value: TaggingTemplate.taglist.rawValue)
        ]
        cell1930.valueHandler = {
            if let v = $0 as? Int {
                self.defaults.taggingTemplate = v
            }
        }

        settingCellDescribers.append(cell1930)

        for desc in settingCellDescribers {
            tableView.register(describer: desc)
        }
    }

    func didSetContentView(_ view:UIView, dock:AppDock) {
        tableView.reloadData()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingCellDescribers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: HashtagenApp.info.identifier) as! Cell

        cell.imageView?.tintColor = primaryColor
        cell.imageView?.contentMode = .scaleAspectFit


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

        else if let cellDescriber = item as? UITableViewActionSheetCellDescriber
                , let cell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewActionSheetCell {

            cell.textLabel?.text = item.label
            cell.valueLabelText = cellDescriber.presentableValue
            cell.imageView?.image = cellDescriber.iconImage?.asUIImage
            cell.detailTextLabel?.textColor = UIColor.gray
            cell.valueLabels = cellDescriber.presentableValueCollection

            if let collection = cellDescriber.valueCollection as? [Any]{
                cell.valueSelected = { action, index in
                    if let index = index{
                        cellDescriber.valueHandler?(collection[index])
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
            cell.switcher.onTintColor = self.primaryColor
            cell.imageView?.image = item.iconImage?.asUIImage?.withRenderingMode(.alwaysTemplate)
//            cell.imageView?.tintColor = self.view.tintColor
            cell.switchDidChange = item.valueHandler
            return cell
        }

        else if let cellDescriber = item as? UITableViewButtonCellDescriber
                , let cell = tableView.dequeueReusableCell(withIdentifier: cellDescriber.cellIdentifier) as? UITableViewButtonCell {

            cell.textLabel?.text = item.label

            if let buttonAsImage = cellDescriber.buttonImage?.asUIImage{
                cell.buttonFrameInset = UIEdgeInsets(top:5, left: 5, bottom: 5,right:  5)
                cell.button.setImage(buttonAsImage.withRenderingMode(.alwaysTemplate), for: .normal)
            }else if let buttonAsText = cellDescriber.buttonTitle {
                cell.button.setTitle(buttonAsText, for: .normal)
                cell.button.setTitleColor(self.view.tintColor, for: .selected)
                cell.button.setTitleColor(self.view.tintColor, for: .highlighted)
            }
            cell.button.tintColor = self.view.tintColor
            cell.imageView?.image = item.iconImage?.asUIImage?.withRenderingMode(.alwaysTemplate)
            cell.imageView?.tintColor = self.view.tintColor
            cell.didTap = {
                cellDescriber.valueHandler?(true)
            }
            cell.button.layoutIfNeeded()
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

        let emptyCell = tableView.cellForRow(at: indexPath) ?? UITableViewCell()
        emptyCell.textLabel?.text = item.label
        return emptyCell

    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func pickerCell(_ cell: UITableViewPickerCell, didPick row: Int, value: Any) {

    }

    lazy var footerView:UITextView = UITableView.createHeaderFooterViewForSmallMessage(text:"Choose some photos you want to find tags.".localized)
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if 0 == section {
            footerView.sizeToFit()
            return footerView
        }
        return nil
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

extension HashtagenApp:UIApplicationDelegateLaunchableApp{
    static var intents: [INIntent] {
        if #available(iOS 12.0, *) {

            let asb = AutoSelectIntent()
            asb.appId = info.identifier
            asb.appName = defaultIntentAppName
            asb.suggestedInvocationPhrase = "Enable Auto-tagging.".localizedFormatted(defaultIntentAppName)

            return self.defaultIntents + [asb]
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

                (content as? HashtagenAppDockContent)?.tableView.reloadData()
            }
        }

    }

    func didLaunchHandling(with shortcutItem: UIApplicationShortcutItem) {
    }
}
