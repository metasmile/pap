//
// Created by BL?ACKGENE on 10.?07.18.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation
import Photos
import MetalPerformanceShaders
import MetalKit
import Vision

typealias GarbageDetectorInput = PHAssetParamable

protocol _GarbageDetector: AsyncProcessor where Self.OutputType==Bool {}

protocol _PHAssetGarbageDetector: _GarbageDetector where Self.InputType==GarbageDetectorInput {}

//INFO: lighter detector, higher priority.
enum PHAssetGarbageDetectingPriority:Int {
    case lowest
    case low
    case normal
    case high
}

class PHAssetGarbageDetector : NSObject, _PHAssetGarbageDetector{
    required public override init() {}

    class var identifier: String {
        return String(describing:self)
    }

    class var shouldCacheResults:Bool{
        return true
    }

    class var priority: PHAssetGarbageDetectingPriority {
        return .normal
    }

    class var label:String{
        return "Undefined"
    }

    class var iconImageName:String?{
        return nil
    }

    class var iconImageShouldUseTintColor:Bool{
        return true
    }

    class var needsCachingRequestOptions: [PHAssetRequestOption]?{
        return nil
    }

    func process(input: GarbageDetectorInput, _ asyncSignal: AsyncWaitSignalable) -> Bool? {
        return nil
    }
}

class PHAssetGarbageDetector_Screenshots : PHAssetGarbageDetector{
    override class var label:String{
        return "Screenshots".localized
    }

    override func process(input: GarbageDetectorInput,_ asyncSignal: AsyncWaitSignalable) -> Bool? {
        return input.asset.mediaType == .image && input.asset.mediaSubtypes.contains(.photoScreenshot) //FIXME: always true??
    }
}

class PHAssetGarbageDetector_VideosFromScreenRecorder: PHAssetGarbageDetector{
    override class var label:String{
        return "Videos from Screen Recorder".localized
    }

    override func process(input: GarbageDetectorInput,_ asyncSignal: AsyncWaitSignalable) -> Bool? {
        return input.asset.videoType == .screenRecordedVideo
    }
}

class PHAssetGarbageDetector_Flashlight: PHAssetGarbageDetector{
    override class var label:String{
        return "Flashlight".localized
    }

    private let firedFlags = Set<Int>([
        0x1//=Fired
        ,0x5//=Fired, Return not detected
        ,0x7//=Fired, Return detected
        ,0x9//=On, Fired
        ,0x19//=Auto, Fired
        ,0x1d//=Auto, Fired, Return not detected
        ,0x1f//=Auto, Fired, Return detected
        ,0x41//=Fired, Red-eye reduction
        ,0x45//=Fired, Red-eye reduction, Return not detected
        ,0x47//=Fired, Red-eye reduction, Return detected
        ,0x59//=Auto, Fired, Red-eye reduction
        ,0x5d//=Auto, Fired, Red-eye reduction, Return not detected
        ,0x5f//=Auto, Fired, Red-eye reduction, Return detected
    ])

    override func process(input: GarbageDetectorInput,_ asyncSignal: AsyncWaitSignalable) -> Bool? {
        guard input.asset.mediaType == .image else { return false }

        let option = PHContentEditingInputRequestOptions()
        option.isNetworkAccessAllowed = false
        option.canHandleAdjustmentData = { _ -> Bool in
            return false
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        if let data = input.asset.requestImageData(options: options, asyncSignal).data{
            if let lensMake = data.getMetadataValue(dictionary: ImageMetadata.Dictionary.Exif, property: ImageMetadata.Property.ExifLensMake) as? String{
                if lensMake.trimmed == "Apple", let flashValue = data.getMetadataValue(dictionary: ImageMetadata.Dictionary.Exif, property: ImageMetadata.Property.ExifFlash) as? Int{
                    return firedFlags.contains(flashValue)
                }
            }
        }

        return false
    }
}

class PHAssetGarbageDetector_TooCloseupFace: PHAssetGarbageDetector {

    override class var priority: PHAssetGarbageDetectingPriority {
        return .low
    }

    override class var label:String{
        return "Too Close-up Face".localized
    }

    private let allowedMinFaceBoundSizeRatio:CGFloat = 0.4

    override func process(input: GarbageDetectorInput,_ asyncSignal: AsyncWaitSignalable) -> Bool? {
        guard let faces = input.asset.asCIImage?.asFaceBoundingBoxes else{
            return false
        }

        let rect = faces.biggest()
        return rect.width*rect.height>=self.allowedMinFaceBoundSizeRatio
    }
}

class PHAssetGarbageDetector_VideosWithoutSound: PHAssetGarbageDetector{
    override class var label:String{
        return "Videos Without Sound".localized
    }

