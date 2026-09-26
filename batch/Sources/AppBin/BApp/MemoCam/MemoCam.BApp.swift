//
//  MMCMemoCam.BApp.swift
//  pap
//
//  Created by HYOJIN MO on 2018. 7. 17..
//  Copyright © 2018년 Stells. All rights reserved.
//

import UIKit
import Vision
import AVFoundation

private class _MemoCamAppTask: AppTaskPrototype, AppTaskable {
    public func cancel(_ param: AppTaskParamable, _ async: AsyncWaitSignalable){}

    public func perform(_ param: AppTaskParamable, _ async: AsyncWaitSignalable) throws -> AppTaskResultable? {
        return nil
    }
}

private protocol MemoCamAppDefaults: AppDefaults, AppUICameraOptions {
    var showAllTexts:Bool{set get}
}

extension Defaults: MemoCamAppDefaults {
    fileprivate var showAllTexts: Bool {
        set{ set(newValue) }
        get{ return get(or: true) }
    }
}

class MemoCamApp: NSObject, PropertyWatchable, BApp, LaunchableApp, AppDockApp, PhotoPickerCollectionViewDelegatableApp, AVCaptureDeviceApp {
    static var taskType: AppTaskable.Type = _MemoCamAppTask.self
    static var paramType: AppTaskParamable.Type = AppAsset.self

    public private(set) lazy var content: AppDockContent? = MemoCamAppDockContent()
    public private(set) static var fixedContentLayout: Bool = true

    fileprivate static var privateDefaults = MemoCamApp.defaults as! MemoCamAppDefaults

    private static let _info = AppInfo(
        identifier: "com.stells.pap.memocam"
        , version: "1.1"
        , phase: .release
        , appType: MemoCamApp.self
        , displayName: "MemoCam".localized, description:nil, keywords:nil
        , icon: AppIcon(source: R.image.memoCamBAppIcon.name, style: .original)
            , themeColor: UIColor(red:0.98, green:0.99, blue:0.22, alpha:1), policy: AppPolicy.default
        , minOSVersion: nil
    )

    public static var info:AppInfo{
        return (self as? SubApp.Type)?.subInfo ?? _info
    }

    public required override init() {}

    func shouldSelect(item: AppAsset) -> Bool {
        return false
    }

    fileprivate var photoPickerCallee:PhotoPickerViewControllerUniversalOperations?
    func didAppear(callee: PhotoPickerViewControllerUniversalOperations) {
        photoPickerCallee = callee
    }

    fileprivate var importedLaunchOption: AppLaunchOptions? = nil

    func didLaunch(previous: App.Type?, withOption: AppLaunchOptions?) {
        importedLaunchOption = withOption
    }

    func didResign(current: App.Type?) {

    }
}

extension VisionTextResultGroup {
    static func createResultGroup(with visionTextBlocks: [VisionTextBlock], barcodes: [VisionBarcodeText] = [], _ async: AsyncWaitSignalable) -> VisionTextResultGroup {
        var resultGroup = VisionTextResultGroup()

        let emails = visionTextBlocks.parse(type: VisionTextEmailAddressParser.self, async) ?? []
        let urls = visionTextBlocks.parse(type: VisionTextURLParser.self, async)?.compactMap { $0.compactMap { $0.scheme == "mailto" ? nil : $0 }.nilEmpty } ?? []
        let addresses = visionTextBlocks.parse(type: VisionTextAddressParser.self, async) ?? []
        let flights = visionTextBlocks.parse(type: VisionTextFlightNumberParser.self, async) ?? []
        let dates = visionTextBlocks.parse(type: VisionTextDateParser.self, async) ?? []
        let currencies = visionTextBlocks.parse(type: VisionTextCurrencyParser.self, async) ?? []

        let barcodeValues = barcodes.compactMap({ $0.visionBarcode })
        resultGroup.barcodes = !barcodeValues.isEmpty ? barcodeValues : nil

        resultGroup.emails = !emails.isEmpty ? emails : nil
        resultGroup.urls = !urls.isEmpty ? urls : nil
        resultGroup.addresses = !addresses.isEmpty ? addresses : nil
        resultGroup.flights = !flights.isEmpty ? flights : nil
        resultGroup.dates = !dates.isEmpty ? dates : nil
        resultGroup.currencies = !currencies.isEmpty ? currencies : nil

        return resultGroup
    }
}


private struct MemoCamAppDetector {
    private let vision = Vision.vision()
    private var textDetector: VisionTextRecognizer
    private var barcodeDetector: VisionBarcodeDetector

    init() {
        textDetector = vision.onDeviceTextRecognizer()
        barcodeDetector = vision.barcodeDetector()
    }

    fileprivate mutating func detectResult(image: UIImage, _ async: AsyncWaitSignalable) -> VisionTextImageDetectResult? {
        guard let visionText = self.textDetector.detect(with: image, async) else {
            return nil
        }

        var result = VisionTextImageDetectResult(image: image)

        let blocks = visionText.blocks
        let barcodes = self.barcodeDetector.detect(with: image, async) ?? []

        result.sourceVisionText = CustomVisionText(visionTextBlocks: blocks, barcodes: barcodes) as Any
        result.resultGroup = VisionTextResultGroup.createResultGroup(with: blocks, barcodes: barcodes, async)

        return result
    }
}

private class BadgeIconLayer: ResultItemLayer {
    lazy var badgeLayer = CAShapeLayer()
    lazy var badgeIconLayer = CALayer()

    override init(layer: Any) {
        super.init(layer: layer)
    }

    override init() {
        super.init()

        initialize()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func initialize() {
        super.initialize()

        addSublayer(badgeLayer)
        badgeLayer.frame.size = CGSize(width: badgeSize, height: badgeSize)
        badgeLayer.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: badgeLayer.frame.size)).cgPath
        badgeLayer.fillColor = UIColor.white.cgColor
        badgeLayer.isHidden = true
        badgeLayer.opacity = 0.9
        badgeLayer.addSublayer(badgeIconLayer)
        
