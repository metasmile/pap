//
//  AssetView.swift
//  batch
//
//  Created by Hyojin Mo on 2017. 11. 27..
//  Copyright © 2017년 Stells. All rights reserved.
//
// STAssetView can draw following media:
// - image
// - video
// - live photo
// - images

import UIKit
import Photos
import AVFoundation
import PhotosUI

class AssetVideoView: UIView {
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    var player: AVPlayer? {
        didSet {
            (layer as? AVPlayerLayer)?.player = player
        }
    }
    
    override var contentMode: UIView.ContentMode {
        didSet {
            switch contentMode {
            case .scaleAspectFill:
                (layer as? AVPlayerLayer)?.contentsGravity = CALayerContentsGravity.resizeAspectFill
                (layer as? AVPlayerLayer)?.videoGravity = .resizeAspectFill
            default:
                (layer as? AVPlayerLayer)?.contentsGravity = CALayerContentsGravity.resizeAspect
                (layer as? AVPlayerLayer)?.videoGravity = .resizeAspect
            }
        }
    }
}

class AssetView: UIView {
    lazy var accessoryView: UIView = {
        return UIView(frame: CGRect(origin: .zero, size: frame.size))
    }()
    
    lazy var imageView: UIImageView = {
        return UIImageView(frame: CGRect(origin: .zero, size: frame.size))
    }()
    lazy var videoView: AssetVideoView = {
        return AssetVideoView(frame: CGRect(origin: .zero, size: frame.size))
    }()
    lazy var livePhotoView: PHLivePhotoView = {
        return PHLivePhotoView(frame: CGRect(origin: .zero, size: frame.size))
    }()
    
