//
// Created by BLACKGENE on 28/03/2018.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation
import UIKit
import ImageIO

public func UIImageGIFRepresentation(with imageFiles: [URL], loopCount: Int = 0, frameDelay: Double, cancellation: (() -> Bool)? = nil, progressHandler: ((Progress) -> Void)? = nil) -> Data? {
    guard let url = UIImageGIFRepresentationURL(with: imageFiles, loopCount: loopCount, frameDelay: frameDelay, cancellation: cancellation, progressHandler: progressHandler) else { return nil }
    let gifData = try? Data(contentsOf: url)

    return gifData
}

public func UIImageGIFRepresentationURL(with imageFiles: [URL], loopCount: Int = 0, frameDelay: Double, cancellation: (() -> Bool)? = nil, progressHandler: ((Progress) -> Void)? = nil) -> URL? {
    let fileProperties = [
        ImageMetadata.Dictionary.GIF: [
            ImageMetadata.Property.GIFLoopCount: loopCount
        ]
    ]
    let frameProperties = [
        ImageMetadata.Dictionary.GIF: [
            ImageMetadata.Property.GIFDelayTime: frameDelay,
            ImageMetadata.ColorModel: ImageMetadata.ColorModelRGB
        ]
    ]

    let url = FileURL.temp("\(UUID().uuidString)", UTI.gif)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, imageFiles.count, nil) else { return nil }
    CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
    
    let progress = Progress(totalUnitCount: Int64(imageFiles.count))
    
    for imageFile in imageFiles {
        guard cancellation?() != true else { return nil }
        
        autoreleasepool {
            guard let cgImage = UIImage(contentsOfFile: imageFile.path)?.cgImage else { return }
            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
            
            progress.completedUnitCount += 1
            progressHandler?(progress)
        }
    }
    
    let success = CGImageDestinationFinalize(destination)
    
    return success ? url : nil
}

public func UIImageGIFRepresentationURL(with imageFilesWithFrameDelay: [(URL, Double)], loopCount: Int = 0, cancellation: (() -> Bool)? = nil, progressHandler: ((Progress) -> Void)? = nil) -> URL? {
    let fileProperties = [
        ImageMetadata.Dictionary.GIF: [
            ImageMetadata.Property.GIFLoopCount: loopCount
        ]
    ]

    let url = FileURL.temp(UUID().uuidString, UTI.gif)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, imageFilesWithFrameDelay.count, nil) else { return nil }
    CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
    
    let progress = Progress(totalUnitCount: Int64(imageFilesWithFrameDelay.count))
    
    for (imageFile, frameDelay) in imageFilesWithFrameDelay {
        guard cancellation?() != true else { return nil }
        
        autoreleasepool {
            guard let cgImage = UIImage(contentsOfFile: imageFile.path)?.cgImage else { return }
            
            let frameProperties = [
                ImageMetadata.Dictionary.GIF: [
                    ImageMetadata.Property.GIFDelayTime: frameDelay,
                    ImageMetadata.ColorModel: ImageMetadata.ColorModelRGB
                ]
            ]
            
            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
            
            progress.completedUnitCount += 1
            progressHandler?(progress)
        }
    }
    
    let success = CGImageDestinationFinalize(destination)
    
    return success ? url : nil
}

//https://gist.github.com/powhu/00acd9d34fa8d61d2ddf5652f19cafcf
public func UIImageGIFRepresentation(_ image: UIImage) -> Data? {
    return UIImageGIFRepresentation(image, duration: 0.0, loopCount: 0)
}

public func UIImageGIFRepresentation(_ image: UIImage, duration: TimeInterval, loopCount: Int) -> Data? {
    guard let images = image.images else {
        return nil
    }

    let frameCount = images.count
    let gifDuration = duration <= 0.0 ? image.duration / Double(frameCount) : duration / Double(frameCount)

    let frameProperties = [ImageMetadata.Dictionary.GIF: [ImageMetadata.Property.GIFDelayTime: gifDuration]]
    let imageProperties = [ImageMetadata.Dictionary.GIF: [ImageMetadata.Property.GIFLoopCount: loopCount]]

    let data = NSMutableData()

    guard let destination = CGImageDestinationCreateWithData(data, "com.compuserve.gif" as CFString, frameCount, nil) else {
        return nil
    }
    CGImageDestinationSetProperties(destination, imageProperties as CFDictionary)

    for image in images {
        if let cgImage = image.cgImage{
            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
        }
    }

    return CGImageDestinationFinalize(destination) ? Data(data as Data) : nil
}


public extension UIImage {
    static func animatedImageWithGIFData(_ data: Data) -> UIImage? {
        return animatedImageWithGIFData(_: data, scale: UIScreen.main.scale, duration: 0.0)
    }