        badgeIconLayer.contentsGravity = CALayerContentsGravity.resizeAspectFill
        badgeIconLayer.masksToBounds = true
        badgeIconLayer.frame.size = CGSize(width: badgeSize * 0.6, height: badgeSize * 0.6)
    }
    
    let badgeSize: CGFloat = 24
    
    func showBadgeIcon(with quad: CGQuad, in bounds: CGRect) {
        let point = quad.topLeft.applying(previewTransform)
        
        badgeLayer.isHidden = false
        badgeLayer.position = CGPoint(x: (point.x - badgeSize * 0.35).clamped(to: bounds.origin.x + badgeSize / 2 ... bounds.width - badgeSize / 2), y: (point.y - badgeSize * 0.35).clamped(to: bounds.origin.y + badgeSize / 2 ... bounds.height - badgeSize / 2))
        
        badgeIconLayer.contents = (result?.preferredParserIcon() ?? R.image.appActionIconEmbossText())?.cgImage
        badgeIconLayer.position = CGPoint(x: badgeLayer.bounds.midX, y: badgeLayer.bounds.midY)
    }
}

private class ResultItemLayer: CAShapeLayer {
    var result: ResultPreviewItem?

    var previewTransform: CGAffineTransform = .identity
    var tintColor: UIColor?

    var hitTestPath: UIBezierPath?

    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    override init() {
        super.init()
        
        initialize()
    }
    
    var highlighted: Bool = false {
        didSet {
            fillColor = highlighted ? UIColor(white: 1, alpha: 0.7).cgColor : UIColor.clear.cgColor
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func initialize() {
        strokeColor = UIColor.white.cgColor
        fillColor = UIColor.clear.cgColor
        lineWidth = 1
        shadowOpacity = 0.5
        shadowColor = UIColor.black.cgColor
        shadowOffset = .zero
        shadowRadius = 2
    }
}

fileprivate protocol ResultPreviewViewDelegate {
    func resultPreviewView(_ view: ResultPreviewView, didSelectItemWith resultPreviewItem: ResultPreviewItem?)
}

fileprivate class CustomVisionText {
    private var visionTextBlocks = [VisionTextBlock]()
    private var visionBarcodes = [VisionBarcodeText]()

    init(visionTextBlocks: [VisionTextBlock]) {
        self.visionTextBlocks.append(contentsOf: visionTextBlocks)
    }

    init(visionTextBlocks: [VisionTextBlock], barcodes: [VisionBarcodeText]) {
        self.visionTextBlocks.append(contentsOf: visionTextBlocks)
        self.visionBarcodes = barcodes
    }

    var text: String {
        return visionTextBlocks.parse(type: VisionTextStringParser.self, AsyncSignal())?.joined() ?? ""
    }

    var blocks: [VisionTextBlock] {
        return visionTextBlocks
    }

    var barcodes: [VisionBarcodeText] {
        return visionBarcodes
    }
}

fileprivate struct ResultPreviewItem {
    var visionTextBlock: VisionTextBlock?
    var visionBarcodeText: VisionBarcodeText?
    var resultGroup: VisionTextResultGroup

    init(visionTextBlock: VisionTextBlock, resultGroup: VisionTextResultGroup) {
        self.visionTextBlock = visionTextBlock
        self.resultGroup = resultGroup
    }

    init(visionBarcodeText: VisionBarcodeText, resultGroup: VisionTextResultGroup) {
        self.visionBarcodeText = visionBarcodeText
        self.resultGroup = resultGroup
    }

    var quad: CGQuad {
        let points = visionTextBlock?.cornerPoints?.map { $0.cgPointValue }
            ?? visionBarcodeText?.cornerPoints?.map { $0.cgPointValue }
            ?? []
        return CGQuad(points)
    }

    var frame: CGRect {
        return visionTextBlock?.frame ?? visionBarcodeText?.frame ?? .zero
    }

    var text: String {
        return visionTextBlock?.text ?? visionBarcodeText?.text ?? ""
    }

    var isBarcode: Bool {
        return visionBarcodeText != nil
    }

    func preferredParserIcon() -> UIImage? {
        guard resultGroup.isFilled else {
            return nil
        }

        if resultGroup.barcodes?.contains(where: { $0.valueType == .phone }) == true {
            return R.image.appActionIconEmbossPhoneCall()
        } else if resultGroup.emails?.count ?? 0 > 0 || resultGroup.barcodes?.contains(where: { $0.valueType == .email }) == true {
            return R.image.appActionIconEmail()
        } else if resultGroup.addresses?.count ?? 0 > 0 || resultGroup.barcodes?.contains(where: { $0.valueType == .geographicCoordinates }) == true {
            return R.image.appActionIconLocation()
        } else if resultGroup.barcodes?.contains(where: { $0.valueType == .contactInfo }) == true {
            return R.image.appActionIconContact()
        } else if resultGroup.dates?.count ?? 0 > 0 || resultGroup.barcodes?.contains(where: { $0.valueType == .calendarEvent }) == true {
            return R.image.appActionIconEmbossDate()
        } else if resultGroup.urls?.count ?? 0 > 0 || resultGroup.barcodes?.contains(where: { $0.valueType == .URL || $0.valueType == .ISBN || $0.valueType == .product || $0.format != .qrCode }) == true {
            return R.image.appActionIconEmbossURL()
        } else if resultGroup.flights?.count ?? 0 > 0 {
            return R.image.appActionIconEmbossFlight()
        } else if resultGroup.currencies?.count ?? 0 > 0 {
            return R.image.appActionIconCurrency()
        }

        return nil
    }
}

fileprivate class ResultPreviewView: DesignableView {
    lazy var imageView: UIImageView = UIImageView(frame: .zero)
    var delegate: ResultPreviewViewDelegate?

    private(set) var resultsInPlainText: Bool = false
    private lazy var longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.didLongPress))

    override func initialize() {
        super.initialize()
        
        addSubview(imageView)
        imageView.fitConstraints(to: self)
        imageView.contentMode = .scaleAspectFill
        
        layer.addSublayer(dimmedLayer)
        layer.addSublayer(resultsLayer)
        layer.addSublayer(resultsUILayer)
        
        dimmedLayer.fillRule = .evenOdd
        dimmedLayer.fillColor = UIColor(white: 0, alpha: 0.75).cgColor
        
        addGestureRecognizer(longPressGesture)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        layoutIfNeeded()
    }
    
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        
        guard let result = detectResult else { return }
        
