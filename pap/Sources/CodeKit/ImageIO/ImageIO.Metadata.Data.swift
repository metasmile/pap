//
// Created by BLACKGENE on 19/04/2018.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation
import ImageIO
import CoreImage

extension Data {

    func getMetadata() -> [String: Any]? {
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

    func getMetadataValue(dictionary:String?=nil, property:String) -> Any? {
        guard let metadata = getMetadata() else{
            return nil
        }
        if let d = dictionary, let dictionaryItemDict = metadata[d] as? [String: Any]{
            return dictionaryItemDict[property]
        }
        return metadata[property]
    }

    func setMetadata(with metadata:[String:Any]?) -> Data{
        let source = CGImageSourceCreateWithData(self as CFData, nil)!
        let imageData = CFDataCreateMutable(nil, 0)!
        let destination = CGImageDestinationCreateWithData(imageData, "public.jpeg" as CFString, 1, nil)!
        if let metadata = metadata{
            CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)

        }else {
            if let dict = self.getMetadata(){
                var newDict = dict
                for (k,v) in dict where ImageMetadata.isValueVoid(v) == false{
                    newDict[k] = ImageMetadata.getVoidValue(v)
                }
                CGImageDestinationAddImageFromSource(destination, source, 0, newDict as CFDictionary)
            }
        }
        CGImageDestinationFinalize(destination)
        return imageData as Data
    }

    func updateMetadata(dictionary:String, property:String, value:Any?) -> Data {
        if let metadata = getMetadata(){
            return updateMetadata(with:metadata, dictionary:dictionary, property: property, value:value)
        }
        return self
    }

    @discardableResult
    func updateMetadata(with metadata:[String:Any], dictionary:String, property:String, value:Any?) -> Data {
#if DEBUG
        if value == nil{
            print("[!] WARNING: Value is nil, means that remove property itself, but it cannot be guaranteed to remove while actually handling on OS.")
        }
#endif
        return setMetadata(with: metadata.updateMetadata(dictionary: dictionary, property: property, value: value))
    }

    func purgeMetadata(with metadata:[String:Any], dictionary:String, property:String) -> Data {
        return setMetadata(with: metadata.purgeMetadata(dictionary: dictionary, property: property))
    }

    func purgeMetadata(with metadata:[String:Any], for collection: ImageMetadataPropertyCollection?) -> Data {
        return setMetadata(with: metadata.purgeMetadata(for: collection))
    }

    func setMetadata(with metadata:[String:Any], comment: String?, software: String?) -> Data {
        let newMetadata = metadata.changeMetadata(with: nil, comment: comment, software: software, exifOrientation: nil)

        return setMetadata(with: newMetadata)
    }

    func setMetadata(with metadata:[String:Any], comment: String?, software: String?, exifOrientation: CGImagePropertyOrientation?) -> Data {
        let newMetadata = metadata.changeMetadata(with: nil, comment: comment, software: software, exifOrientation: exifOrientation)
        return setMetadata(with: newMetadata)
    }

    func changeMetadata(metadata: [String: Any], imageSize: CGSize?, comment: String?, software: String?, exifOrientation: CGImagePropertyOrientation?) -> [String: Any] {
        var newMetadata = metadata
        var exifdata = metadata[ImageMetadata.Dictionary.Exif] as? [String: Any]
        var tiffdata = metadata[ImageMetadata.Dictionary.TIFF] as? [String: Any]
        if exifdata == nil {
            exifdata = [String:Any]()
        }
        if tiffdata == nil {
            tiffdata = [String:Any]()
        }

        if let imageSize = imageSize {
            newMetadata.updateValue(imageSize.width, forKey: ImageMetadata.PixelWidth )
            newMetadata.updateValue(imageSize.height, forKey: ImageMetadata.PixelHeight )
            exifdata!.updateValue(imageSize.width, forKey: ImageMetadata.Property.ExifPixelXDimension )
            exifdata!.updateValue(imageSize.height, forKey: ImageMetadata.Property.ExifPixelYDimension )
        }

        if let comment = comment {
            exifdata!.updateValue(comment, forKey: ImageMetadata.Property.ExifUserComment )
        }

        if let software = software {
            tiffdata!.updateValue(software, forKey: ImageMetadata.Property.TIFFSoftware )
        }

        if let exifOrientation = exifOrientation {
            newMetadata.updateValue(exifOrientation.rawValue, forKey: ImageMetadata.Orientation)
            tiffdata!.updateValue(exifOrientation.rawValue, forKey: ImageMetadata.Property.TIFFOrientation )
        }

        newMetadata.updateValue(exifdata!, forKey: ImageMetadata.Dictionary.Exif )
        newMetadata.updateValue(tiffdata!, forKey: ImageMetadata.Dictionary.TIFF )

        return newMetadata
    }
}