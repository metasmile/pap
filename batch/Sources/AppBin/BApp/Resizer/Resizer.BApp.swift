//
//  Resizer.BApp.swift
//  batch
//
//  Created by HYOJIN MO on 09/11/2018.
//  Copyright © 2018 Stells. All rights reserved.
//

import UIKit
import Photos
import MetalPerformanceShaders

protocol ResizerAppDefaults: AppDefaults {
    var resizeFilterName: String? { get set }
    var backgroundColorValue: Int { get set }
    var borderWidth: Double { get set }
}

extension Defaults: ResizerAppDefaults {
    var resizeFilterName: String? {
        get { return get(or: AspectRatioOption.original.name) }
        set { set(newValue); papLog.app.defaults.log(value:newValue ?? AspectRatioOption.original.name) }
    }

    var backgroundColorValue: Int {
        get {
            return get(or:CIFrameFillFilter.BlurFilledBackgroundColorValue)
        }

        set { set(newValue); papLog.app.defaults.log(value:newValue) }
    }

    var borderWidth: Double {
        get { return get(or: 0) }
        set { set(newValue); papLog.app.defaults.log(value:newValue) }
    }
}

public class ResizerAppConfigValue: NSObject, AppConfigAdoptableValuable {
    @objc dynamic
    public var filter: ImageEditStateValue?

    public func adoptValues(fromOther: AppConfigValuable) {
        if let other = fromOther as? ResizerAppConfigValue, let filter = other.filter {
            self.filter = filter
        }
    }
}

class ResizerApp: NSObject, BApp, ConfigurableApp, _ConfigurableApp,
    PHAssetFinalizableApp, EditableApp, PreviewProcessableApp, AppDockApp,
    PhotoPickerCollectionViewDelegatableApp, PhotoPickerViewControllerAppearanceDelegatableApp,
PhotoEditViewControllerDelegatableApp {
    public static let taskType: AppTaskable.Type = _ResizerAppTask.self
    public static let paramType: AppTaskParamable.Type = _ResizerAppAsset.self

    public static var defaultConfigValue: AppConfigValuable {
        let config = ResizerAppConfigValue()
        return config
    }

    @objc dynamic
    public private(set) lazy var config: ResizerAppConfigValue? = type(of:self).defaultConfigValue as? ResizerAppConfigValue

    public private(set) lazy var content: AppDockContent? = ResizerAppDockContent()
    public private(set) lazy var editViewDockContent: AppDockContent? = ResizerAppDockContent()

    public private(set) var defaultEditStateValue: ImageEditStateValue?
    public func setDefaultEditState(value: ImageEditStateValue?) {
        defaultEditStateValue = value

        var defaults = type(of: self).defaults as! ResizerAppDefaults

        let filter = value?.ciFilter as? CIFrameFillFilter
        defaults.resizeFilterName = filter?.name
        defaults.backgroundColorValue = filter?.backgroundColor.rgba() ?? 0xFFFFFFFF
        defaults.borderWidth = Double(filter?.borderWidth ?? 0)
    }

    public static let info = AppInfo(
        identifier: "com.stells.batch.resizer"
        , version: "1.2"
        , phase: .release
        , appType: ResizerApp.self
            , displayName: "Framer".localized.localizedCapitalized
            , description: "Resize and fill to fit your photos by the various sizes.".localized
            , keywords: ["Resize", "Instasize", "Instafit", "No Crop", "Fit", "Scale", "Size","Transform","Instagram","Insta"]
        , icon: AppIcon(source: R.image.resizerBAppIcon.name, style: .original)
        , themeColor: UIColor(rgba: 0xFFE567FF)
        , policy: AppPolicy(lifeCycle: AppLifecyclePolicy(instance: .availability), task: AppTaskPolicy.default)
        , minOSVersion: nil
    )

    required public override init() {
        super.init()
    }

    public var doneButtonTitle: String? {
        return "Resize".localized
    }

    public func shouldSelect(item: AppAsset) -> Bool {
        return item.asset.imageType == .stillImage || item.asset.imageType == .livePhoto || item.asset.imageType == .burst || item.asset.mediaType == .video
    }

    fileprivate var photoPickerCallee:PhotoPickerViewControllerUniversalOperations?

    func didAppear(callee: PhotoPickerViewControllerUniversalOperations) {
        self.photoPickerCallee = callee
    }


    public var finalizingActions: [PHAssetFinalizingAction] {
        return [.actions]
    }

    public static var fixedContentLayout: Bool {
        return true
    }

    public func setConfigValues<T: AppConfigValuable>(_ config:T){
        self.config?.adoptValues(fromOther: config)
    }

    public lazy var previewOriginalImageCache: NSCache<NSString, CIImage>? = NSCache<NSString, CIImage>()
    public func previewProcessing(_ appAsset: AppAsset, targetSize: CGSize, in content: AppDockContent?, completion: @escaping ((_ original: UIImage?, _ filtered: UIImage?) -> Void)) {
        let cacheKey = fileName() + appAsset.asset.localIdentifierWithoutSplitter + "\(targetSize)" as NSString

        let original = previewOriginalImageCache?.object(forKey: cacheKey) ?? appAsset.asset.requestThumbnailImage(targetSize: targetSize)?.asCIImage

        if let image = original {
            previewOriginalImageCache?.setObject(image, forKey: cacheKey)
        }

        let filtered = original?.applyFilter(ciFilter: appAsset.editState.ciFilter)
        completion(original?.asUIImage, filtered?.asUIImage)
    }

    public func willBeginProcessing() {
        editViewDockContent?.view.isUserInteractionEnabled = false
    }

    public func willEndProcessing() {
        editViewDockContent?.view.isUserInteractionEnabled = true
    }

    public func selectEditState(value: ImageEditStateValue?, in content: AppDockContent?) {
        if let filter = value?.ciFilter?.copy() as? CIFrameFillFilter {
            (content as? ResizerAppDockContent)?.selectFilter(filter)
        }
    }
}