    var previewMode: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        initialize()
    }
    
    func initialize() {
        addSubview(imageView)
        addSubview(videoView)
        addSubview(livePhotoView)
        
        addSubview(accessoryView)
        accessoryView.fitConstraints(to: self)
        
        videoView.player = AVPlayer()
        videoView.isHidden = true
        
        livePhotoView.isHidden = true
        livePhotoView.delegate = self
        
        imageRequestOptions = defaultImageRequestOptions
        videoRequestOptions = defaultVideoRequestOptions
        livePhotoRequestOptions = defaultLivePhotoRequestOptions
        
        imageView.accessibilityIgnoresInvertColors = true
        videoView.accessibilityIgnoresInvertColors = true
        livePhotoView.accessibilityIgnoresInvertColors = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        imageView.frame = bounds
        videoView.frame = bounds
        livePhotoView.frame = bounds
    }
    
    override var contentMode:UIView.ContentMode  {
        didSet {
            imageView.contentMode = contentMode
            videoView.contentMode = contentMode
            livePhotoView.contentMode = contentMode
        }
    }
    
    // MARK: Media type
    
    var image: UIImage? {
        didSet {
            updateImageContents(image)
        }
    }
    
    func imageDidLoad(image: UIImage?) {}
    
    var player: AVPlayer? {
        return videoView.player
    }
    
    var playerItem: AVPlayerItem? {
        didSet {
            videoView.player?.replaceCurrentItem(with: playerItem)
        }
    }
    
    func videoDidLoad(video: AVAsset?) {}
    
    var livePhoto: PHLivePhoto? {
        didSet {
            livePhotoView.livePhoto = livePhoto
        }
    }
    
    func livePhotoDidLoad(livePhoto: PHLivePhoto?) {}
    
    var gifImage: UIImage? {
        didSet {
            if let image = gifImage {
                imageView.setGifImage(image)
            }
            else {
                imageView.clear()
            }
        }
    }
    
    func imageDataDidLoad(data: Data?) {}
    
    // MARK: Video
    
    var isVideoPlaying: Bool {
        return videoView.player?.timeControlStatus == .playing
    }
    
    var videoSeekTime: CMTime {
        return playerItem?.currentTime() ?? CMTime.zero
    }
    
    fileprivate var playerLoopingObserver: Any?
    
    // MARK: Live Photo
    
    open var isLivePhotoPlaying: Bool = false
    
    // MARK: - PHAsset
    
    fileprivate static let imageManager = PHImageManager()
    fileprivate var imageRequestID: PHImageRequestID?
    
    var asset: PHAsset? {
        didSet {
            if oldValue != asset {
                clearDrawing()
            }
        }
    }
    
    func clearDrawing() {
        cancelCurrentImageRequest()
        
        isLivePhotoPlaying = false
        videoView.isHidden = true
        livePhotoView.isHidden = true
        stopAny()
        
        image = nil
        playerItem = nil
        livePhoto = nil
    }
    
    func teardown() {
        clearDrawing()
        
        DispatchQueue(label: "AudioSessionQueue", qos: .utility).asyncAfter(deadline: DispatchTime.now() + 0.1) {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
    
    fileprivate func cancelCurrentImageRequest() {
        if let imageRequestID = imageRequestID {
            AssetView.imageManager.cancelImageRequest(imageRequestID)
        }
        self.imageRequestID = nil
    }
    
    // MARK: Image Request Options
    
    private var defaultImageRequestOptions: PHImageRequestOptions {
        let imageRequestOptions = PHImageRequestOptions()
        imageRequestOptions.isNetworkAccessAllowed = true
        imageRequestOptions.isSynchronous = false
        imageRequestOptions.deliveryMode = .opportunistic
        imageRequestOptions.resizeMode = .fast
        imageRequestOptions.progressHandler = { progress, error, stop, info in
            
        }
        return imageRequestOptions
    }
    var imageRequestOptions: PHImageRequestOptions?
    
    private var defaultVideoRequestOptions: PHVideoRequestOptions {
        let videoRequestOptions = PHVideoRequestOptions()
        videoRequestOptions.isNetworkAccessAllowed = true
        videoRequestOptions.deliveryMode = .automatic
        videoRequestOptions.progressHandler = { progress, error, stop, info in
            
        }
        return videoRequestOptions
    }
    var videoRequestOptions: PHVideoRequestOptions?
    
    private var defaultLivePhotoRequestOptions: PHLivePhotoRequestOptions {
        let livePhotoRequestOptions = PHLivePhotoRequestOptions()
        livePhotoRequestOptions.deliveryMode = .opportunistic
        livePhotoRequestOptions.isNetworkAccessAllowed = true
        livePhotoRequestOptions.progressHandler = { progress, error, stop, info in
            
        }
        return livePhotoRequestOptions
    }
    var livePhotoRequestOptions: PHLivePhotoRequestOptions?
    
    internal func setImageAsset(_ asset: PHAsset, cancelDrawingIfNeeded cancellation: @escaping () -> Bool = { return false }, completion: (() -> Void)? = nil) {
        if asset.imageType == .livePhoto {
            livePhotoView.isHidden = false
            
            loadLivePhoto(from: asset) { [weak self] livePhoto in
                guard !cancellation() else { return }
                
                DispatchQueue.main.async { [weak self] in
                    self?.livePhoto = livePhoto
                    completion?()
                }
            }
        }
        else if asset.imageType == .animatedGIF {
            loadImageData(for: asset) { [weak self] data in
                guard !cancellation(), let data = data else { return }
                
                DispatchQueue.main.async { [weak self] in
                    self?.gifImage = try? UIImage(gifData: data)
                    completion?()
                }
            }
        }
    }
}

extension AssetView: UIGestureRecognizerDelegate {}

//MARK: - Draw asset

extension AssetView {
    func setAsset(_ asset: PHAsset, cancelDrawingIfNeeded cancellation: @escaping () -> Bool = { return false }, updatePreview: ((UIImage?) -> Void)? = nil, completion: (() -> Void)? = nil) {
        previewMode = false
        self.asset = asset
        
        loadImage(from: asset) { (image) in
            updatePreview?(image)
            
            DispatchQueue.main.async { [weak self] in
                guard !cancellation() else { return }
                
                self?.image = image
                
                completion?()
            }
        }
        
        if asset.mediaType == .image {
            setImageAsset(asset, cancelDrawingIfNeeded: cancellation, completion: completion)
        }
        else if asset.mediaType == .video {
            setVideoAsset(asset, cancelDrawingIfNeeded: cancellation, completion: completion)
        }
    }
    
    internal func setVideoAsset(_ asset: PHAsset, cancelDrawingIfNeeded cancellation: @escaping () -> Bool = { return false }, completion: (() -> Void)? = nil) {
        videoView.isHidden = false
        
        loadVideo(from: asset) { [weak self] playerItem in
            guard !cancellation() else { return }
            
            DispatchQueue.main.async { [weak self] in
                self?.playerItem = playerItem
                completion?()
            }
        }
    }
}

extension AssetView {
    func setThumbnailAsset(_ asset: PHAsset, cancelDrawingIfNeeded cancellation: @escaping () -> Bool = { false }, completion: ((UIImage?) -> Void)? = nil) {
        previewMode = true
        self.asset = asset
        
        loadImage(from: asset) { [weak self] image in
            DispatchQueue.main.async { [weak self] in
                guard !cancellation() else { return }
                
                if let completion = completion {
                    completion(image)
                }
                else {
                    self?.image = image
                }
            }
        }
    }
}

extension AssetView {
    private func updateImageContents(_ image: UIImage?) {
        imageView.image = image
    }
}

//MARK: - Load media from asset

extension AssetView {
    fileprivate func loadImage(from asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let targetBounds = AVMakeRect(aspectRatio: asset.pixelSize, insideRect: bounds)
        let targetScale: CGFloat = UIScreen.main.scale
        let targetSize = CGSize(width: targetBounds.width * targetScale, height: targetBounds.height * targetScale)
        imageRequestID = AssetView.imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: imageRequestOptions) { [weak self] (image, info) in
            guard (info?[PHImageResultIsDegradedKey] as? Bool) != true else { return }
            self?.imageDidLoad(image: image)
            completion(image)
        }
    }
    
    fileprivate func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let image = UIImage(contentsOfFile: url.path)
        self.imageDidLoad(image: image)
        completion(image)
    }
    
    fileprivate func loadVideo(from asset: PHAsset, completion: @escaping (AVPlayerItem?) -> Void) {
        if asset.mediaType == .video {
            imageRequestID = AssetView.imageManager.requestAVAsset(forVideo: asset, options: videoRequestOptions) { [weak self] (video, audioMix, info) in
                guard (info?[PHImageResultIsDegradedKey] as? Bool) != true else { return }
                self?.videoDidLoad(video: video)
                if let video = video {
                    let playerItem = AVPlayerItem(asset: video)
                    playerItem.audioMix = audioMix
                    completion(playerItem)
                }
                else {
                    completion(nil)
                }
            }
        }
        else if asset.imageType == .livePhoto {
            loadLivePhoto(from: asset) { (livePhoto) in
                if let livePhoto = livePhoto, let videoResource = PHAssetResource.assetResources(for: livePhoto).first(where: { $0.type == PHAssetResourceType.pairedVideo }) {
                    var videoData = Data()
                    
                    self.imageRequestID = PHAssetResourceManager.default().requestData(for: videoResource, options: nil, dataReceivedHandler: { (data) in
                        videoData.append(data)
                    }) { (error) in
                        let pairedVideoFileURL = FileURL.temp("\(UUID().uuidString)_pairedVideo", UTI.quickTimeMovie, group: FileURL.fileAndQueuePrivateGroup())
                        try? videoData.write(to: pairedVideoFileURL, options: Data.WritingOptions.atomicWrite)
                        
                        let video = AVAsset(url: pairedVideoFileURL)
                        
                        self.videoDidLoad(video: video)
                        let playerItem = AVPlayerItem(asset: video)
                        
                        completion(playerItem)
                    }
                }
                else {
                    completion(nil)
                }
            }
        }
    }
    
    fileprivate func loadVideo(from url: URL, completion: @escaping (AVPlayerItem?) -> Void) {
        let video = AVAsset(url: url)
        self.videoDidLoad(video: video)
        completion(AVPlayerItem(asset: video))
    }
    
    fileprivate func loadLivePhoto(from asset: PHAsset, completion: @escaping (PHLivePhoto?) -> Void) {
        let targetSize = CGSize(width: bounds.width * UIScreen.main.nativeScale, height: bounds.height * UIScreen.main.nativeScale)
        imageRequestID = AssetView.imageManager.requestLivePhoto(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: livePhotoRequestOptions, resultHandler: { [weak self] (livePhoto, info) in
            guard (info?[PHImageResultIsDegradedKey] as? Bool) != true else { return }
            self?.livePhotoDidLoad(livePhoto: livePhoto)
            completion(livePhoto)
        })
    }
    
    func loadLivePhoto(from photoURL: URL, pairedVideoURL: URL, completion: @escaping (PHLivePhoto?) -> Void) {
        let targetSize = CGSize(width: bounds.width * UIScreen.main.nativeScale, height: bounds.height * UIScreen.main.nativeScale)
        imageRequestID = PHLivePhoto.request(withResourceFileURLs: [photoURL, pairedVideoURL], placeholderImage: nil, targetSize: targetSize, contentMode: .aspectFit) { [weak self] (livePhoto, info) in
            guard (info[PHImageResultIsDegradedKey] as? Bool) != true else { return }
            self?.livePhotoDidLoad(livePhoto: livePhoto)
            completion(livePhoto)
        }
    }
    
    fileprivate func loadImageData(for asset: PHAsset, completion: @escaping (Data?) -> Void) {
        AssetView.imageManager.requestImageDataAndOrientation(for: asset, options: imageRequestOptions) { [weak self] (data, uti, orientation, info) in
            guard (info?[PHImageResultIsDegradedKey] as? Bool) != true else { return }
            self?.imageDataDidLoad(data: data)
            completion(data)
        }
    }
}

