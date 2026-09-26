//
//? Created by BLACKGENE on 27/03/2018.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation
import Photos
import Contacts
import ContactsUI
import EventKit
import EventKitUI
import UIKit
import SafariServices

public class FinderApp: NSObject, PropertyWatchable, BApp
        , FinalizableApp
        , AppDockApp
        , PhotoPickerViewControllerAppearanceDelegatableApp
        , PhotoPickerCollectionViewDelegatableApp
        , PreheatableApp
        , LaunchableApp
        , AppPreviewActionable {

    public static let taskType: AppTaskable.Type = _FinderAppTask.self

    public static let paramType: AppTaskParamable.Type = AppAsset.self

    public private(set) lazy var content: AppDockContent? = FinderAppDockContent()

    fileprivate static let privateDefaults = FinderApp.defaults as! FinderAppDefaults

    @objc dynamic
    public lazy var autoSelect: Bool = false

    fileprivate lazy var detector = FinderAppDetector()

    public static let info = AppInfo(
            identifier: "com.stells.batch.finder"
            , version: "1.0"
            , phase: .release
            , appType: FinderApp.self
            , displayName: "Finder".localized.localizedCapitalized
            , description: "Finder enables extracting every meaningful information such as phone numbers, addresses, dates or URLs from your photos, and then call, open maps or navigate websites even search flights. You also can save them all as raw text.".localized
            , keywords: ["Date", "Address", "Maps", "Location","URL","Flight","E-Mail", "Call", "Phone Number", "Contacts","Text","Detection","Information", "Search","Find","Recognization"]
            , icon: AppIcon(source: R.image.finderBAppIcon.name, style: .original)
            , themeColor: UIColor(red:0.75, green:0.59, blue:0.99, alpha:1)
            , policy: AppPolicy.default
            , minOSVersion: nil
    )

    public required override init() {
    
    }

    class func didConfigure(with manager: AppManager) {

    }

    func didResign(current: App.Type?) {
        //replace with new instance
        self.detector = FinderAppDetector()
        self.didCancelPreheating()
    }

    private var importedLaunchOption: AppLaunchOptions?
    func didLaunch(previous: App.Type?, withOption: AppLaunchOptions?) {
        importedLaunchOption = withOption
    }

    public func shouldSelect(item: AppAsset) -> Bool {
        return item.asset.mediaType == .image
    }

    public func shouldSelectWhenInserted(indexPaths: [IndexPath]?) -> [IndexPath]? {
        if let _ = importedLaunchOption{
            return indexPaths
        }
        return nil
    }

    fileprivate var preheatCachedResults = [String:VisionTextPHAssetDetectResult]()
    private var preheatingFrontQueueLabel:String?

    func disposePreheatingCache(){
        if let l = preheatingFrontQueueLabel{
            DispatchQueue(label:l).async{
                self.preheatCachedResults.removeAll()
            }
        }else{
            preheatCachedResults.removeAll()
        }
    }

    public func performPreheating(item: PHAssetParamable,  _ async: AsyncWaitSignalable)  -> PreheatingFinishAction? {
        if self.autoSelect == false{
            return nil
        }

        (content as? PreheatableAppSubscribable)?.didStartPreheating()

        preheatingFrontQueueLabel = async.queueStack.first ?? DispatchQueue.currentLabel

        var preheatedResult:VisionTextPHAssetDetectResult?

        if let result = preheatCachedResults[item.asset.localIdentifierWithoutSplitter]{
            preheatedResult = result
        }else{
            if let image = item.asset.asUIImage{
                preheatedResult = self.detector.detectResult(asset: item.asset, image: image, async) ?? VisionTextPHAssetDetectResult(asset: item.asset)
                preheatCachedResults[item.asset.localIdentifierWithoutSplitter] = preheatedResult
            }
        }

        return FinderAppDetector.isResultFilled(result: preheatedResult)
                ? UICollectionViewPreheatableAppFinishAction.selectItem
                : nil
    }

    public func didCancelPreheating() {
        (content as? PreheatableAppSubscribable)?.didStopPreheating()
    }

    public func didFinishCurrentPreheatingCycle() {
        (content as? PreheatableAppSubscribable)?.didStopPreheating()
    }

    public func finalize(result: [AppTaskRespondable], _ asyncSignal: AsyncWaitSignalable) -> [AppTaskRespondable] {
        let items = result
                .filter { $0.info.state == .completed }
                .compactMap { $0.result as? VisionTextPHAssetDetectResult }

        var resultMessage:String?

        switch (FinderApp.privateDefaults.selectionPreset){
        case SelectionPreset.plaintext.rawValue:
            resultMessage = self.finalize_plaintext(items: items, asyncSignal)
        case SelectionPreset.contact.rawValue:
            resultMessage = self.finalize_contact(items: items, asyncSignal)
        case SelectionPreset.action.rawValue:
            resultMessage = items.handleAsAction(FinderApp.privateDefaults.quickActionOnly, asyncSignal)
        default:/**/
            assert(false, "not supported preset \(String(describing: FinderApp.privateDefaults.selectionPreset))")
        }

        if let msg = resultMessage{
            asyncSignal.begin()
            DispatchQueue.main.async {
                UIAlertController.alert(msg, completion:{ _ in
                    asyncSignal.end()
                })
            }
            asyncSignal.waitUntilEnd()
        }

        return result

    }

    public var titleWillBegin: String? {
        return "Starting To Find ...".localized
    }

    public var titleWillFinalize: String? {
        return "Waiting To Select ...".localized
    }

    public func titleDidUpdate(progress: Float) -> String? {
        return "Detecting ... %@ ".localizedFormatted("\(Int(progress * 100))%")
    }

    public var doneButtonTitle: String? {
        return "Find".localized
    }

    public var titleForAction: String? {
        return "Open In %@".localizedFormatted(MemoCamApp.info.displayName)
    }

    public func didAction(with appAsset: AppAsset) {
        if let image = appAsset.asset.asUIImage {
            var option = AppLaunchOptions(options: [AppLaunchOptionsKey.MemoCamPreviewOption: image])
            option.identifierToReturn = FinderApp.info.identifier
            
            DispatchQueue.mainAsyncIfNot {
                AppCenter.default.openApp(identifier:MemoCamApp.info.identifier, options:option)
            }
        }
    }
}