    static func animatedImageWithGIFData(_ data: Data, scale: CGFloat, duration: TimeInterval) -> UIImage? {

        let options = [kCGImageSourceShouldCache as String: true, kCGImageSourceTypeIdentifierHint as String: "com.compuserve.gif" as CFString] as [String : Any]
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }

        let frameCount = CGImageSourceGetCount(imageSource)
        var images = [UIImage]()

        var gifDuration = 0.0

        for i in 0 ..< frameCount {
            guard let imageRef = CGImageSourceCreateImageAtIndex(imageSource, i, options as CFDictionary) else {
                return nil
            }

            guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil),
                  let gifInfo = (properties as! [String:Any])[ImageMetadata.Dictionary.GIF] as? [String:Any],
                  let frameDuration = (gifInfo[ImageMetadata.Property.GIFDelayTime] as? Double) else
            {
                return nil
            }

            gifDuration += frameDuration
            images.append(UIImage(cgImage: imageRef, scale: CGFloat(scale), orientation: .up))
        }

        if frameCount == 1 {
            return images.first
        } else {
            return UIImage.animatedImage(with: images, duration: duration <= 0.0 ? gifDuration : duration)
        }
    }

    static func animatedImageURLsWithGIFData(_ data: Data, directory:String=NSTemporaryDirectory(), filenamePrefix:String="exported_gif_image_") -> [(url: URL, frameDelay: Double)]? {

        let options = [kCGImageSourceShouldCache as String: true, kCGImageSourceTypeIdentifierHint as String: "com.compuserve.gif" as CFString] as [String : Any]
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }

        let frameCount = CGImageSourceGetCount(imageSource)
        var urls = [(URL, Double)]()

        for i in 0 ..< frameCount {
            guard let imageRef = CGImageSourceCreateImageAtIndex(imageSource, i, options as CFDictionary) else {

                return nil
            }

            guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil),
                  let gifInfo = (properties as! [String:Any])[ImageMetadata.Dictionary.GIF] as? [String:Any],
                  let frameDelay = (gifInfo[ImageMetadata.Property.GIFDelayTime] as? Double) else {

                return nil
            }

            let mutableData = CFDataCreateMutable(nil, 0)!
            if let destination = CGImageDestinationCreateWithData(mutableData, UTCoreTypes.PNG as CFString, 1, nil){
                CGImageDestinationAddImage(destination, imageRef, nil)
                if CGImageDestinationFinalize(destination) {
                    let data = mutableData as Data

                    let url = FileURL.create(URL(fileURLWithPath: directory), "\(filenamePrefix)_\(i)", UTI.png, group: FileURL.fileAndQueuePrivateGroup())
                    do {
                        try data.write(to: url)
                        urls.append((url, frameDelay))
                    } catch {
                        print("failed to save url for: \(url.path)")
                    }
                } else {
                    print("Error writing Image")
                }
            }
        }

        return urls
    }
}

extension Data{
    public func extractAnimatedImageURLsAsGIF(directory:String=NSTemporaryDirectory(), filenamePrefix:String="exported_gif_image_") -> [(url: URL, frameDelay: Double)]? {
        return UIImage.animatedImageURLsWithGIFData(self, directory: directory, filenamePrefix: filenamePrefix)
    }
}