enum AspectRatioOption: Int, Codable, CaseIterable{
    case original
    case square
    case ratio12x6_75
    case ratio4x5
    case ratio1_91x1
    case ratio9x16
    case ratio16x9
    case ratio9x21
    case ratio21x9
    case devicePortrait
    case deviceLandscape

    var name: String {
        switch self {
        case .original: return "Original"
        case .square: return "1:1"
        case .ratio12x6_75: return "12:6.75"
        case .ratio4x5: return "4:5"
        case .ratio1_91x1: return "1.91:1"
        case .ratio9x16: return "9:16"
        case .ratio16x9: return "16:9"
        case .ratio9x21: return "9:21"
        case .ratio21x9: return "21:9"
        case .devicePortrait: return "devicePortrait"
        case .deviceLandscape: return "deviceLandscape"
        }
    }

    var description: String? {
        switch self {
        case .original: return nil
        case .square: return "Square".localized
        case .ratio12x6_75: return "Twitter".localized
        case .ratio4x5: return "Instagram Vertical".localized
        case .ratio1_91x1: return "Instagram Landscape".localized
        case .ratio16x9: return "Youtube".localized
        case .ratio9x16: return "Instagram Story"
        case .ratio21x9: return "Ultra Wide".localized
        case .ratio9x21: return "Ultra Wide Vertical".localized
        case .devicePortrait: return "\(UIDevice.current.localizedModel) \("Portrait".localized)"
        case .deviceLandscape: return "\(UIDevice.current.localizedModel) \("Landscape".localized)"
        }
    }

    var title: String {
        return description ?? name
    }

    var aspectRatio: CGSize {
        switch self {
        case .original: return CGSize.zero
        case .square: return CGSize(width: 1, height: 1)
        case .ratio12x6_75: return CGSize(width: 12, height: 6.75)
        case .ratio4x5: return CGSize(width: 4, height: 5)
        case .ratio1_91x1: return CGSize(width: 1.91, height: 1)
        case .ratio16x9: return CGSize(width: 16, height: 9)
        case .ratio9x16: return CGSize(width: 9, height: 16)
        case .ratio9x21: return CGSize(width: 9, height: 21)
        case .ratio21x9: return CGSize(width: 21, height: 9)
        case .devicePortrait: return UIScreen.main.nativeBounds.size
        case .deviceLandscape: return CGSize(width: UIScreen.main.nativeBounds.size.height, height: UIScreen.main.nativeBounds.width)
        }
    }