private typealias FinderAppParam = AppAsset


extension FinderApp{

    fileprivate func finalize_plaintext(items: [VisionTextPHAssetDetectResult], _ asyncSignal: AsyncWaitSignalable) -> String?{
        let strings = items.compactMap{ $0.plainText }

        if strings.count > 0 {
            asyncSignal.begin()
            DispatchQueue.main.async{
                let actionSheet = UIAlertController.actionSheet(title: nil, message: strings.joined().trimmed)

                let shareAction = UIAlertAction(title: "Share".localized, style: .default, handler: { (action) in
                    UIActivityViewController.share(activityItems: strings, excludedActivityTypes: nil) { _, _, _, _ in
                        asyncSignal.end()
                    }
                })
                shareAction.accessoryImage = R.image.commonCellIconShare()
                actionSheet.addAction(shareAction)

                if let url = VisionTextDetectResultAction_Translation.makeUrl(text: strings.joined().trimmed) {
                    let action = UIAlertAction(title: VisionTextDetectResultAction_Translation.title, style: .default, handler: { action in
                        UIApplication.openSafari(with: url, didDismiss: {
                            asyncSignal.end()
                        })
                    })
                    action.accessoryImage = VisionTextDetectResultAction_Translation.iconImage
                    actionSheet.addAction(action)
                }

                actionSheet.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: { (action) in
                    asyncSignal.end()
                }))
                UIViewController.present(actionSheet, animated: true)
            }
            asyncSignal.waitUntilEnd()
            return nil
        }

        return "Could not detect any text.".localized
    }

    fileprivate func finalize_contact(items _items: [VisionTextPHAssetDetectResult], _ asyncSignal: AsyncWaitSignalable) -> String?{
        let items = _items.filter { (item: VisionTextPHAssetDetectResult) -> Bool in
            if let contacts = item.contacts{
                return contacts.count>0
            }
            return false
        }

        var canSaveContract = items.count > 0

        if false == canSaveContract{
            return "Could not detect any contact.".localized
        }

        canSaveContract = ContactsUtil.shared.requestAuthorizationAndWait(asyncSignal)

        let errorMessage = "It could not be stored.".localized
        if false == canSaveContract{
            return errorMessage
        }

        let saveContactWithoutEdit = FinderApp.privateDefaults.saveContactWithoutEdit

        //INFO: Direct save mode
        if saveContactWithoutEdit {
            var savedCount = 0
            for item in items {
                guard let _contacts = item.contacts, _contacts.count > 0 else{
                    continue
                }

                let imageData = item.asset.requestThumbnailImage(targetSize: CGSize(width: 400, height: 400))?.asData

                for contact in _contacts{
                    autoreleasepool{
                        contact.imageData = imageData

                        let result = ContactsUtil.shared.addContacts(Contact: [contact])
                        if case ContactsUtil.ContactOperationResult.Success(response: true) = result {
                            savedCount += 1
                        }
                    }
                }
            }

            var message = errorMessage
            if savedCount > 0{
                if savedCount == items.count {
                    message = "All contacts were successfully saved.".localized
                }else if savedCount < items.count {
                    message = "Some contacts were saved, but someones were not.".localized
                }
            }
            return message
        }


        //INFO: Editor Mode
        var reviewAndDoneAtLeaseOne = false

        for item in items {
            guard let _contacts = item.contacts, _contacts.count > 0 else{
                continue
            }
            for contact in _contacts{

                autoreleasepool{
                    contact.imageData = item.asset.requestThumbnailImage(targetSize: CGSize(width: 400, height: 400))?.asData

                    asyncSignal.begin()
                    DispatchQueue.main.async{
                        CNContactViewController.presentDialog(newContact: contact, willDismiss: { contact in
                            if reviewAndDoneAtLeaseOne == false{
                                reviewAndDoneAtLeaseOne = contact != nil
                            }

                        }, didDismiss: {
                            asyncSignal.end()
                        })
                    }
                    asyncSignal.waitUntilEnd()
                }
            }
        }

        if reviewAndDoneAtLeaseOne {
            return "All processes you have confirmed were finished.".localized
        }

        return nil
    }
}

