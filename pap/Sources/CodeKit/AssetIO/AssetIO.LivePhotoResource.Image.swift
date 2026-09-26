//
//  AssetIO.LivePhotoResource.Image.swift
//  Live Photos
//
//  Originally Created by genadyo (github.com/genadyo).
//  Newly Written by metasmile (github.com/metasmile) on 9/12/16.
//

import Foundation
import ImageIO

public class LivePhotoImageResourceWriter: NSObject {
    private let kFigAppleMakerNote_AssetIdentifier = "17"

    @discardableResult
    public func write(from fromUrl:URL, to toUrl: URL, assetIdentifier : String) -> Bool {
        guard let data = fromUrl.asData else {
            return false
        }

        let updatedData:Data
        if let metadata = data._getMetadata(){
            updatedData = data._updateMetadata(with: metadata,
                    dictionary: kCGImagePropertyMakerAppleDictionary as String,
                    property: kFigAppleMakerNote_AssetIdentifier,
                    value: assetIdentifier)
        }else{
            updatedData = data._setMetadata(with: [
                kCGImagePropertyMakerAppleDictionary as String: [
                    kFigAppleMakerNote_AssetIdentifier:assetIdentifier
                ]
            ])
        }

        try? FileManager.default.removeItem(at: toUrl)
        
        do {
            try updatedData.write(to: toUrl)
            return true

        } catch _ {}

        return false
    }
}

private extension Data{
    func _getMetadata() -> [String: Any]? {
        let imageSource = CGImageSourceCreateWithData(self as CFData, nil)
        if let imageSource = imageSource {
            let options: [String: Any] = [kCGImageSourceShouldCache as String: false]
            let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, options as CFDictionary)

            return imageProperties as? [String: Any]
        } else {
            print("failed to read metadata")
            return nil
        }
    }

    func _setMetadata(with metadata:[String:Any]) -> Data{
        let source = CGImageSourceCreateWithData(self as CFData, nil)!
        let imageData = CFDataCreateMutable(nil, 0)!
        let destination = CGImageDestinationCreateWithData(imageData, "public.jpeg" as CFString, 1, nil)!
        CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)
        CGImageDestinationFinalize(destination)
        return imageData as Data
    }

    @discardableResult
    func _updateMetadata(with metadata:[String:Any], dictionary:String, property:String, value:Any?) -> Data {
#if DEBUG
        if value == nil{
            print("[!] WARNING: Value is nil, means that remove property itself, but it cannot be guaranteed to remove while actually handling on OS.")
        }
#endif
        var newMetadata = metadata
        var data = newMetadata[dictionary] as? [String:Any] ?? [String:Any]()
        if value == nil{
            data.removeValue(forKey: property)
        }else{
            data[property] = value
        }
        newMetadata[dictionary] = data
        return _setMetadata(with: newMetadata)
    }
}