        let disableActions = CATransaction.disableActions()
        CATransaction.setDisableActions(true)
        self.resultsLayer.sublayers = nil
        self.resultsUILayer.sublayers = nil
        
        let previewSize = self.imageView.contentMode == .scaleAspectFill ? result.image.size.aspectFill(in: self.bounds.size) : result.image.size.aspectFit(in: self.bounds.size)
        self.resultsLayer.frame = CGRect(origin: CGPoint(x: (self.bounds.width - previewSize.width) / 2, y: (self.bounds.height - previewSize.height) / 2), size: previewSize)
        
        self.dimmedLayer.frame = self.resultsLayer.frame
        self.resultsUILayer.frame = self.resultsLayer.frame
        
        self.dimmedPath.removeAllPoints()
        self.dimmedLayer.path = nil
        
        self.dimmedPath.append(UIBezierPath(rect: self.dimmedLayer.bounds))
        
        let items = self.resultPreviewItems.sorted { (item1, item2) -> Bool in
            item1.quad.boundingRect.size.area < item2.quad.boundingRect.size.area
        }
        
        for item in items {
            self.drawResult(item, in: result.image.size)
        }
        
        self.dimmedLayer.path = self.dimmedPath.cgPath
        
        CATransaction.setDisableActions(disableActions)
    }
    
    fileprivate lazy var dimmedLayer = CAShapeLayer()
    private lazy var dimmedPath = UIBezierPath()
    
    fileprivate lazy var resultsUILayer: CALayer = {
        let layer = CALayer()
        layer.rasterizationScale = UIScreen.main.scale
        layer.shouldRasterize = true
        layer.drawsAsynchronously = true
        return layer
    }()
    
    fileprivate lazy var resultsLayer: CALayer = {
        let layer = CALayer()
        layer.rasterizationScale = UIScreen.main.scale
        layer.shouldRasterize = true
        layer.drawsAsynchronously = true
        return layer
    }()
    
    var image: UIImage? {
        set {
            reset()
            
            imageView.image = newValue
        }
        
        get {
            return imageView.image
        }
    }
    
    private var resultPreviewItems = [ResultPreviewItem]()
    
    private(set) var detectResult: VisionTextImageDetectResult?

    func reloadResults(_ result: VisionTextImageDetectResult, includingPlainText:Bool) {
        self.resultsInPlainText = includingPlainText
        self.detectResult = result

        let async = AsyncSignal()

        DispatchQueue.global(qos: .userInteractive).async {
            self.resultPreviewItems.removeAll()

            let customText = result.sourceVisionText as? CustomVisionText
            for visionTextBlock in customText?.blocks ?? [] {
                let resultGroup = VisionTextResultGroup.createResultGroup(with: [visionTextBlock], async)
                
                guard self.resultsInPlainText || resultGroup.isFilled else { continue }
                self.resultPreviewItems.append(ResultPreviewItem(visionTextBlock: visionTextBlock, resultGroup: resultGroup))
            }

            if let customText = result.sourceVisionText as? CustomVisionText {
                for barcodeText in customText.barcodes {
                    var resultGroup = VisionTextResultGroup()
                    resultGroup.barcodes = [barcodeText.visionBarcode]
                    guard self.resultsInPlainText || resultGroup.isFilled else { continue }
                    self.resultPreviewItems.append(ResultPreviewItem(visionBarcodeText: barcodeText, resultGroup: resultGroup))
                }
            }
            
            DispatchQueue.main.async {
                self.layoutIfNeeded()
            }
        }
    }
    
    fileprivate func reset() {
        DispatchQueue.main.async {
            self.detectResult = nil
            
            self.resultsLayer.sublayers = nil
            self.resultsUILayer.sublayers = nil
            
            self.dimmedPath.removeAllPoints()
            self.dimmedLayer.path = nil
        }
    }
    
    private func drawResult(_ resultPreviewItem: ResultPreviewItem, in size: CGSize) {
        let renderScaleTransform = CGAffineTransform(scaleX: resultsLayer.frame.width / size.width, y: resultsLayer.frame.height / size.height)
        
        let padding: CGFloat = 12
        let insets = UIEdgeInsets(top: -padding / 2, left: -padding / 2, bottom: -padding / 2, right: -padding / 2)
        let quad = resultPreviewItem.quad.inset(by: insets)
        
        let frame = resultPreviewItem.frame.inset(by: insets)
        
        let path = UIBezierPath()
        path.move(to: quad.topLeft)
        path.addLine(to: quad.topRight)
        path.addLine(to: quad.bottomRight)
        path.addLine(to: quad.bottomLeft)
        path.close()
        path.apply(renderScaleTransform)
        
        let perspectiveTransform = CATransform3DConcat(CATransform3D(from: frame, to: quad), CATransform3DMakeAffineTransform(renderScaleTransform))
        
        var cornerRadius = min(20, frame.minLength * 0.2)
        
        //FIXME: it's weird... wrong transform with barcode
        if resultPreviewItem.isBarcode {
            let dimmedPath = path
            self.dimmedPath.append(dimmedPath)

            cornerRadius = min(4, frame.minLength * 0.1)
        }
        else {
            let dimmedPath = UIBezierPath(roundedRect: frame, cornerRadius: cornerRadius)
            dimmedPath.apply(CATransform3DGetAffineTransform(perspectiveTransform))
            self.dimmedPath.append(dimmedPath)
        }
        
        let layer = ResultItemLayer()
        layer.tintColor = tintColor
        layer.result = resultPreviewItem
        layer.previewTransform = renderScaleTransform
        layer.lineWidth = 1 / max(renderScaleTransform.scaleX, renderScaleTransform.scaleY)
        layer.hitTestPath = path
        layer.path = UIBezierPath(roundedRect: quad.boundingRect, cornerRadius: cornerRadius).cgPath
        layer.transform = perspectiveTransform
        
        let iconLayer = BadgeIconLayer()
        iconLayer.tintColor = tintColor
        iconLayer.result = resultPreviewItem
        iconLayer.previewTransform = renderScaleTransform
        iconLayer.showBadgeIcon(with: resultPreviewItem.quad, in: CGRect(origin: CGPoint(x: (resultsLayer.bounds.width - bounds.width) / 2, y: (resultsLayer.bounds.height - bounds.height) / 2), size: resultsLayer.bounds.size))
        
        resultsLayer.addSublayer(layer)
        resultsUILayer.addSublayer(iconLayer)
    }
    
    private var currentHitLayer: ResultItemLayer?
    private func resultItemLayer(at point: CGPoint) -> ResultItemLayer? {
        let layerLocation = layer.convert(point, to: resultsLayer)
        for layer in resultsLayer.sublayers?.compactMap({ $0 as? ResultItemLayer }) ?? [] {
            if layer.hitTestPath?.contains(layerLocation) == true {
                return layer
            }
        }
        return nil
    }
    
    @objc private func didLongPress(sender: UILongPressGestureRecognizer) {
        let hidesResults: Bool
        switch sender.state {
        case .ended, .cancelled: hidesResults = false
        default: hidesResults = true
        }
        resultsLayer.isHidden = hidesResults
        resultsUILayer.isHidden = hidesResults
        dimmedLayer.isHidden = hidesResults
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self
    }
    
    private var cancelToTap = false
    private var touchBeginLocation = CGPoint.zero
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        cancelToTap = false
        
        guard let point = touches.first?.location(in: self) else { return }
        
        touchBeginLocation = point
        
        currentHitLayer = resultItemLayer(at: point)
        currentHitLayer?.highlighted = true
        
        longPressGesture.isEnabled = currentHitLayer == nil
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard let point = touches.first?.location(in: self) else { return }
        
        if currentHitLayer == nil {
            cancelToTap = touchBeginLocation.distance(to: point) > 10
        }
        
        guard let boundingBoxOfPath = resultItemLayer(at: point)?.path?.boundingBoxOfPath else {
            currentHitLayer?.highlighted = false
            return
        }
        
        currentHitLayer?.highlighted = (currentHitLayer?.path?.boundingBoxOfPath.intersects(boundingBoxOfPath) == true)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        guard let point = touches.first?.location(in: self) else { return }
        
        guard (currentHitLayer == nil && !cancelToTap) || (currentHitLayer != nil && currentHitLayer == resultItemLayer(at: point)) else {
            self.touchesCancelled(touches, with: event)
            return
        }
        
        DispatchQueue.main.async {
            UIFeedback.select()
        }
        
        delegate?.resultPreviewView(self, didSelectItemWith: currentHitLayer?.result)
        
        currentHitLayer?.highlighted = false
        currentHitLayer = nil
        longPressGesture.isEnabled = true
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        currentHitLayer?.highlighted = false
        currentHitLayer = nil
        longPressGesture.isEnabled = true
    }
}

