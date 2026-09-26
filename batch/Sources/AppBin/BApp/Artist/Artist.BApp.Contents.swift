//
//  PhotosFilter.App.Contents.swift
//  batch
//
//  Created by HYOJIN MO on 2018. 3. 28..
//  Copyright © 2018년 Stells. All rights reserved.
//

import UIKit
import Photos
import AVFoundation

class _ArtistAppAsset: AppAsset {
    fileprivate weak var editingContext: PHLivePhotoEditingContext?
    fileprivate weak var exportSession: AVAssetExportSession?
    
    func cancelProcessing() {
        editingContext?.cancel()
        editingContext = nil
        
        exportSession?.cancelExport()
        exportSession = nil
    }
}

extension _ArtistAppAsset: PHAssetImageEditable {
    func edit<T: ImageProcessable>(processor: T.Type, progress progressHandler: PHAssetEditableProgressHandler?, completion completionHandler: @escaping PHAssetEditableCompletionHandler) -> [PHAssetRequestID]? {
        let asset = self.asset
        
        guard
            let ciImage = asset.asCIImage,
            let filter = editState.ciFilter
            else {
                completionHandler(nil, nil, nil)
                return nil
        }
        
        let image = ciImage.applyFilter(ciFilter: filter)
        
        let r = self.requestContentEditing { _item in
            guard let item = _item else{
                completionHandler(nil, nil, nil)
                return
            }
            
            DispatchQueue(label: "com.stells.internal."+fileName(), qos: .utility).async {
                // renderedContentURL supports only JPEG and MOV ...
                // so... always export JPEG
                //TODO: investigate PHAssetChangeRequest.creationRequestForAssetFromImage(url)
                
                guard image.writeJPEGRepresentationOriginally(to: item.output.renderedContentURL) else {
                    completionHandler(nil, nil, nil)
                    return
                }
                
                completionHandler(asset, [PHAssetEditingResultItem(url: item.output.renderedContentURL, resourceType: .photo)], item.output)
            }
        }
        return [PHAssetRequestID(forEditingInput: r)]
    }
}

extension _ArtistAppAsset: PHAssetLivePhotoEditable {
    func edit<T:LivePhotoProcessable>(processor:T.Type, progress progressHandler: PHAssetEditableProgressHandler?, completion completionHandler: @escaping PHAssetEditableCompletionHandler) -> [PHAssetRequestID]? {
        let r = self.requestContentEditing { _item in
            guard let item = _item else{
                completionHandler(nil, nil, nil)
                return
            }
            
            DispatchQueue(label: "com.stells.internal."+fileName(), qos: .utility).async {
                let editingContext = PHLivePhotoEditingContext(livePhotoEditingInput: item.input)
                guard let duration = editingContext?.duration.seconds else { return }
                let progress = Progress(totalUnitCount: Int64(duration * 1000))
                editingContext?.frameProcessor = { frame, error in
                    progressHandler?({
                        progress.completedUnitCount = Int64(frame.time.seconds * 1000)
                        return progress
                        }())
                    return frame.image.applyFilter(ciFilter: self.editState.ciFilter)
                }
                
                editingContext?.saveLivePhoto(to: item.output, options: nil, completionHandler: { (success, error) in
                    guard success else {
                        completionHandler(nil, nil, nil)
                        return
                    }
                    
                    var resultItems = [PHAssetEditingResultItem(url: item.output.renderedContentURL, resourceType: .photo)]
                    if let pairedVideoURL = item.output.pairedVideoRenderedContentURL {
                        resultItems.append(PHAssetEditingResultItem(url: pairedVideoURL, resourceType: .pairedVideo))
                    }
                    
                    completionHandler(self.asset, resultItems, item.output)
                })
                
                self.editingContext = editingContext
            }
        }
        
        return [PHAssetRequestID(forEditingInput: r)]
    }
}

extension _ArtistAppAsset: PHAssetVideoEditable {
    func edit<T>(processor:T.Type, /*audioMix: AVAudioMix? = nil,*/ progress progressHandler: PHAssetEditableProgressHandler?, completion completionHandler: @escaping PHAssetEditableCompletionHandler) -> [PHAssetRequestID]?
        where T:VideoProcessable {
            
            let asset = self.asset
            
            guard
                let video = asset.asAVAsset
                else {
                    completionHandler(nil, nil, nil)
                    return nil
            }
            
            var reqIDs = [PHAssetRequestID]()
            
            let r = self.requestContentEditing { _item in
                guard let item = _item else{
                    completionHandler(nil, nil, nil)
                    return
                }
                
                DispatchQueue(label: "com.stells.internal."+fileName(), qos: .utility).async {
                    self.exportSession = AVAssetExportSession.export(asset: video, videoComposition: video.applyFilter(self.editState.ciFilter), presetName: AVAssetExportPresetHighestQuality, outputURL: item.output.renderedContentURL, progressHandler: progressHandler, completionHandler: { (success) in
                        if success {
                            completionHandler(asset, [PHAssetEditingResultItem(url: item.output.renderedContentURL, resourceType: .video)], item.output)
                        }
                        else {
                            completionHandler(nil, nil, nil)
                        }
                    })
                }
            }
            
            reqIDs.append(PHAssetRequestID(forEditingInput: r))
            return reqIDs
    }
}