/*
https://github.com/Mark-SS/wallPaper/blob/master/Pods/Kingfisher/Kingfisher/UIImage%2BExtension.swift
//
// Created by BLACKGENE on 2016. 4. 7..
// Copyright (c) 2016 stells. All rights reserved.
//

#import "NSData+STGIFUtil.h"
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

#if TARGET_OS_WATCH
#import <WatchKit/WatchKit.h>
#endif

NSString * const AnimatedGIFImageErrorDomain = @"com.compuserve.gif.image.error";

__attribute__((overloadable)) UIImage * UIImageWithAnimatedGIFData(NSData *data) {
#if TARGET_OS_WATCH
    CGFloat screenScale = [[WKInterfaceDevice currentDevice] screenScale];
#else
    CGFloat screenScale = [[UIScreen mainScreen] scale];
#endif
    return UIImageWithAnimatedGIFData(data, screenScale, 0.0f, nil);
}

__attribute__((overloadable)) UIImage * UIImageWithAnimatedGIFData(NSData *data, CGFloat scale, NSTimeInterval duration, NSError * __autoreleasing *error) {
    if (!data) {
        return nil;
    }

    {
        NSMutableDictionary *mutableOptions = [NSMutableDictionary dictionary];
        [mutableOptions setObject:@(YES) forKey:(NSString *)kCGImageSourceShouldCache];
        [mutableOptions setObject:(NSString *)"com.compuserve.gif" as CFString forKey:(NSString *)kCGImageSourceTypeIdentifierHint];

        CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)data, (__bridge CFDictionaryRef)mutableOptions);

        size_t numberOfFrames = CGImageSourceGetCount(imageSource);
        NSMutableArray *mutableImages = [NSMutableArray arrayWithCapacity:numberOfFrames];

        NSTimeInterval calculatedDuration = 0.0f;
        for (size_t idx = 0; idx < numberOfFrames; idx++) {
            CGImageRef imageRef = CGImageSourceCreateImageAtIndex(imageSource, idx, (__bridge CFDictionaryRef)mutableOptions);

            NSDictionary *properties = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(imageSource, idx, NULL);
            calculatedDuration += [[[properties objectForKey:(__bridge NSString *)ImageMetadata.Dictionary.GIF] objectForKey:(__bridge  NSString *)kCGImagePropertyGIFDelayTime] doubleValue];

            [mutableImages addObject:[UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp]];

            CGImageRelease(imageRef);
        }

        CFRelease(imageSource);

        if (numberOfFrames == 1) {
            return [mutableImages firstObject];
        } else {
            return [UIImage animatedImageWithImages:mutableImages duration:(duration <= 0.0f ? calculatedDuration : duration)];
        }
    }
}

__attribute__((overloadable)) NSData * UIImageAnimatedGIFRepresentation(UIImage *image) {
    return UIImageAnimatedGIFRepresentation(image, 0.0f, 0, nil);
}

__attribute__((overloadable)) NSData * UIImageAnimatedGIFRepresentation(UIImage *image, NSTimeInterval duration, NSUInteger loopCount, NSError * __autoreleasing *error) {
    return UIImagesAnimatedGIFRepresentation(image.images, duration ?: image.duration, loopCount, error);
}

__attribute__((overloadable)) NSData * _UIImagesAnimatedGIFRepresentation(NSArray *images, NSTimeInterval duration, NSUInteger loopCount, NSError * __autoreleasing *error) {
    if (!images) {
        return nil;
    }

    NSDictionary *userInfo = nil;

    if(duration<=0){
        userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"Duration must be higher than 0.", nil) };
        goto _error;
    }

    {
        size_t frameCount = images.count;
        NSTimeInterval frameDuration = duration / frameCount;
        NSDictionary *frameProperties = @{
                (__bridge NSString *)ImageMetadata.Dictionary.GIF: @{
                        (__bridge NSString *)kCGImagePropertyGIFDelayTime: @(frameDuration)
                }
        };

        NSMutableData *mutableData = [NSMutableData data];
        CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)mutableData, "com.compuserve.gif" as CFString, frameCount, NULL);

        NSDictionary *imageProperties = @{ (__bridge NSString *)ImageMetadata.Dictionary.GIF: @{
                (__bridge NSString *)kCGImagePropertyGIFLoopCount: @(loopCount)
        }
        };
        CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)imageProperties);

        for (size_t idx = 0; idx < images.count; idx++) {
            @autoreleasepool {
                id imageObj = images[idx];

                UIImage * image = nil;
                if([imageObj isKindOfClass:NSString.class]){
                    image = [UIImage imageWithContentsOfFile:imageObj];

                } else if([imageObj isKindOfClass:UIImage.class]){
                    image = imageObj;

                }else{
                    userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(([@"Not supported object type." stringByAppendingFormat:@"%@", NSStringFromClass([imageObj class])]), nil) };
                    goto _error;
                }

                CGImageDestinationAddImage(destination, [image CGImage], (__bridge CFDictionaryRef)frameProperties);
            }
        }

        BOOL success = CGImageDestinationFinalize(destination);
        CFRelease(destination);

        if (!success) {
            userInfo = @{
                    NSLocalizedDescriptionKey: NSLocalizedString(@"Could not finalize image destination", nil)
            };

            goto _error;
        }

        return [NSData dataWithData:mutableData];
    }
    _error: {
        if (error) {
            *error = [[NSError alloc] initWithDomain:AnimatedGIFImageErrorDomain code:-1 userInfo:userInfo];
        }

        return nil;
    }
}

__attribute__((overloadable)) NSData * NSStringPathsAnimatedGIFRepresentation(NSArray<NSString *> *filePaths, NSTimeInterval duration, NSUInteger loopCount, NSError * __autoreleasing *error) {
    return _UIImagesAnimatedGIFRepresentation(filePaths, duration, loopCount, error);
}

__attribute__((overloadable)) NSData * UIImagesAnimatedGIFRepresentation(NSArray<UIImage *> *images, NSTimeInterval duration, NSUInteger loopCount, NSError * __autoreleasing *error) {
    return _UIImagesAnimatedGIFRepresentation(images, duration, loopCount, error);
}

@implementation NSData (STGIFUtil)

- (BOOL)isGIF{
    if (self.length > 4) {
        const unsigned char * bytes = [self bytes];
        return bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46;
    }
    return NO;
}

@end
*/