fileprivate class UIControlContainerView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let view = super.hitTest(point, with: event), view is UIControl {
            return view
        }
        else {
            return nil
        }
    }
}

fileprivate class MemoCamAppDockContent: NSObject, PropertyWatchable, AppDockContent, AppDockDelegate {
    fileprivate lazy var cameraView: UICamera = {
        let cameraView = UICamera(frame: .zero)
        cameraView.clipsToBounds = false
        cameraView.contentMode = .scaleAspectFill
        return cameraView
    }()
    
    var primaryColor: UIColor {
        return MemoCamApp.info.themeColor ?? UIColor(red:0.98, green:0.99, blue:0.22, alpha:1)
    }

    fileprivate lazy var contentView: UIView = {
        let view = UIView(frame: .zero)
        view.clipsToBounds = false
        return view
    }()

    fileprivate lazy var cameraWidgetView: UIControlContainerView = {
        let view = UIControlContainerView(frame: .zero)
        view.clipsToBounds = false
        return view
    }()

    lazy var view: UIView = {
        let view = UIView(frame: .zero)
        
        if let defaults = MemoCamApp.defaults as? MemoCamAppDefaults {
            cameraView.preferredFlashMode = defaults.cameraFlashMode
            cameraView.preferredTorchLevel = defaults.cameraTorchLevel
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.performButtonDidTap))
        cameraView.addGestureRecognizer(tapGesture)
        
        view.addSubview(contentView)
        view.addSubview(toolBar)
        
        toolBar.translatesAutoresizingMaskIntoConstraints = false
        toolBar.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        toolBar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        toolBar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        toolBar.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: toolBar.topAnchor).isActive = true

        //Lv.1 Camera
        contentView.addSubview(cameraView)
        cameraView.fitConstraints(to: contentView)

        //Lv.2 Camera Widgets - Zoom, Torch, etc
        contentView.addSubview(cameraWidgetView)
        cameraWidgetView.fitConstraints(to: contentView)
        
        let buttonImageInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        
        //flash >> cameraWidgetView
        cameraTorchButton.imageEdgeInsets = buttonImageInsets
        cameraTorchButton.setImage(torchIcon, for: .normal)
        cameraTorchButton.addTarget(self, action: #selector(self.toggleTorchMode), for: .touchUpInside)
        cameraWidgetView.addSubview(cameraTorchButton)
        
        cameraTorchButton.tintColor = view.colorTheme.tintColor
        
        cameraTorchButton.translatesAutoresizingMaskIntoConstraints = false
        cameraTorchButton.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor).isActive = true
        cameraTorchButton.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor, constant: 2).isActive = true
        cameraTorchButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        cameraTorchButton.widthAnchor.constraint(equalTo: cameraTorchButton.heightAnchor, multiplier: 1).isActive = true
        
        // torch level >> cameraWidgetView
        cameraTorchLevelButton.imageEdgeInsets = buttonImageInsets
        cameraTorchLevelButton.imageView?.contentMode = .scaleAspectFit
        cameraTorchLevelButton.contentHorizontalAlignment = .fill
        cameraTorchLevelButton.contentVerticalAlignment = .fill
        cameraTorchLevelButton.addTarget(self, action: #selector(self.touchLevelButtonDidTap), for: .touchUpInside)
        cameraWidgetView.addSubview(cameraTorchLevelButton)
        
        cameraTorchLevelButton.translatesAutoresizingMaskIntoConstraints = false
        cameraTorchLevelButton.centerYAnchor.constraint(equalTo: cameraTorchButton.centerYAnchor).isActive = true
        cameraTorchLevelButton.leadingAnchor.constraint(equalTo: cameraTorchButton.trailingAnchor, constant: 0).isActive = true
        cameraTorchLevelButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        cameraTorchLevelButton.widthAnchor.constraint(equalTo: cameraTorchLevelButton.heightAnchor, multiplier: 0.75).isActive = true
        
        //zoom >> cameraWidgetView
        view.addGestureRecognizer(pinchGesture)
        
        zoomButton.addTarget(self, action: #selector(self.zoomButtonDidTap), for: .touchUpInside)
        cameraWidgetView.addSubview(zoomButton)
        
        zoomButton.translatesAutoresizingMaskIntoConstraints = false
        zoomButton.centerXAnchor.constraint(equalTo: toolBar.centerXAnchor).isActive = true
        toolBar.topAnchor.constraint(equalTo: zoomButton.bottomAnchor, constant: 10).isActive = true
        zoomButton.widthAnchor.constraint(equalToConstant: 44 * 0.75).isActive = true
        zoomButton.heightAnchor.constraint(equalTo: zoomButton.widthAnchor).isActive = true
        
        cameraView.configurationDidUpdate = {
            var defaults = MemoCamApp.defaults as? MemoCamAppDefaults
            defaults?.cameraFlashMode = self.cameraView.flashMode
            if self.cameraView.flashMode == .torch {
                defaults?.cameraTorchLevel = self.cameraView.torchLevel
            }
            
            DispatchQueue.mainAsyncIfNot {
                self.cameraTorchButton.setImage(self.torchIcon, for: .normal)
                self.cameraTorchButton.tintColor = self.cameraView.flashMode == .torch ? self.primaryColor : view.colorTheme.tintColor
                
                self.cameraTorchLevelButton.setImage(self.torchLevelIcon(self.cameraView.torchLevel), for: .normal)
                self.cameraTorchLevelButton.isHidden = self.cameraView.flashMode != .torch
            }
        }
        
        return view
    }()
    
    fileprivate lazy var resultPreviewView: ResultPreviewView = {
        let view = ResultPreviewView(frame: .zero)
        return view
    }()
    
    fileprivate lazy var toolBar: UIToolbar = {
        let toolBar = UIToolbar(frame: .zero)
        return toolBar
    }()
    
    private lazy var cameraTorchButton = UIButton(type: .system)
    private lazy var cameraTorchLevelButton = UIButton(type: .system)
    
    private var torchIcon: UIImage{
        return (R.image.appUICameraTorchOn() ?? UIImage()).withRenderingMode(.alwaysTemplate)
    }
    
    private func torchLevelIcon(_ level: Float) -> UIImage {
        return (UIImage(path: UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: 20, height: 20)).insetBy(dx: 5, dy: 5)), fillColor: self.primaryColor.withAlphaComponent(CGFloat(level)), strokeColor: self.primaryColor) ?? UIImage()).withRenderingMode(.alwaysOriginal)
    }
    
    @objc func toggleTorchMode(sender: Any) {
        cameraView.flashMode = [
            UICamera.FlashMode.off:UICamera.FlashMode.torch,
            UICamera.FlashMode.torch:UICamera.FlashMode.off
        ][cameraView.flashMode]!
        
        UIFeedback.select()
    }
    
    @objc func touchLevelButtonDidTap(sender: Any) {
        cameraView.torchLevel = max(0.25, (cameraView.torchLevel + 0.25).truncatingRemainder(dividingBy: 1.25))
        
        UIFeedback.select()
    }
    
    private lazy var zoomButton = ZoomButton()
    
    @objc func zoomButtonDidTap() {
        if cameraView.videoZoomFactor != cameraView.videoMinZoomFactor {
            cameraView.zoom(cameraView.videoMinZoomFactor)
            zoomButton.zoomFactor = cameraView.videoMinZoomFactor
        }
        else {
            cameraView.zoom(2)
            zoomButton.zoomFactor = 2
        }
    }
    
    private lazy var pinchGesture: UIPinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.pinchToZoom))
    
    @objc func pinchToZoom(sender: UIPinchGestureRecognizer) {
        if sender.state == .began {
            sender.scale = cameraView.videoZoomFactor
        }
        
        cameraView.zoom(sender.scale)
        zoomButton.zoomFactor = cameraView.videoZoomFactor
    }
    
    internal class DisableImplicitAnimatableShapeLayer: CAShapeLayer {
        override func action(forKey event: String) -> CAAction? {
            switch event {
            case "position", "onOrderIn", "onOrderOut", "path": return NSNull()
            default: return super.action(forKey: event)
            }
        }
    }
    
    private func createDebugLayer() -> DisableImplicitAnimatableShapeLayer {
        let layer = DisableImplicitAnimatableShapeLayer()
        layer.drawsAsynchronously = true
        
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = 1
        layer.opacity = 0.7
        
        return layer
    }

    fileprivate func drawPolygons(with quads: [CGQuad], to layer: CAShapeLayer, in previewSize: CGSize? = nil) {
        let disabledActions = CATransaction.disableActions()
        CATransaction.setDisableActions(true)
        
        var layers = [CALayer]()
        
        let padding: CGFloat = 4
        var transform: CGAffineTransform = .identity
        
        if let previewSize = previewSize {
            transform = transform
                    .scaledBy(x: 1, y: -1)
                    .translatedBy(x: 0, y: -previewSize.height)
                    .scaledBy(x: previewSize.width, y: previewSize.height)
            
            layer.frame = CGRect(origin: CGPoint(x: (self.cameraView.bounds.width - previewSize.width) / 2, y: (self.cameraView.bounds.height - previewSize.height) / 2), size: previewSize)
        }
        else {
            layer.frame = self.cameraView.bounds
        }
        
        for var quad in quads {
            quad.apply(transform)
            let padding = min(quad.boundingRect.height * 0.1, padding)
            quad = quad.inset(by: UIEdgeInsets(top: -padding, left: -padding, bottom: -padding, right: -padding))
            
            let polygonLayer = createDebugLayer()
            polygonLayer.path = UIBezierPath(roundedRect: quad.boundingRect, cornerRadius: min(20, quad.boundingRect.minLength * 0.2)).cgPath
            polygonLayer.transform = CATransform3D(from: quad.boundingRect, to: quad)
            layers.append(polygonLayer)
        }
        
        layer.sublayers = layers
        
        CATransaction.setDisableActions(disabledActions)
        CATransaction.commit()
    }

    fileprivate func drawPolygons(with observations: [VNRectangleObservation], to layer: CAShapeLayer) {
        let previewSize = previewContentMode == .scaleAspectFill ? self.cameraView.captureVideoSize.aspectFill(in: self.cameraView.bounds.size) : self.cameraView.captureVideoSize.aspectFit(in: self.cameraView.bounds.size)
        let polygons: [CGQuad] = observations.compactMap {
            guard $0.responds(to: #selector(getter: CIRectangleFeature.topLeft)), $0.responds(to: #selector(getter: CIRectangleFeature.topRight)), $0.responds(to: #selector(getter: CIRectangleFeature.bottomRight)), $0.responds(to: #selector(getter: CIRectangleFeature.bottomLeft)) else { return nil }
            return CGQuad($0.topLeft, $0.topRight, $0.bottomRight, $0.bottomLeft)
        }
        drawPolygons(with: polygons, to: layer, in: previewSize)
    }

    fileprivate func drawPolygons(with codeObjects: [AVMetadataMachineReadableCodeObject], to layer: CAShapeLayer) {
        drawPolygons(with: codeObjects.map { CGQuad($0.corners, clockwised: false) }, to: layer)
    }

    private lazy var detector = MemoCamAppDetector()

    var preferences: AppDockContentPreferable? {
        var pref = AppDockContentPreferences()
        pref.preferredHeight = AppDockContentPreferences.GreatestHeight
        return pref
    }

    func willSetContentView(_ view: UIView, dock: AppDock) {

    }
    
    func willLayoutSubviews() {
        resultPreviewView.layoutIfNeeded()
    }

    @objc dynamic
    fileprivate var captureSessionHasStarted:Bool = false
    
    private var previewContentMode: UIView.ContentMode {
        return self.resultPreviewView.imageView.contentMode
    }

    func didSetContentView(_ view: UIView, dock: AppDock) {
        let launchOption = AppCenter.default.currentInstanceAs(MemoCamApp.self)?.importedLaunchOption
        self.currentTargetImage = launchOption?.options?[AppLaunchOptionsKey.MemoCamPreviewOption] as? UIImage
        
        stopMemoCamSession()
        
        updateToolBar()

        toolBar.tintColor = view.colorTheme.tintColor

        if let image = currentTargetImage {
            reloadDetectedResult(with: image)
        }
        else {
            self.resultPreviewView.imageView.contentMode = .scaleAspectFill
            startMemoCamSession()
        }
    }
    
    private func reloadDetectedResult(with image: UIImage) {
        let loadingView = UIActivityIndicatorView(style: .medium)
        loadingView.startAnimating()
        
        toolBar.setItems([
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(customView: loadingView),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            ], animated: true)
        
        self.resultPreviewView.imageView.contentMode = .scaleAspectFit
        self.detect(with: image)
    }
    
    private func startMemoCamSession() {
        cameraView.setUp()
        cameraView.capturePreset = .high
        
        let detectTextLayer = createDebugLayer()
        let detectBarcodesLayer = createDebugLayer()
        
        cameraView.layer.addSublayer(detectTextLayer)
        cameraView.layer.addSublayer(detectBarcodesLayer)

        let detectTextRequest:VNDetectTextRectanglesRequest? = VNDetectTextRectanglesRequest { (request, error) in
            guard let observations = request.results as? [VNTextObservation] else {
                return
            }
            
            DispatchQueue.main.async {
                self.drawPolygons(with: observations, to: detectTextLayer)
            }
        }

        cameraView.setCaptureVideoDataOutput { sampleBuffer in
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let deviceOrientation = self.cameraView.deviceMotion.orientation
            
            if self.needsCaptureImage {
                self.needsCaptureImage = false
                
                self.cameraView.performShutterAnimation()
                
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(forExifOrientation: Int32(deviceOrientation.exifOrientation(frontFacing: false).rawValue))
                
                var image: UIImage?
                if let cgImage = CIContext(options: nil).createCGImage(ciImage, from: ciImage.extent) {
                    image = UIImage(cgImage: cgImage)
                }
                
                self.detect(with: image)
            }
            
            var options: [VNImageOption: Any] = [:]
            if let cameraIntrinsicMatrix = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
                options[VNImageOption.cameraIntrinsics] = cameraIntrinsicMatrix
            }
            
            if let detectTextRequest = detectTextRequest{
                try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: UInt32(deviceOrientation.exifOrientation(frontFacing: false).rawValue)) ?? .rightMirrored, options: options).perform([detectTextRequest])
            }
        }
        cameraView.setMetadataOutput { (metadataObjects) in
            DispatchQueue.main.async {
                self.drawPolygons(with: metadataObjects as? [AVMetadataMachineReadableCodeObject] ?? [], to: detectBarcodesLayer)
            }
        }
        cameraView.startSession {
            self.captureSessionHasStarted = true
        }
    }
    
    private func stopMemoCamSession() {
        cameraView.layer.sublayers?.forEach {
            if $0 is DisableImplicitAnimatableShapeLayer {
                $0.removeFromSuperlayer()
            }
        }
        
        cameraView.stopSession()
        captureSessionHasStarted = false
    }

    func willRemoveContentView() {
        cameraView.setCaptureVideoDataOutput(nil)
        cameraView.stopSession()
        captureSessionHasStarted = false
        
        resultPreviewView.reset()
    }

    var delegate: AppDockDelegate? {
        return self
    }

    func dockWillExpand(_ dock: AppDock) {

    }

    func dockWillContract(_ dock: AppDock) {

    }

    private var currentTargetImage: UIImage? {
        didSet {
            DispatchQueue.main.async {
                self.resultPreviewView.image = self.currentTargetImage

                UIView.transition(with: self.contentView, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                    if let _ = self.currentTargetImage {
                        self.stopMemoCamSession()

                        self.cameraView.isHidden = true
                        self.contentView.addSubview(self.resultPreviewView)
                        self.resultPreviewView.fitConstraints(to: self.contentView)
                        self.resultPreviewView.delegate = self
                    }
                    else {
                        self.startMemoCamSession()
                        
                        self.cameraView.isHidden = false
                        self.resultPreviewView.removeFromSuperview()
                        self.resultPreviewView.delegate = nil
                    }
                }) { (completed) in

                }
            }
        }
    }

    fileprivate var isShowingAllText:Bool{
        set{
            switchShowAllTexts.selectedSegmentIndex = newValue ? 1 : 0
        }
        get{
            return switchShowAllTexts.selectedSegmentIndex == 1
        }
    }

    private lazy var switchShowAllTexts: UISegmentedControl = {
        let view = UISegmentedControl(items: ["Action".localized, "Text".localized])
        //TODO: later some category, beautiful action icons with collection view.
        view.selectedSegmentIndex = MemoCamApp.privateDefaults.showAllTexts ? 1 : 0
        view.addTarget(self, action: #selector(self.toggleResultPreviewMode), for: .valueChanged)
        view.sizeToFit()
        return view
    }()

    private func updateToolBar() {
        if let _ = self.currentTargetImage {
            toolBar.setItems([
                UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(self.cancelButtonDidTap)),
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(customView: switchShowAllTexts),
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(self.actionButtonDidTap)),
            ], animated: true)

            cameraWidgetView.visible = false
        }
        else {
            toolBar.setItems([
                UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil),
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(title: "Tap to detect text".localized.localizedCapitalized, style: .plain, target: self, action: #selector(self.performButtonDidTap)),
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(image: R.image.commonCellIconInfo(), style: .plain, target: self, action: #selector(self.selectLanguageOption))
            ], animated: true)

            cameraWidgetView.visible = true
        }

        //INFO: without this line, switchShowAllTexts will disapear
        switchShowAllTexts.sizeToFit()
    }

    private var needsCaptureImage = false
    private func setNeedsCaptureImage() {
        needsCaptureImage = true
    }

    @objc fileprivate func performButtonDidTap(sender: Any) {

        AppCenter.default.currentInstanceAs(MemoCamApp.self)?.photoPickerCallee?.performInNonSelectionContext {

            if let _ = self.currentTargetImage {
//            UIFeedback.select()
//            actionButtonDidTap()
            }
            else {
                let loadingView = UIActivityIndicatorView(style: .medium)
                loadingView.startAnimating()

                self.toolBar.setItems([
                    UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                    UIBarButtonItem(customView: loadingView),
                    UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                ], animated: true)

                UIFeedback.impact(.light)
                self.setNeedsCaptureImage()
            }

        }
    }

    @objc fileprivate func cancelButtonDidTap(sender: Any) {
        UIFeedback.impact(.medium)
        
        if let launchOption = AppCenter.default.currentInstanceAs(MemoCamApp.self)?.importedLaunchOption, let identifierToReturn = launchOption.identifierToReturn {
            AppCenter.default.openApp(identifier: identifierToReturn)
        }
        else if let _ = currentTargetImage {
            currentTargetImage = nil

            updateToolBar()
        }
    }

    @objc private func toggleResultPreviewMode(sender: UISegmentedControl) {
        MemoCamApp.privateDefaults.showAllTexts = isShowingAllText
        if let results = self.resultPreviewView.detectResult {
            resultPreviewView.reloadResults(results, includingPlainText:isShowingAllText)

            UIFeedback.select()
        }
    }

    @objc private func selectLanguageOption(sender: Any) {
        let alert = UIAlertController.alert(title: "Limited Performance Notice".localized, message: "Currently, our AI text recognition model is only available for Alphanumeric and some special characters, and it could be affected by the current system language.".localized)
        alert.addAction(UIAlertAction(title: "OK".localized, style: .cancel, handler: { _ in
            alert.dismiss(animated: true, completion: nil)
        }))
        UIViewController.present(alert, animated: true)
    }

    private func detect(with image: UIImage?) {
        currentTargetImage = image

        if let image = image {
            DispatchQueue.global(qos: .userInteractive).async{
                let async = AsyncSignal()
                if let results = self.detector.detectResult(image: image, async) {
                    DispatchQueue.main.async {
                        self.resultPreviewView.reloadResults(results, includingPlainText:self.isShowingAllText)
                    }
                }

                DispatchQueue.main.async {
                    self.updateToolBar()

                    self.cameraView.layer.sublayers?.forEach { ($0 as? DisableImplicitAnimatableShapeLayer)?.sublayers = nil }
                }
            }
        }
    }
}