    func aspectFitSize(in size: CGSize) -> CGSize {
        return aspectFit(in: size).size
    }

    func aspectFit(in size: CGSize) -> CGRect {
        guard self != .original else { return CGRect(origin: .zero, size: size) }
        return AVMakeRect(aspectRatio: aspectRatio, insideRect: CGRect(origin: .zero, size: size))
    }

    var normalizedSize: CGSize {
        return aspectRatio.aspectFit(in: CGSize(width: 1, height: 1))
    }
}

private class CIFrameFillFilter: CIFilter {
    static let BlurFilledBackgroundColorValue:Int = 0xEFFFFFFF
    static let BlurFilledBackgroundColor:UIColor = UIColor(rgba:BlurFilledBackgroundColorValue)

    var aspectRatioOption: AspectRatioOption = .original

    var backgroundColor: UIColor = UIColor(rgba: 0xFFFFFFFF)

    var borderWidth: CGFloat = 0

    init(aspectRatioOption: AspectRatioOption) {
        super.init()
        self.name = aspectRatioOption.name
        self.aspectRatioOption = aspectRatioOption
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = CIFrameFillFilter(aspectRatioOption: aspectRatioOption)
        copy.backgroundColor = backgroundColor
        copy.borderWidth = borderWidth
        return copy
    }

    @objc dynamic var inputImage : CIImage?

    override var outputImage: CIImage? {
        return autoreleasepool {
            guard let image = inputImage else { return nil }

            let inputSize = image.extent.size
            var outputSize = aspectRatioOption.aspectFitSize(in: inputSize)

            let borderInset = borderWidth * (outputSize.minLength / 4)
            let maximumBorderInset = borderWidth * (outputSize.maxLength / 4)
            if aspectRatioOption == .original {
                if outputSize.height > outputSize.width {
                    outputSize.height -= (maximumBorderInset - borderInset) * 2
                }
                else {
                    outputSize.width -= (maximumBorderInset - borderInset) * 2
                }
            }
            let outputRect = CGRect(origin: .zero, size: outputSize)
            let aspectFitRect = AVMakeRect(aspectRatio: inputSize, insideRect: outputRect.inset(by: UIEdgeInsets(top: borderInset, left: borderInset, bottom: borderInset, right: borderInset)))

            let resizedImage = image.resizeAspectFit(in: aspectFitRect)
            let colorImage: CIImage

            //INFO: blur mode
            if backgroundColor == type(of: self).BlurFilledBackgroundColor, let bgImage = image.asCGImage?.blur() {
                let fillSize = image.extent.size.aspectFill(in: outputRect.size)
                colorImage = CIImage(cgImage: bgImage).resizeAspectFit(fillSize)
            }
            else {
                colorImage = CIImage(color: CIColor(color: backgroundColor))
            }

            return resizedImage.composited(over: colorImage).cropped(to: outputRect)
        }
    }
}

private class CIFrameFilterItem: CIFilterItem {
    override init(_ filter: CIFilter? = nil) {
        super.init(filter)
    }

    convenience init(_ filter: CIFilter? = nil, backgroundColor: UIColor?, borderWidth: CGFloat = 0) {
        self.init(filter)

        self.backgroundColor = backgroundColor ?? UIColor(rgba: 0xFFFFFFFF)
        (ciFilter as? CIFrameFillFilter)?.borderWidth = borderWidth
    }

    private var backgroundColor: UIColor {
        set {
            (ciFilter as? CIFrameFillFilter)?.backgroundColor = newValue
        }

        get {
            return (ciFilter as? CIFrameFillFilter)?.backgroundColor ?? UIColor(rgba: 0xFFFFFFFF)
        }
    }

    var borderWidth: CGFloat {
        return (ciFilter as? CIFrameFillFilter)?.borderWidth ?? 0
    }

    override var doubleValue: Double? {
        return Double(borderWidth)
    }

    override var normalizedSize: CGSize? {
        let filter = ciFilter as? CIFrameFillFilter
        guard filter?.aspectRatioOption != .original else { return nil }
        return filter?.aspectRatioOption.normalizedSize
    }