private struct FinderAppDetector{

    private let vision = Vision.vision()

    fileprivate static func isResultFilled(result:VisionTextPHAssetDetectResult?) -> Bool{
        let preset = FinderApp.privateDefaults.selectionPreset

        if preset == SelectionPreset.plaintext.rawValue{
            return result?.plainText?.count ?? 0 > 0
        }

        if preset == SelectionPreset.action.rawValue{
            return result?.resultGroup?.isFilled == true
        }

        if preset == SelectionPreset.contact.rawValue{
            return result?.contacts?.count ?? 0 > 0
        }

        return false
    }


    fileprivate func detectResult(asset:PHAsset, image: UIImage, _ async: AsyncWaitSignalable) -> VisionTextPHAssetDetectResult? {
        guard let visionText = vision.onDeviceTextRecognizer().detect(with: image, async) else {
            return nil
        }

        let preset = FinderApp.privateDefaults.selectionPreset
        let defaults = FinderApp.privateDefaults
        let selectedParserTypes = Set((defaults.selectedParserCollection.values).reduce([],+))

        var result = VisionTextPHAssetDetectResult(asset: asset)

        result.sourceVisionText = visionText

        // SelectionPreset.plaintext
        if preset == SelectionPreset.plaintext.rawValue{
            result.plainText = visionText.text
        }

        // SelectionPreset.contact,  SelectionPreset.action
        else if preset == SelectionPreset.contact.rawValue {
            var parser = VisionTextContactParser()
            var parserTypes:NSTextCheckingResult.CheckingType = []

            parser.parseLinkAsEmailAddress = selectedParserTypes.contains(ParserItem.Key.EmailAddress)

            if selectedParserTypes.contains(ParserItem.Key.PhoneNumber){
                parserTypes.insert(.phoneNumber)
            }

            if selectedParserTypes.contains(ParserItem.Key.URL){
                parserTypes.insert(.link)
            }

            if selectedParserTypes.contains(ParserItem.Key.Address){
                parserTypes.insert(.address)
            }

            if selectedParserTypes.contains(ParserItem.Key.Date){
                parserTypes.insert(.date)
            }

            if selectedParserTypes.contains(ParserItem.Key.FlightNumber){
                parserTypes.insert(.transitInformation)
            }

            parser.types = parserTypes

            var stackedParsedContacts = [CNMutableContact]()

            for block in visionText.blocks {

                var mergingContract:CNMutableContact?
                if stackedParsedContacts.count == 0{
                    mergingContract = CNMutableContact()
                }else{
                    mergingContract = stackedParsedContacts.last
                }

                if let mergingContract = mergingContract
                        , let parsedContract = parser.process(input: block, mergingOutput: mergingContract){
                    stackedParsedContacts.append(parsedContract)
                }
            }

            if let lastParsedContact = stackedParsedContacts.last{
                result.contacts = [lastParsedContact]
            }
        }

        else if preset == SelectionPreset.action.rawValue{

            var resultGroup = VisionTextResultGroup()

            if selectedParserTypes.contains(ParserItem.Key.EmailAddress){
                resultGroup.emails = visionText.blocks.parse(type: VisionTextEmailAddressParser.self, async)
            }

            if selectedParserTypes.contains(ParserItem.Key.PhoneNumber){
            }

            if selectedParserTypes.contains(ParserItem.Key.URL){
                if let urls = visionText.blocks.parse(type: VisionTextURLParser.self, async){
                    //excluding mail addresses
                    resultGroup.urls = urls.compactMap { $0.compactMap { $0.scheme == "mailto" ? nil : $0 }.nilEmpty }
                }
            }

            if selectedParserTypes.contains(ParserItem.Key.Address){
                resultGroup.addresses = visionText.blocks.parse(type: VisionTextAddressParser.self, async)
            }

            if selectedParserTypes.contains(ParserItem.Key.FlightNumber){
                resultGroup.flights = visionText.blocks.parse(type: VisionTextFlightNumberParser.self, async)
            }

            if selectedParserTypes.contains(ParserItem.Key.Date){
                resultGroup.dates = visionText.blocks.parse(type: VisionTextDateParser.self, async)
            }

            if selectedParserTypes.contains(ParserItem.Key.Price){
                resultGroup.currencies = visionText.blocks.parse(type: VisionTextCurrencyParser.self, async)
            }

            result.resultGroup = resultGroup

        }else{
            assert(false, "current preset mode is not supported. \(String(describing: preset))")
            return nil
        }

        return result
    }
}