extension MemoCamAppDockContent: ResultPreviewViewDelegate {
    fileprivate func showActions(with results: [VisionTextImageDetectResult]) {
        AppCenter.default.currentInstanceAs(MemoCamApp.self)?.photoPickerCallee?.performInNonSelectionContext {
            let quickMode = self.isShowingAllText == false

        DispatchQueue.global(qos: .userInteractive).async{
            let asyncSignal = AsyncSignal()

                var previewTexts:String?
                if !quickMode{
                    previewTexts = results.compactMap{ $0.plainText }.joined().trimmed.nilEmpty
                }

                if let resultMessage = results.handleAsAction(quickMode, message: previewTexts, asyncSignal){
                    asyncSignal.begin()
                    DispatchQueue.main.async {
                        UIAlertController.alert(resultMessage, completion:{ _ in
                            asyncSignal.end()
                        })
                    }
                    asyncSignal.waitUntilEnd()
                }
            }
        }
    }

    @objc fileprivate func actionButtonDidTap() {
        if var results = self.resultPreviewView.detectResult {
            if resultPreviewView.resultsInPlainText {
                results.plainText = (results.sourceVisionText as? CustomVisionText)?.text
            }
            self.showActions(with: [results])
        }
    }

    func resultPreviewView(_ view: ResultPreviewView, didSelectItemWith resultPreviewItem: ResultPreviewItem?) {
        guard let image = currentTargetImage else { return }

        if let resultPreviewItem = resultPreviewItem {
            var result = VisionTextImageDetectResult(image: image)
            if let textBlock = resultPreviewItem.visionTextBlock {
                result.sourceVisionText = CustomVisionText(visionTextBlocks: [textBlock])
            } else if let barcodeText = resultPreviewItem.visionBarcodeText {
                result.sourceVisionText = CustomVisionText(visionTextBlocks: [], barcodes: [barcodeText])
            }
            if view.resultsInPlainText {
                result.plainText = resultPreviewItem.text
            }
            result.resultGroup = resultPreviewItem.resultGroup

            showActions(with: [result])
        }
        else {
            actionButtonDidTap()
        }
    }
}