    override var color: UIColor? {
        return self.backgroundColor
    }

    override func playerItem(with video: AVAsset, for exporting: Bool = false) -> AVPlayerItem? {
        guard
            let videoTrack = video.tracks(withMediaType: .video).first
        else { return nil }

        let isOriginalRatio = (ciFilter as? CIFrameFillFilter)?.aspectRatioOption == .original

        let composition = AVMutableComposition()
        guard let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }
        if (try? videoCompositionTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: video.duration), of: videoTrack, at: CMTime.zero)) == nil {
            composition.removeTrack(videoCompositionTrack)
        }

        videoCompositionTrack.preferredTransform = videoTrack.preferredTransform

        if let audioTrack = video.tracks(withMediaType: .audio).first, let compositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            if (try? compositionTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: video.duration), of: audioTrack, at: CMTime.zero)) == nil {
                composition.removeTrack(compositionTrack)
            }
        }

        let normalizedSize = self.normalizedSize ?? videoCompositionTrack.naturalSize.applying(videoCompositionTrack.preferredTransform).magnitude.aspectFit(in: CGSize(width: 1, height: 1))

        var renderSize = CGSize.zero

        if exporting {
            let inputSize = videoCompositionTrack.naturalSize.applying(videoCompositionTrack.preferredTransform).magnitude
            let borderInset = borderWidth * (videoCompositionTrack.naturalSize.minLength / 4)
            let maximumBorderInset = borderWidth * (videoCompositionTrack.naturalSize.maxLength / 4)
            var outputSize = normalizedSize.applying(CGAffineTransform(scaleX: inputSize.maxLength, y: inputSize.maxLength))
            if isOriginalRatio {
                if outputSize.height > outputSize.width {
                    outputSize.height -= (maximumBorderInset - borderInset) * 2
                }
                else {
                    outputSize.width -= (maximumBorderInset - borderInset) * 2
                }
            }

            renderSize = outputSize
        }
        else {
            let inputSize = videoCompositionTrack.naturalSize
            let borderInset = borderWidth * (videoCompositionTrack.naturalSize.minLength / 4)
            let maximumBorderInset = borderWidth * (videoCompositionTrack.naturalSize.maxLength / 4)
            var outputSize = normalizedSize.applying(CGAffineTransform(scaleX: inputSize.maxLength, y: inputSize.maxLength).concatenating(videoCompositionTrack.preferredTransform.inverted())).magnitude
            if isOriginalRatio {
                if outputSize.height > outputSize.width {
                    outputSize.height -= (maximumBorderInset - borderInset) * 2
                }
                else {
                    outputSize.width -= (maximumBorderInset - borderInset) * 2
                }
            }

            renderSize = outputSize.applying(videoCompositionTrack.preferredTransform).magnitude
        }

        let currentFilter = self.ciFilter
        let videoComposition = AVMutableVideoComposition(asset: video) { [weak self] (request) in
            let image = request.sourceImage.applyFilter(ciFilter: currentFilter).resizeAspectFit(renderSize)
            if currentFilter != self?.ciFilter {
                request.finish(with: NSError(domain: "AVAsset", code: -500, userInfo: nil)) // User Interrupt
            }
            else {
                request.finish(with: image, context: nil)
            }
        }
        videoComposition.renderSize = AVVideoComposition.makeVideoRenderSize(renderSize)

        let playerItem = AVPlayerItem(asset: composition)
        playerItem.videoComposition = videoComposition

        return playerItem
    }
}