    override func process(input: GarbageDetectorInput,_ asyncSignal: AsyncWaitSignalable) -> Bool? {
        guard input.asset.mediaType == .video else { return false }

        let videoRequestOptions = PHVideoRequestOptions()
        videoRequestOptions.isNetworkAccessAllowed = false
        videoRequestOptions.deliveryMode = .automatic

        var haveNotSound = false
        asyncSignal.begin()
        PHImageManager.default().requestAVAsset(forVideo: input.asset, options: videoRequestOptions, resultHandler: { (asset: AVAsset?, audioMix: AVAudioMix?, info: [AnyHashable: Any]?) -> Void in
            haveNotSound = asset?.tracks(withMediaType: .audio).count ?? 0 == 0
            asyncSignal.end()
        })
        asyncSignal.waitUntilEnd()
        print(haveNotSound)
        return haveNotSound
    }
}

class PHAssetGarbageDetector_VideosSavedbyInstagramApp: PHAssetGarbageDetector{
    override class var label:String{
        return "Videos Saved by Instagram".localized
    }

    override func process(input: GarbageDetectorInput,_ asyncSignal: AsyncWaitSignalable) -> Bool? {
        guard input.asset.mediaType == .video else { return false }

        let videoRequestOptions = PHVideoRequestOptions()
        videoRequestOptions.isNetworkAccessAllowed = false
        videoRequestOptions.deliveryMode = .automatic

        var size = CGSize.zero
        asyncSignal.begin()
        PHImageManager.default().requestAVAsset(forVideo: input.asset, options: videoRequestOptions, resultHandler: { (asset: AVAsset?, audioMix: AVAudioMix?, info: [AnyHashable: Any]?) -> Void in
            if let track = asset?.tracks(withMediaType: .video).first{
                size = track.naturalSize.applying(track.preferredTransform)
            }
            asyncSignal.end()
        })
        asyncSignal.waitUntilEnd()

        return size.width==720.0 && size.height==720.0
    }
}

class PHAssetGarbageDetector_TooSlowShutterSpeed: PHAssetGarbageDetector{
    override class var label:String{
        return "Too Slow Shutter Speed".localized
    }

    override func process(input: GarbageDetectorInput,_ asyncSignal: AsyncWaitSignalable) -> Bool? {
        guard input.asset.mediaType == .image else { return false }

        let option = PHContentEditingInputRequestOptions()
        option.isNetworkAccessAllowed = false
        option.canHandleAdjustmentData = { _ -> Bool in
            return false
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false

        if let data = input.asset.requestImageData(options: options, asyncSignal).data{
            //ShutterSpeedValue
            //ExposureTime
            if let v = data.getMetadataValue(dictionary: ImageMetadata.Dictionary.Exif, property: ImageMetadata.Property.ExifExposureTime) as? Double{
                //ShutterSpeed=-log2(ExposureTime).
                return v >= 0.25
            }

            //OR

            if let v = data.getMetadataValue(dictionary: ImageMetadata.Dictionary.Exif, property: ImageMetadata.Property.ExifShutterSpeedValue) as? Double{
                return v < 2.1
            }
        }

        return false
    }
}

class PHAssetGarbageDetector_VideosShorterThan1Sec: PHAssetGarbageDetector{
    override class var priority: PHAssetGarbageDetectingPriority {
        return .high
    }

    override class var label:String{
        return "Videos Shorter Than 1 Second".localized
    }

    override func process(input: GarbageDetectorInput,_ asyncSignal: AsyncWaitSignalable) -> Bool? {
        //TODO: user defined custom duration
        return input.asset.mediaType == .video && input.asset.duration < 1
    }
}

class PHAssetGarbageDetector_SavedWithouttheCamera: PHAssetGarbageDetector{
    override class var label:String{
        return "All not taken with Camera".localized
    }

    override func process(input: GarbageDetectorInput,_ asyncSignal: AsyncWaitSignalable) -> Bool? {
        guard input.asset.mediaType == .image else { return false }

        let option = PHContentEditingInputRequestOptions()
        option.isNetworkAccessAllowed = false
        option.canHandleAdjustmentData = { _ -> Bool in
            return false
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        if let data = input.asset.requestImageData(options: options, asyncSignal).data{
            if let v = data.getMetadataValue(dictionary: ImageMetadata.Dictionary.Exif, property: ImageMetadata.Property.ExifLensMake) as? String{
                if v.trimmed == "Apple"{
                    return false
                }
            }
        }
        return true
    }
}

class PHAssetGarbageDetector_SavedWithBuiltInCamera: PHAssetGarbageDetector{
//    override class var iconImageName:String?{
//        return R.image.appUICameraIcon.name
//    }

//    override class var iconImageShouldUseTintColor:Bool{
//        return false
//    }