import Intents

extension MemoCamApp:UIApplicationDelegateLaunchableApp{
    static var intents: [INIntent] {
        if #available(iOS 12.0, *) {
            let captureAllText = CaptureAllTextIntent()
            captureAllText.appId = info.identifier
            captureAllText.suggestedInvocationPhrase = "Capture All Text.".localized

            let captureActionsToDo = CaptureActionsToDoIntent()
            captureActionsToDo.appId = info.identifier
            captureActionsToDo.suggestedInvocationPhrase = "Capture Actions To Do.".localized

            return defaultIntents + [captureAllText, captureActionsToDo]
        } else {
            return []
        }
    }

    func didLaunchHandling(with userActivity: NSUserActivity) {

        if #available(iOS 12.0, *) {
            guard let intent = userActivity.interaction?.intent
            , let content = self.content as? MemoCamAppDockContent else {
                return
            }


            guard content.captureSessionHasStarted else {
                content.watch(\MemoCamAppDockContent.captureSessionHasStarted){ _, _ in
                    if content.captureSessionHasStarted{
                        DispatchQueue.main.async {
                            self.didLaunchHandling(with: userActivity)
                        }
                    }
                }
                return
            }

            if intent is CaptureAllTextIntent{
                content.isShowingAllText = true

            }else if intent is CaptureActionsToDoIntent{
                content.isShowingAllText = false
            }

            content.cancelButtonDidTap(sender: "")

            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+1) {
                content.performButtonDidTap(sender: "")
            }

        }
    }

    func didLaunchHandling(with shortcutItem: UIApplicationShortcutItem) {
    }
}