fileprivate class ResizerAppDockContent: NSObject, AppDockContent {
    private lazy var filters: [CIFrameFillFilter] = [
        CIFrameFillFilter(aspectRatioOption: AspectRatioOption.original),
        CIFrameFillFilter(aspectRatioOption: AspectRatioOption.square),
        CIFrameFillFilter(aspectRatioOption: AspectRatioOption.ratio12x6_75),
        CIFrameFillFilter(aspectRatioOption: AspectRatioOption.ratio4x5),
        CIFrameFillFilter(aspectRatioOption: AspectRatioOption.ratio1_91x1),
        CIFrameFillFilter(aspectRatioOption: AspectRatioOption.ratio9x16),
        CIFrameFillFilter(aspectRatioOption: AspectRatioOption.ratio16x9),
        CIFrameFillFilter(aspectRatioOption: AspectRatioOption.ratio21x9),
        CIFrameFillFilter(aspectRatioOption: AspectRatioOption.ratio9x21),
        CIFrameFillFilter(aspectRatioOption: AspectRatioOption.devicePortrait),
        CIFrameFillFilter(aspectRatioOption: AspectRatioOption.deviceLandscape),
    ]

    struct CIFilterCollectionItem: AppUICollectionItem {
        var title: String?
        var image: UIImage?
        var action: (() -> Void)?

        var filter: CIFilter?
    }

    @objc dynamic var filterItem: CIFilterItem?

    private var selectedFilter: CIFrameFillFilter?

    private var selectedBackgroundColor: UIColor? {
        didSet {
            let buttonSize = CGSize(width: 20, height: 20)
            let buttonRect = CGRect(origin: .zero, size: buttonSize)

            if selectedBackgroundColor == CIFrameFillFilter.BlurFilledBackgroundColor{
                colorPickerButton.setImage(R.image.resizerBlurColorIcon()?.resize(aspectFit: buttonRect.size.screenScaled()), for: .normal)

            } else{
                let image = UIImage(path: UIBezierPath(ovalIn: buttonRect.inset(by: UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2))), fillColor: selectedBackgroundColor ?? UIColor(rgba: 0xFFFFFFFF), strokeColor: .white)?.withRenderingMode(.alwaysOriginal)
                colorPickerButton.setImage(image, for: .normal)
            }
        }
    }
    private var selectedBorderWidth: CGFloat { return CGFloat(borderWidthSlider.value) }

    private lazy var items: [CIFilterCollectionItem] = {
        var items = [CIFilterCollectionItem]()

        let imageInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        let imageSize = CGSize(width: 32, height: 32)

        let originalFilter = self.filters[0]

        items.append(CIFilterCollectionItem(title: "Original".localized, image: UIImage(path: UIBezierPath(roundedRect: CGRect(origin: .zero, size: imageSize).inset(by: imageInsets), cornerRadius: imageSize.minLength / 8), fillColor: UIColor(white: 1, alpha: 0.2), strokeColor: .white), action: {
            self.selectedFilter = originalFilter
            self.filterItem = CIFrameFilterItem(originalFilter, backgroundColor: self.selectedBackgroundColor, borderWidth: self.selectedBorderWidth)
        }, filter: originalFilter))

        items += self.filters[1...].map({ (filter) -> CIFilterCollectionItem in
            let iconSize = imageSize.applying(CGAffineTransform(scaleX: filter.aspectRatioOption.normalizedSize.width, y: filter.aspectRatioOption.normalizedSize.height))
            let icon = UIImage(path: UIBezierPath(roundedRect: CGRect(origin: .zero, size: iconSize).inset(by: imageInsets), cornerRadius: iconSize.minLength / 8), fillColor: UIColor(white: 1, alpha: 0.9), strokeColor: .white)

            return CIFilterCollectionItem(title: filter.aspectRatioOption.title, image: icon, action: {
                self.selectedFilter = filter
                self.filterItem = CIFrameFilterItem(filter, backgroundColor: self.selectedBackgroundColor, borderWidth: self.selectedBorderWidth)
            }, filter: filter)
        })

        return items
    }()

    private lazy var collectionView: AppUICollectionView = {
        let view = AppUICollectionView(items: items)
        view.cellAppearance.size = CGSize(width: 64, height: 52)
        view.cellAppearance.spacing = 1
        view.cellAppearance.imageInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        view.cellAppearance.imageContentMode = UIView.ContentMode.scaleAspectFit

        return view
    }()

    private lazy var toolBar: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [colorPickerButton, borderWidthSlider])
        stackView.alignment = UIStackView.Alignment.fill
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.spacing = 4
        return stackView
    }()

    lazy var view: UIView = {
        let view = UIView(frame: .zero)
        view.addSubview(collectionView)
        view.addSubview(toolBar)

        toolBar.translatesAutoresizingMaskIntoConstraints = false
        view.bottomAnchor.constraint(equalTo: toolBar.bottomAnchor, constant: 4).isActive = true
        toolBar.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 30).isActive = true
        view.trailingAnchor.constraint(greaterThanOrEqualTo: toolBar.trailingAnchor, constant: 30).isActive = true
        toolBar.heightAnchor.constraint(lessThanOrEqualToConstant: 32).isActive = true
        toolBar.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        toolBar.widthAnchor.constraint(lessThanOrEqualToConstant: 320).isActive = true
        toolBar.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: toolBar.topAnchor, constant: 4).isActive = true

        colorPickerButton.translatesAutoresizingMaskIntoConstraints = false
        colorPickerButton.heightAnchor.constraint(equalTo: toolBar.heightAnchor).isActive = true
        colorPickerButton.widthAnchor.constraint(equalTo: colorPickerButton.heightAnchor, multiplier: 1).isActive = true

        return view
    }()

    private lazy var colorPickerButton: UIButton = {
        let button = UIButton(type: UIButton.ButtonType.system)
        button.contentVerticalAlignment = .center
        button.contentHorizontalAlignment = .center
        button.imageView?.contentMode = .scaleAspectFit
        button.imageEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        button.addTarget(self, action: #selector(self.openColorPicker), for: .touchUpInside)
        return button
    }()

    private lazy var borderWidthSlider: UISlider = {
        let slider = UISlider(frame: .zero)
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.isContinuous = true
        slider.addTarget(self, action: #selector(self.borderWidthDidChange), for: .valueChanged)
        return slider
    }()


    private lazy var colors: [UIColor] = [
        CIFrameFillFilter.BlurFilledBackgroundColor,
        UIColor(rgba:0xFFFFFFFF),
        UIColor(rgba:0x000000FF),
        UIColor(rgba:0x6ABB72FF),
        UIColor(rgba:0x3ABB9DFF),
        UIColor(rgba:0x4DA664FF),
        UIColor(rgba:0x2CA786FF),
        UIColor(rgba:0x5CADCFFF),
        UIColor(rgba:0x3585C5FF),
        UIColor(rgba:0x4590B6FF),
        UIColor(rgba:0x2F6CADFF),
        UIColor(rgba:0x485675FF),
        UIColor(rgba:0x29334DFF),
        UIColor(rgba:0x9069B5FF),
        UIColor(rgba:0x533D7FFF),
        UIColor(rgba:0xF2D46FFF),
        UIColor(rgba:0xF7C23EFF),
        UIColor(rgba:0xF79E3DFF),
        UIColor(rgba:0xEE7841FF),
        UIColor(rgba:0xE66B5BFF),
        UIColor(rgba:0xCC4846FF),
        UIColor(rgba:0xDC5047FF),
        UIColor(rgba:0xB33234FF),
        UIColor(rgba:0xA28F85FF),
        UIColor(rgba:0xEFEFEFFF),
        UIColor(rgba:0xD1D5D8FF),
        UIColor(rgba:0x75706BFF)
    ]

    @objc private func openColorPicker() {
        let picker = UIAlertController.actionSheet(title: "\n" + "Background Fill Color".localized, message: nil)
        picker.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))

        for color in colors {
            var accessoryImage = R.image.resizerBlurColorIcon()
            let title:String

            let accessoryImageRect = CGRect(origin: .zero, size: accessoryImage?.size ?? CGSize(width: 10, height: 10))

            if color == CIFrameFillFilter.BlurFilledBackgroundColor{
                title = "Blur Background".localized
            }else{
                title = color.hexCode()

                let strokeWidth: CGFloat = 2
                let accessoryImageInset = UIEdgeInsets(top: strokeWidth, left: strokeWidth, bottom: strokeWidth, right: strokeWidth)
                accessoryImage = UIImage(path: UIBezierPath(ovalIn: accessoryImageRect.inset(by: accessoryImageInset)), fillColor: color, strokeColor: .white, strokeWidth: strokeWidth)?.resize(aspectFit: accessoryImageRect.size)?.withRenderingMode(.alwaysOriginal)
            }

            let action = UIAlertAction(title: title, style: .default, handler: { _ in
                self.selectedBackgroundColor = color
                self.filterItem = CIFrameFilterItem(self.selectedFilter, backgroundColor: color, borderWidth: self.selectedBorderWidth)

                self.updateBorderSlider()
            })

            if let accessoryImage = accessoryImage{
                action.accessoryImage = accessoryImage
            }

            picker.addAction(action)
        }

        DispatchQueue.main.async {
            UIViewController.present(picker, animated: true)
        }
    }

    private func updateBorderSlider() {
        let estimatedHeight = max(4, borderWidthSlider.height * CGFloat(borderWidthSlider.value)) / 6

        let minTrackPath = UIBezierPath(roundedRect: CGRect(origin: .zero, size: CGSize(width: estimatedHeight, height: estimatedHeight)), byRoundingCorners: [UIRectCorner.topLeft, UIRectCorner.bottomLeft], cornerRadii: CGSize(width: estimatedHeight / 2, height: estimatedHeight / 2))

        let maxTrackPath = UIBezierPath(roundedRect: CGRect(origin: .zero, size: CGSize(width: estimatedHeight, height: estimatedHeight)), byRoundingCorners: [UIRectCorner.topRight, UIRectCorner.bottomRight], cornerRadii: CGSize(width: estimatedHeight / 2, height: estimatedHeight / 4))

        borderWidthSlider.setMinimumTrackImage(UIImage(path: minTrackPath, fillColor: selectedBackgroundColor ?? .white)?.resizableImage(withCapInsets: UIEdgeInsets(top: estimatedHeight / 2, left: estimatedHeight, bottom: estimatedHeight / 2, right: 0), resizingMode: .stretch), for: .normal)
        borderWidthSlider.setMaximumTrackImage(UIImage(path: maxTrackPath, fillColor: selectedBackgroundColor ?? .white)?.resizableImage(withCapInsets: UIEdgeInsets(top: estimatedHeight / 2, left: 0, bottom: estimatedHeight / 2, right: estimatedHeight), resizingMode: .stretch), for: .normal)
    }

    @objc func borderWidthDidChange() {
        updateBorderSlider()

        DispatchQueue.main.async {
            self.filterItem = CIFrameFilterItem(self.selectedFilter, backgroundColor: self.selectedBackgroundColor, borderWidth: self.selectedBorderWidth)
        }
    }

    var selectedEditStateValue: ImageEditStateValue?

    fileprivate func indexOfItem(by filterName: String?) -> Int? {
        return items.firstIndex(where: { $0.filter?.name == filterName })
    }

    fileprivate func selectItem(by filterName: String?) {
        let index = indexOfItem(by: filterName) ?? 0
        collectionView.selectItem(at: IndexPath(item: index, section: 0), animated: true)
    }

    fileprivate func selectFilter(_ filter: CIFrameFillFilter?) {
        selectItem(by: filter?.name)

        selectedFilter = filter
        selectedBackgroundColor = filter?.backgroundColor
        borderWidthSlider.value = Float(filter?.borderWidth ?? 0)

        updateBorderSlider()
    }

    fileprivate func getFilter(by filterName: String?) -> CIFrameFillFilter? {
        let index = indexOfItem(by: filterName) ?? 0
        return self.filters[safe: index]
    }

    var contentScrollable: AppDockContentScrollable? {
        return AppDockScrollableContent(collectionView.collectionView)
    }

    var preferences: AppDockContentPreferable? {
        var preferences = AppDockContentPreferences()
        preferences.preferredHeight = 120
        return preferences
    }

    func willSetContentView(_ view: UIView, dock: AppDock) {

    }

    func didSetContentView(_ view:UIView, dock:AppDock) {
        view.tintColor = view.colorTheme.tintColor
        collectionView.tintColor = view.colorTheme.tintColor
        collectionView.cellAppearance.selectedStateColor = ResizerApp.info.themeColor
        collectionView.cellAppearance.selectedStateBorderWidth = 2
        collectionView.cellAppearance.selectedStateCornerRadius = 6
        collectionView.reloadData()
    }
}