private class _FinderAppTask: AppTaskPrototypeDefaultRestrictedConcurrency, AppTaskable {

    private let emailParser = VisionTextEmailAddressParser()
    public func cancel(_ param: AppTaskParamable, _ async: AsyncWaitSignalable){}

    public func perform(_ param: AppTaskParamable, _ async: AsyncWaitSignalable) throws -> AppTaskResultable? {

        guard let asset = (param as? AppAsset)?.asset else{
            return nil
        }

        if let preheatedResults = AppCenter.default.currentInstanceAs(FinderApp.self)?.preheatCachedResults
                , let result = preheatedResults[asset.localIdentifierWithoutSplitter] {
            return result

        }else if let image = asset.asUIImage{

            let detector = AppCenter.default.currentInstanceAs(FinderApp.self)?.detector
            return detector?.detectResult(asset: asset, image: image, async)
        }

        return nil
    }
}


/*

AppContent

*/

private enum SelectionPreset:Int{
    case action
    case contact
    case plaintext
}

private enum FinderAppSettingCells {
    case takePhoto
    case presets
    case autoSelect
    case saveContactWithoutEdit
    case quickActionOnly
//    case delete
}

private struct SettingsItem {
    fileprivate var key: FinderAppSettingCells
    fileprivate var label:String
    fileprivate var valueGetter:() -> Any
    fileprivate var valueCollection:Any?
    fileprivate var valueHandler:((Any) -> ())?
    fileprivate var cellDescriber: UITableViewCellDescribable //TODO: integrate all properties
    fileprivate var iconImageName:String?
}

private protocol FinderAppDefaults: AppDefaults{
    var selectedParserCollection: ParserCollection {get set}
    var selectionPreset: Int {get set}
    var saveContactWithoutEdit:Bool {get set}
    var quickActionOnly:Bool {get set}
}