    override class var priority: PHAssetGarbageDetectingPriority {
        return .high
    }

    override class var label:String{
        return "Taken With Built-in Camera".localized
    }

    override func process(input: GarbageDetectorInput,_ asyncSignal: AsyncWaitSignalable) -> Bool? {
        guard input.asset.mediaType == .image else { return false }

        let option = PHContentEditingInputRequestOptions()
        option.isNetworkAccessAllowed = false
        option.canHandleAdjustmentData = { _ -> Bool in
            return false
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        if let data = input.asset.requestImageData(options: options, asyncSignal).data{
            if let v = data.getMetadataValue(dictionary: ImageMetadata.Dictionary.Exif, property: ImageMetadata.Property.ExifUserComment) as? String{
                if v.trimmed.contains(UICameraCaptureProcessor.ExifUserCommentIdentifier){
                    return true
                }
            }
        }

        return false
    }
}

/*
    Blurry
*/
//FIXME: Blurry is not detect only Blurred.
class PHAssetGarbageDetector_Blurry: PHAssetGarbageDetector{
    override class var label:String{
        return "Blur Rate".localized
    }

    override func process(input: GarbageDetectorInput,_ asyncSignal: AsyncWaitSignalable) -> Bool? {
        return self.detectBlurryImage(input)
    }

    private func detectBlurryImage(_ input: GarbageDetectorInput) -> Bool {
        let asset = input.asset
        // https://www.pyimagesearch.com/2015/09/07/blur-detection-with-opencv/
        // https://stackoverflow.com/questions/46893198/detecting-if-image-is-blurred-using-opencv
        //
        guard
                asset.imageType == .stillImage,
                let device = MTLCreateSystemDefaultDevice(),
                let commandQueue = device.makeCommandQueue(),
                let commandBuffer = commandQueue.makeCommandBuffer(),
                let ciImage = asset.asCIImage
                else { return false }


//        if let face = croppedFaceGroup(ciImage) {
//            ciImage = face
//        }

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: Int(ciImage.extent.width), height: Int(ciImage.extent.height), mipmapped: false)
        textureDescriptor.usage = [MTLTextureUsage.shaderRead, MTLTextureUsage.shaderWrite]

        guard
                let sourceTexture = device.makeTexture(descriptor: textureDescriptor),
                let binaryTexture = device.makeTexture(descriptor: textureDescriptor),
                let laplacianTexture = device.makeTexture(descriptor: textureDescriptor)
                else { return false }

        ImageAlignment.sharedCIContext.render(ciImage, to: sourceTexture, commandBuffer: commandBuffer, bounds: ciImage.extent, colorSpace: CGColorSpaceCreateDeviceRGB())

        MPSImageLaplacian(device: device).encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: laplacianTexture)
        MPSImageThresholdBinary(device: device, thresholdValue: 0.4, maximumValue: 1, linearGrayColorTransform: nil).encode(commandBuffer: commandBuffer, sourceTexture: laplacianTexture, destinationTexture: binaryTexture)

        let numberOfHistogramEntries = 256

        var histogramInfo = MPSImageHistogramInfo(
                numberOfHistogramEntries: numberOfHistogramEntries,
                histogramForAlpha: false,
                minPixelValue: vector_float4(0, 0, 0, 0),
                maxPixelValue: vector_float4(1, 1, 1, 1))

        let histogram = MPSImageHistogram(device: device, histogramInfo: &histogramInfo)
        let bufferLength = histogram.histogramSize(forSourceFormat: binaryTexture.pixelFormat)
        guard let histogramInfoBuffer = device.makeBuffer(length: bufferLength, options: []) else { return false }

        histogram.encode(to: commandBuffer, sourceTexture: binaryTexture, histogram: histogramInfoBuffer, histogramOffset: 0)

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let histogramContents = histogramInfoBuffer.contents().bindMemory(to: Float.self, capacity: numberOfHistogramEntries)

        let threshold = 0.000000000000000000000000000000000000000031 //TODO: this is a manual threshold
        let numberOfWhitePixels = histogramContents[numberOfHistogramEntries - 1]

        return numberOfWhitePixels < Float(threshold)
    }

    private func croppedFaceGroup(_ image: CIImage) -> CIImage? {
        if let unionBound = image.asFaceBoundingBoxes?.union(), unionBound.width * unionBound.height > 0.2{

            let transform = CGAffineTransform(scaleX: image.extent.width, y: image.extent.height)
            return image.cropped(to: unionBound.applying(transform))
        }
        return nil
    }
}