extension AssetView {
    var isPlaying: Bool {
        if let _ = self.livePhoto {
            return isLivePhotoPlaying
        }
        else if let _ = self.playerItem {
            return isVideoPlaying
        }
        else if let _ = self.gifImage {
            return imageView.isAnimatingGif()
        }
        else {
            return false
        }
    }
    
    // Abs
    @objc func playAny() {
        if let _ = self.livePhoto {
            self.playLivePhoto()
        }
        else if let _ = self.playerItem {
            self.playVideo()
        }
        else if let _ = self.gifImage {
            self.playGIFImage()
        }
    }

    func stopAny() {
        if let _ = self.livePhoto {
            self.stopLivePhoto()
        }
        else if let _ = self.playerItem {
            self.stopVideo()
        }
        else if let _ = self.gifImage {
            self.stopGIFImage()
        }
    }
    
    func pauseAny() {
        if let _ = self.livePhoto {
            self.stopLivePhoto()
        }
        else if let _ = self.playerItem {
            self.pauseVideo()
        }
        else if let _ = self.gifImage {
            self.stopGIFImage()
        }
    }

    //Live PHAsset
    func playLivePhoto() {
        guard !isLivePhotoPlaying else { return }
        livePhotoView.startPlayback(with: .full)
    }

    func stopLivePhoto() {
        guard isLivePhotoPlaying else { return }
        livePhotoView.stopPlayback()
    }