extension Defaults: FinderAppDefaults {
    fileprivate var selectedParserCollection: ParserCollection {
        set{ set(newValue) }
        get{ return get(or: ParserDictionary.DefaultCollection) }
    }

    fileprivate var selectionPreset: Int {
        set{ set(newValue); papLog.app.defaults.log(value: newValue) }
        get{ return get(or: SelectionPreset.plaintext.rawValue ) }
    }

    fileprivate var saveContactWithoutEdit: Bool {
        set{ set(newValue); papLog.app.defaults.log(value:newValue) }
        get{ return get(or: false ) }
    }

    fileprivate var quickActionOnly: Bool {
        set{ set(newValue); papLog.app.defaults.log(value:newValue)  }
        get{ return get(or: false ) }
    }
}

extension FinderAppDefaults{
    fileprivate func addHandledProperty(_ dictionary:ParserDictionary.Key, _ property:ParserItem.Key){

        var immutableSelf = self
        if immutableSelf.selectedParserCollection[dictionary] == nil{
            immutableSelf.selectedParserCollection = ParserCollection()
            var p = immutableSelf.selectedParserCollection
            p[dictionary] = [property]
            immutableSelf.selectedParserCollection = p
        }else{
            if selectedParserCollection[dictionary]?.contains(property) == false{
                var p = immutableSelf.selectedParserCollection
                p[dictionary]?.append(property)
                immutableSelf.selectedParserCollection = p
            }
        }
    }

    fileprivate func removeHandledProperty(_ dictionary:ParserDictionary.Key, _ property:ParserItem.Key){

        if let index = selectedParserCollection[dictionary]?.firstIndex(of: property){
            var immutableSelf = self
            var p = immutableSelf.selectedParserCollection
            p[dictionary]?.remove(at: index)
            immutableSelf.selectedParserCollection = p
        }
    }
}

private typealias ParserCollection = [ParserDictionary.Key: [ParserItem.Key]]

private struct ParserItem {
    enum Key: Int, Codable {
        case PhoneNumber
        case EmailAddress
        case Address

        case Date
        case URL

        case FlightNumber
        case Price

        case GPSCoordinates
    }

    fileprivate var key:Key
    fileprivate var label:String
    fileprivate var iconImageBundleName:String?
}

private struct ParserDictionary {

    static let DefaultCollection: ParserCollection = [
        ParserDictionary.Key.Information: [
            ParserItem.Key.PhoneNumber
            ,ParserItem.Key.EmailAddress
            ,ParserItem.Key.Address

            ,ParserItem.Key.Date
            ,ParserItem.Key.URL
            ,ParserItem.Key.FlightNumber
            ,ParserItem.Key.Price
        ]
    ]

    enum Key: Int, Codable {
        case Information
    }

    fileprivate var key:Key
    fileprivate var label:String
    fileprivate var items:[ParserItem]
}