/*
import ARKit

class AppUIARView: UIView {
    fileprivate lazy var previewView: ARSCNView = {
        let view = ARSCNView(frame: .zero, options: nil)
        return view
    }()
    
    private lazy var renderer: SCNRenderer = SCNRenderer(device: nil, options: nil)
    private lazy var renderQueue = DispatchQueue(label: "com.stells.internal."+codefile(), qos: .utility)
    
    private(set) lazy var deviceMotion = UIDeviceMotion()
    
    var updateRenderer: ((_ renderer: SCNRenderer, _ frame: ARFrame) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    private lazy var orientationTrackingConfiguration: AROrientationTrackingConfiguration = {
        let configuration = AROrientationTrackingConfiguration()
        if #available(iOS 11.3, *) {
            configuration.isAutoFocusEnabled = true
        }
        return configuration
    }()
    
    private lazy var worldTrackingConfiguration: ARWorldTrackingConfiguration = {
        let configuration = ARWorldTrackingConfiguration()
        
        if #available(iOS 11.3, *) {
            configuration.isAutoFocusEnabled = true
            configuration.planeDetection = [.horizontal, .vertical]
        }
        else {
            configuration.planeDetection = .horizontal
        }
        
        return configuration
    }()
    
    var scene: SCNScene {
        return previewView.scene
    }
    
    private func initialize() {
        addSubview(previewView)
        previewView.fitConstraints(to: self)
        
        previewView.automaticallyUpdatesLighting = true
        previewView.autoenablesDefaultLighting = true
        
        #if DEBUG
        previewView.showsStatistics = true
//        previewView.debugOptions = [ARSCNDebugOptions.showFeaturePoints/*, ARSCNDebugOptions.showWorldOrigin*/]
        #endif
        
        renderer.autoenablesDefaultLighting = true
        renderer.scene = scene
    }
    
    var previewSize: CGSize {
        return previewView.bounds.size
    }
}