class _ResizerAppAsset: _FiltersAppAsset {
    public override var outputSize: CGSize {
        let preferredOutputSize = super.outputSize
        if let borderWidth = editState.doubleValue, editState.normalizedSize == nil {
            let borderInset = CGFloat(borderWidth) * (preferredOutputSize.minLength / 4)
            let maximumBorderInset = CGFloat(borderWidth) * (preferredOutputSize.maxLength / 4)

            var outputSize = preferredOutputSize
            if preferredOutputSize.height > preferredOutputSize.width {
                outputSize.height -= (maximumBorderInset - borderInset) * 2
            }
            else {
                outputSize.width -= (maximumBorderInset - borderInset) * 2
            }

            return outputSize
        }
        else {
            return preferredOutputSize
        }
    }
}

private class _ResizerAppTask: AppTaskPrototype, AppTaskable {
    public typealias ParamType = _ResizerAppAsset
    public typealias ResultType = PHAssetResultItem

    public func cancel(_ param: AppTaskParamable, _ async: AsyncWaitSignalable){

        (param as? _ResizerAppAsset)?.cancelAllRequestIDs()
        (param as? _ResizerAppAsset)?.cancelProcessing()
    }

    public func perform(_ param: AppTaskParamable, _ async: AsyncWaitSignalable) throws -> AppTaskResultable? {
        assert(param is _ResizerAppAsset, "TaskParamable type of this app is \(_ResizerAppAsset.self)")
        guard let _param = param as? _ResizerAppAsset else{
            throw AppTaskError.invalidParam
        }
        return try self._perform(_param, async)
    }