fileprivate class FinderAppDockContent: NSObject, AppDockContent, UITableViewDelegate, UITableViewDataSource, UITableViewPickerCellDelegate{
    private lazy var tintColor = FinderApp.info.themeColor

    fileprivate var settingCellDescribers = [UITableViewCellDefaultDescribable]()

    private var parserCollection:[ParserDictionary] {
        get{
            let preset = FinderApp.privateDefaults.selectionPreset
            if preset == SelectionPreset.plaintext.rawValue{
                return []
            }

            if preset == SelectionPreset.contact.rawValue{
                return type(of: self).defaultParserCollection.compactMap { dictionary -> ParserDictionary? in
                    var _dictionary = dictionary
                    _dictionary.items = _dictionary.items.filter { (item: ParserItem) -> Bool in
                        return item.key != ParserItem.Key.Price
                    }
                    return _dictionary
                }
            }

            return type(of: self).defaultParserCollection
        }
    }

    fileprivate static let defaultParserCollection:[ParserDictionary] = [

        ParserDictionary(key: ParserDictionary.Key.Information, label: "Detection Targets".localized,
                items: [
                    ParserItem(key: ParserItem.Key.PhoneNumber, label:"Phone Number".localized, iconImageBundleName:R.image.appActionIconPhoneNumber.name)
                    ,ParserItem(key: ParserItem.Key.EmailAddress, label:"E-mail Address".localized, iconImageBundleName:R.image.appActionIconEmail.name)
                    ,ParserItem(key: ParserItem.Key.Address, label:"Address".localized, iconImageBundleName:R.image.appActionIconLocation.name)
                    ,ParserItem(key: ParserItem.Key.Date, label:"Date".localized, iconImageBundleName:R.image.appActionIconDate.name)
                    ,ParserItem(key: ParserItem.Key.URL, label:"URL", iconImageBundleName:R.image.appActionIconURL.name)
                    ,ParserItem(key: ParserItem.Key.FlightNumber, label:"Flight Number".localized, iconImageBundleName:R.image.appActionIconFlight.name)
                    ,ParserItem(key: ParserItem.Key.Price, label:"Price".localized, iconImageBundleName:R.image.appActionIconCurrency.name)
                ])
    ]

    required public override init() {
        super.init()
    }

    private var initialSelectedIndexPaths:[IndexPath]?

    lazy var view: UIView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.tintColor = tintColor
        return tableView
    }()

    var contentScrollable: AppDockContentScrollable? {
        guard let scrollView = view as? UITableView else { return nil }
        return AppDockScrollableContent(scrollView)
    }

    lazy var footerView:UITextView = UITableView.createHeaderFooterViewForSmallMessage(text:"Currently, our AI text recognition model is only available for Alphanumeric and some special characters, and it could be affected by the current system language.".localized)

    var preferences: AppDockContentPreferable? {
        var preferences = AppDockContentPreferences()
        preferences.preferredHeight = 300
        return preferences
    }

    private var selectedParserCollection: ParserCollection{
        return FinderApp.privateDefaults.selectedParserCollection
    }

    private var autoSelect:Bool = false


    private func createCellDescriber_SelectionPreset_contact_saveContactWithoutEdit() -> UITableViewSwitchCellDescriber{
        let celld = UITableViewSwitchCellDescriber()
        celld.itemIdentifier = FinderAppSettingCells.saveContactWithoutEdit.hashValue
        celld.label = "Save Contacts".localized
        celld.valueGetter = { FinderApp.privateDefaults.saveContactWithoutEdit }
        celld.valueHandler = {
            var defaults = FinderApp.privateDefaults
            defaults.saveContactWithoutEdit = $0 as! Bool
        }
        return celld
    }

    private func createCellDescriber_SelectionPreset_action_quickActionsOnly() -> UITableViewSwitchCellDescriber{
        let celld = UITableViewSwitchCellDescriber()
        celld.itemIdentifier = FinderAppSettingCells.quickActionOnly.hashValue
        celld.label = "Enable Quick Actions".localized
        celld.valueGetter = { FinderApp.privateDefaults.quickActionOnly }
        celld.valueHandler = {
            var defaults = FinderApp.privateDefaults
            defaults.quickActionOnly = $0 as! Bool
        }
        return celld
    }

    func willSetContentView(_ view: UIView, dock: AppDock) {

        if settingCellDescribers.count>0{
            return
        }

        let cell1 = UITableViewSwitchSubtitleCellDescriber()
        cell1.itemIdentifier = FinderAppSettingCells.autoSelect.hashValue
        cell1.label = "Auto Selection Bot".localized
        cell1.valueGetter = { self.autoSelect }
        cell1.iconImage = R.image.commonCellIconRobot.name
        cell1.valueHandler = {
            self.autoSelect = $0 as! Bool
            AppCenter.default.currentInstanceAs(FinderApp.self)?.autoSelect = self.autoSelect

            if self.autoSelect{
                papLog.app.userEnablesASB()
            }else{
                papLog.app.userDisablesASB()
            }
        }
        settingCellDescribers.append(cell1)


        if AppCenter.default.apps().first(where:{ appType in appType is CameraApp.Type }) != nil{
            let cell_b = UITableViewButtonCellDescriber()
            cell_b.itemIdentifier = FinderAppSettingCells.takePhoto.hashValue
            cell_b.label = "Take A Photo".localized
            cell_b.buttonImage = R.image.systemIconCamera.name
            cell_b.valueHandler = { _ in
                var option = AppLaunchOptions()
                option.identifierToReturn = FinderApp.info.identifier
                AppCenter.default.openApp(identifier:CameraApp.info.identifier, options:option)

                papLog.app.userCalledCameraInApp()

            }
            settingCellDescribers.append(cell_b)
        }


        let cell0 = UITableViewSegmentControlCellDescriber()
        cell0.itemIdentifier = FinderAppSettingCells.presets.hashValue
        cell0.label = "Type".localized
        cell0.valueGetter = { FinderApp.privateDefaults.selectionPreset }
        cell0.valueCollection = [
            (label:"Actions".localized,value: SelectionPreset.action.rawValue),
            (label:"Contacts".localized,value: SelectionPreset.contact.rawValue),
            (label:"Text".localized,value: SelectionPreset.plaintext.rawValue)
        ]
        cell0.valueHandler = {
            let preset = $0 as! Int

            var defaults = FinderApp.privateDefaults
            defaults.selectionPreset = preset

            // selectionPreset changed -> other self.parserCollection getter will be returned.
            (view as? UITableView)?.reloadData()


            [
                FinderAppSettingCells.saveContactWithoutEdit.hashValue
                , FinderAppSettingCells.quickActionOnly.hashValue
            ].forEach { hashValue in

                if let index = self.settingCellDescribers.firstIndex(where:{ describable in
                    return describable.itemIdentifier == hashValue
                }){
                    self.settingCellDescribers.remove(at: index)
                }
            }

            let tableView = view as? UITableView

            //saveContactWithoutEdit
            if preset == SelectionPreset.contact.rawValue{
                let desc = self.createCellDescriber_SelectionPreset_contact_saveContactWithoutEdit()
                self.settingCellDescribers.append(desc)

                tableView?.register(describer: desc)
            }

            if preset == SelectionPreset.action.rawValue{
                let desc = self.createCellDescriber_SelectionPreset_action_quickActionsOnly()
                self.settingCellDescribers.append(desc)

                tableView?.register(describer: desc)
            }

            tableView?.reloadData()

            /*let d = Defaults.shared.shortVersionDescription*/
            if /*(d == .new || d == .first) && */(tableView?.numberOfSections ?? 0 > 1 && tableView?.numberOfRows(inSection: 1) ?? 0 > 1){
                tableView?.scrollToRow(at: IndexPath(item: 0, section: 1), at: .middle, animated: true)
            }

            // autoSelect turn off and restore
            cell1.valueHandler?(false)

            //remove preheating cache
            AppCenter.default.currentInstanceAs(FinderApp.self)?.disposePreheatingCache()

        }
        settingCellDescribers.append(cell0)

        //auto save
        if FinderApp.privateDefaults.selectionPreset == SelectionPreset.contact.rawValue{
            settingCellDescribers.append(createCellDescriber_SelectionPreset_contact_saveContactWithoutEdit())
        }
        else if FinderApp.privateDefaults.selectionPreset == SelectionPreset.action.rawValue{
            settingCellDescribers.append(createCellDescriber_SelectionPreset_action_quickActionsOnly())
        }

        if let tableView = view as? UITableView{
            tableView.dataSource = self
            tableView.delegate = self
            tableView.rowHeight = 44
            tableView.allowsSelection = false
            tableView.allowsMultipleSelection = false
            tableView.register(Cell.self, forCellReuseIdentifier: FinderApp.info.identifier)
            for desc in settingCellDescribers {
                tableView.register(describer: desc)
            }
        }
    }

    func didSetContentView(_ view:UIView, dock:AppDock) {

        let defaultsCollection = FinderApp.privateDefaults.selectedParserCollection

        //get indexes
        let sections = self.parserCollection.enumerated().compactMap { (section, dictionary) -> [IndexPath]? in
            if let handledItems = defaultsCollection[dictionary.key]{

                return handledItems.compactMap { key -> IndexPath? in
                    guard let item = dictionary.items.firstIndex(where: { item -> Bool in
                        return key == item.key
                    }) else{
                        return nil
                    }
                    return IndexPath(item: item, section: 1+section)
                }
            }
            return nil
        }


        //init initialSelectedIndexPaths
        initialSelectedIndexPaths = [IndexPath]()
        for indexPaths in sections{
            initialSelectedIndexPaths?.append(contentsOf: indexPaths)
        }

        (view as? UITableView)?.reloadData()

        initialSelectedIndexPaths = nil
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    }

    func tableView(_ tableView: UITableView, didEndDisplayingHeaderView view: UIView, forSection section: Int) {

    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1 + parserCollection.count
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {

        return tableView.numberOfSections-1 == section
                ? 80 //ff
                : 0
    }


    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let label_section0 = "Select Photos To Find Something.".localized
        return section == 0
                ? label_section0
                : parserCollection[section-1].label
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if tableView.numberOfSections-1 == section {
            footerView.sizeToFit()
            return footerView
        }
        return nil
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0
                ? settingCellDescribers.count
                : parserCollection[section-1].items.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = indexPath.section == 0
                ? settings_tableView(tableView, cellForRowAt: indexPath)
                : parserCollection_tableView(tableView, cellForRowAt: IndexPath(item: indexPath.item, section: indexPath.section))
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
            cell.switcher.onTintColor = FinderApp.info.themeColor
            cell.imageView?.image = item.iconImage?.asUIImage?.withRenderingMode(.alwaysTemplate)
            cell.imageView?.tintColor = self.view.tintColor
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

        let cell = tableView.cellForRow(at: indexPath) ?? UITableViewCell()
        cell.textLabel?.text = item.label
        return cell
    }

    func parserCollection_tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let dict = self.parserCollection[indexPath.section-1]

        var selected = false
        if let _ = initialSelectedIndexPaths?.firstIndex(of: indexPath) {
            selected = true
        }
        if let _ = FinderApp.privateDefaults.selectedParserCollection[dict.key]?.firstIndex(of: dict.items[indexPath.item].key){
            selected = true
        }

        let dataItem = dict.items[indexPath.item]

        let cell = tableView.dequeueReusableCell(withIdentifier: FinderApp.info.identifier) as! Cell
        cell.textLabel?.text = dataItem.label
        cell.detailTextLabel?.text = selected ? "%@ might be found".localizedFormatted("").trimmed : nil

        cell.imageView?.tintColor = self.view.tintColor
        let image = dataItem.iconImageBundleName?.asUIImageNamed
        cell.imageView?.image = image?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)

        cell.detailTextLabel?.textColor = UIColor.gray
        cell.optionSwitch.setOn(selected, animated: false)
        cell.switchDidChange = { on in

            AppCenter.default.currentInstanceAs(FinderApp.self)?.disposePreheatingCache()

            if on{
                papLog.app.defaults.log(value: String(describing: dict.items[indexPath.item].key))
                FinderApp.privateDefaults.addHandledProperty(dict.key, dict.items[indexPath.item].key)
            }else{
                FinderApp.privateDefaults.removeHandledProperty(dict.key, dict.items[indexPath.item].key)
            }

            tableView.reloadRows(at: [indexPath], with: .fade)
        }
        return cell
    }

    func pickerCell(_ cell: UITableViewPickerCell, didPick row: Int, value: Any) {

    }
}