extension AppUIARView {
    func startSession() {
        deviceMotion.startUpdates(interval: 0.6)
        
        previewView.session.delegateQueue = renderQueue
        previewView.session.delegate = self
        previewView.session.run(orientationTrackingConfiguration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func stopSession() {
        deviceMotion.stopUpdates()
        
        previewView.session.delegate = nil
        previewView.session.pause()
    }
}

extension AppUIARView: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        updateRenderer?(renderer, frame)
    }
}

extension AppUIARView {
    func hitTest(at location: CGPoint, types: ARHitTestResult.ResultType? = nil) -> ARHitTestResult? {
        if #available(iOS 11.3, *) {
            return previewView.hitTest(location, types: types ?? [.existingPlaneUsingGeometry, .featurePoint]).first
        }
        else {
            return previewView.hitTest(location, types: types ?? [.existingPlaneUsingExtent, .featurePoint]).first
        }
    }
    
    func node(at location: CGPoint) -> SCNNode? {
        let hitTestResults = previewView.hitTest(location)
        return hitTestResults.first?.node
    }
    
    func convertPointToWorld(_ location: CGPoint) -> float3? {
        return worldTransform(location)?.translation
    }
    
    func anchorTransform(_ location: CGPoint) -> matrix_float4x4? {
        guard let hitTestResult = previewView.hitTest(location, types: .existingPlane).first else { return nil }
        return hitTestResult.anchor?.transform
    }
    
    func worldTransform(_ location: CGPoint) -> matrix_float4x4? {
        guard let hitTestResult = previewView.hitTest(location, types: .featurePoint).first else { return nil }
        return hitTestResult.worldTransform
    }
}

extension float4x4 {
    var translation: float3 {
        let translation = self.columns.3
        return float3(translation.x, translation.y, translation.z)
    }
}
*/