    private func _perform(_ assetItem: _ResizerAppAsset, _ async: AsyncWaitSignalable) throws -> PHAssetResultItem?  {
        var result: PHAssetResultItem?

        async.begin()

        DispatchQueue(label: "com.stells.internal."+fileName(), qos: .utility).async {
            assetItem.runEditing({ (progress) in
                AppAssetItemProgressNotification.update(item: assetItem, progress: progress)
            }) { (asset, editingResultItems, contentEditingOutput) in
                if let asset = asset, let contentEditingOutput = contentEditingOutput {
                    var editInfo: [String: Any] = [:]
                    if let filter = assetItem.editState.ciFilter as? CIFrameFillFilter {
                        editInfo["filterName"] = filter.name
                        editInfo["borderWidth"] = Float(filter.borderWidth)
                    }
                    contentEditingOutput.adjustmentData = PAPAdjustmentData.createAdjustmentData(for: ResizerApp.self, editInfo: editInfo, from: asset)

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

private extension AspectRatioOption{
    var intentActionName:String{
        if let d = description{
            return "Resize the last item to %@".localizedFormatted(d)
        }
        return "Undefined"
    }
}

extension ResizerApp: UIApplicationDelegateLaunchableApp {

    private static var AspectRatioOptions:[AspectRatioOption]{
        return AspectRatioOption.allCases.filter({
            switch $0.description {
            case "Square".localized, "Twitter".localized, "Youtube".localized:
                    return true
                default:
                    return false
            }
        })
    }

    static var intents: [INIntent]{
        if #available(iOS 12.0, *) {
            return defaultIntents + AspectRatioOptions.map({ intentTo(do:$0.intentActionName) })
        } else{
            return []
        }
    }

    func didLaunchHandling(with userActivity: NSUserActivity) {

        if #available(iOS 12.0, *) {
            guard let intent = userActivity.interaction?.intent else {
                return
            }

            if let i = intent as? DoAnyIntent, let name = i.doWhat{

                for c in AspectRatioOption.allCases where c.intentActionName == name{
                    (self.content as? ResizerAppDockContent)?.selectItem(by: c.name)

                    DispatchQueue.global(qos: .userInteractive).async{ [unowned self] in

                        //find latest asset with matched converter
                        let foundAsset = PHAssets.fetched.searchLast{ i, a in
                            return self.shouldSelect(item: AppAsset(a))
                        }

                        if let foundAsset = foundAsset{
                            DispatchQueue.main.async{
                                assert(self.photoPickerCallee != nil)
                                self.photoPickerCallee?.selectInCurrentContext(with: foundAsset, animated: true)
                                self.photoPickerCallee?.performInSelectionContext()
                            }
                        }
                    }

                    break
                }
            }
        }

    }

    func didLaunchHandling(with shortcutItem: UIApplicationShortcutItem) {
    }

}