import Intents

extension FinderApp:UIApplicationDelegateLaunchableApp{
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
                let d = (self.content as? FinderAppDockContent)?.settingCellDescribers.first { describable in
                    describable.itemIdentifier == FinderAppSettingCells.autoSelect.hashValue
                }
                d?.valueHandler?(true)
                (self.content?.view as? UITableView)?.reloadData()
            }
        }
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

        optionSwitch.onTintColor = FinderApp.info.themeColor
    }
}

extension FinderAppDockContent: PreheatableAppSubscribable{
    func prepareStatusDisplaying(label:String?){
        var desc = self.settingCellDescribers.first { describable in
            describable.itemIdentifier == FinderAppSettingCells.autoSelect.hashValue
        }
        desc?.detailedLabel = label
    }

    func didStartPreheating() {
        prepareStatusDisplaying(label: "Activating Current Visible Items ...".localized)
        self.startSelectionBotIconAnimation(self.settingCellDescribers, FinderAppSettingCells.autoSelect.hashValue)
    }

    func didStopPreheating() {

        prepareStatusDisplaying(label: self.autoSelect ? "On Standby".localized : nil)
        self.stopSelectionBotIconAnimation(self.settingCellDescribers, FinderAppSettingCells.autoSelect.hashValue)
    }
}