    //Videos

    func playVideo() {
        guard !isVideoPlaying else { return }
        if videoSeekTime == playerItem?.duration {
            startVideo()
        }
        else {
            videoView.player?.play()
        }
    }
    
    func playVideoWithLooping() {
        playVideo()
        addVideoLooping()
    }
    
    func startVideo(to seekTime: CMTime = CMTime.zero) {
        guard !isVideoPlaying else { return }
        seekVideo(to: seekTime)
        videoView.player?.play()
    }
    
    func pauseVideo() {
        guard isVideoPlaying else { return }
        videoView.player?.pause()
        removeVideoLooping()
    }
    
    func stopVideo() {
        pauseVideo()
        seekVideo(to: CMTime.zero)
    }
    
    func seekVideo(to: CMTime, toleranceBefore: CMTime = CMTime.zero, toleranceAfter: CMTime = CMTime.zero, completionHandler: ((Bool) -> Void)? = nil) {
        playerItem?.seek(to: to, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter, completionHandler: completionHandler)
    }
    
    private func addVideoLooping() {
        if let playerItem = playerItem {
            playerLoopingObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: OperationQueue.main, using: { [weak self] (notification) in
                self?.startVideo(to: CMTime.zero)
            })
        }
    }
    
    private func removeVideoLooping() {
        if let observer = playerLoopingObserver {
            NotificationCenter.default.removeObserver(observer, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        }
        playerLoopingObserver = nil
    }
    
    // Animated Image
    
    private func playGIFImage() {
        imageView.startAnimatingGif()
    }
    
    private func stopGIFImage() {
        imageView.stopAnimatingGif()
    }
}

// Live Photo

extension AssetView: PHLivePhotoViewDelegate {
    func livePhotoView(_ livePhotoView: PHLivePhotoView, willBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        isLivePhotoPlaying = true
    }
    
    func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        isLivePhotoPlaying = false
    }
}
