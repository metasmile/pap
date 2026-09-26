//
// Created by BLACKGENE on 15.07.18.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import Photos
import PhotosUI

//INFO: To extend app-specific properties if needed, app developer can manually implement, decide or define whether storing values or getting default in app scope.
protocol AppUICameraOptions {
    var isLivePhotoEnabled: Bool { get set }
    var isRawPhotoEnabled: Bool { get set }
    var isDepthPhotoEnabled: Bool { get set }
    var cameraPosition: AVCaptureDevice.Position { get set }
    var cameraFlashMode: UICamera.FlashMode { get set }
    var isUsingLocation: Bool { get set }
    var cameraTorchLevel: Float { get set }
}

extension PropertyDefaults where Self:AppUICameraOptions{}
extension Defaults: AppUICameraOptions{
    var isLivePhotoEnabled: Bool {
        set { set(newValue);  }
        get { return get(or: false) }
    }

    var isRawPhotoEnabled: Bool {
        set { set(newValue);  }
        get { return get(or: false) }
    }

    var isDepthPhotoEnabled: Bool {
        set { set(newValue);  }
        get { return get(or: false) }
    }

    var cameraPosition: AVCaptureDevice.Position {
        set { set(newValue.rawValue); }
        get { return AVCaptureDevice.Position(rawValue: get(or: AVCaptureDevice.Position.back.rawValue)) ?? .back }
    }

    var cameraFlashMode: UICamera.FlashMode {
        set { set(newValue.rawValue); }
        get { return UICamera.FlashMode(rawValue: get(or: UICamera.FlashMode.off.rawValue)) ?? .off }
    }

    var isUsingLocation: Bool {
        set { set(newValue);  }
        get { return get(or: false) }
    }

    var cameraTorchLevel: Float {
        set { set(newValue);  }
        get { return get(or: 1) }
    }
}


class AppUICamera: UIView {

    lazy var cameraView: UICamera = {
        let cameraView = UICamera(frame: .zero)
        cameraView.backgroundColor = .black
        cameraView.clipsToBounds = true
        cameraView.contentMode = .scaleAspectFill
        cameraView.setUp()

        cameraView.addGestureRecognizer(tapGesture)

        return cameraView
    }()

    private lazy var tapGesture: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapToCapture))
    private lazy var pinchGesture: UIPinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.pinchToZoom))

    private var optionViewHeightLayout: NSLayoutConstraint?
    private var controlViewHeightLayout: NSLayoutConstraint?
    private var cameraAspectRatioLayout: NSLayoutConstraint?

    fileprivate var primaryColor = UIColor(red:0.99, green:0.8, blue:0.2, alpha:1)

    init(frame: CGRect, options: AppUICameraOptions?=nil) {
        super.init(frame: frame)
        initialize(with: options)
    }

    override convenience init(frame:CGRect) {
        self.init(frame: frame, options: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }

    private lazy var captureButton = CaptureButton()
    private lazy var cameraPositionButton = UIButton(type: .system)
    private lazy var cameraFlashButton = UIButton(type: .system)
    private lazy var cameraTorchLevelButton = UIButton(type: .system)
    private lazy var backgroundView = UIView(frame: .zero)
    private lazy var optionBackgroundView = UIView(frame: .zero)
    private lazy var photoOptionView = UIStackView(frame: .zero)
    private lazy var livePhotoButton = UIButton(type: .system)
    private lazy var rawPhotoButton = UIButton(type: .system)
    private lazy var depthPhotoButton = UIButton(type: .system)
    private lazy var locationButton = UIButton(type: .system)
    private lazy var zoomButton = ZoomButton()

    private let OptionViewHeightAnchorConstant:CGFloat = 44 // top
    private let ControlViewHeightAnchorConstant:CGFloat = remapClamp(
            UIScreen.main.nativeBounds.width/UIScreen.main.nativeBounds.height,
            0.562218890554723, // w/h iphone 6/se (widest)
            // ... 6/7/8 Plus //
            0.461822660098522, // w/h iphone x (longest)
            54,
            72
    )
    private lazy var CaptureButtonMinHeightAnchorConstant:CGFloat = self.ControlViewHeightAnchorConstant/1.5 //compact size

    private func initialize(with defaults: AppUICameraOptions?=nil) {
        if let defaults = defaults{
            self.cameraView.preferredRawPhotoEnabled = defaults.isRawPhotoEnabled
            self.cameraView.preferredLivePhotoEnabled = defaults.isLivePhotoEnabled
            self.cameraView.preferredDepthPhotoEnabled = defaults.isDepthPhotoEnabled
            self.cameraView.preferredCameraPosition = defaults.cameraPosition
            self.cameraView.preferredFlashMode = defaults.cameraFlashMode
            self.cameraView.preferredUsingLocation = defaults.isUsingLocation
            self.cameraView.preferredTorchLevel = defaults.cameraTorchLevel
        }

        cameraView.deviceMotion.watch(\UIDeviceMotion.orientation){
            let o = self.cameraView.deviceMotion.orientation

            var angle:Double = 0;
            if (o == .landscapeLeft ){ angle = .pi/2.0}
            else if (o == .landscapeRight ){ angle = -.pi/2.0}
            else if (o == .portraitUpsideDown ){ angle = .pi}

            DispatchQueue.main.async{
                let newTransform = o == .unknown ? CGAffineTransform.identity : CGAffineTransform(rotationAngle: CGFloat(angle))
                if self.livePhotoButton.transform != newTransform{
                    UIView.animate(withDuration: 0.3, delay: 0, options: .beginFromCurrentState, animations: { () -> () in
                        self.livePhotoButton.transform = newTransform
                        self.rawPhotoButton.transform = newTransform
                        self.depthPhotoButton.transform = newTransform
                        self.cameraFlashButton.transform = newTransform
                        self.cameraPositionButton.transform = newTransform
                     }, completion: nil)
                }
                self.cameraView.updateVideoOrientation()
            }
        }

        tintColor = UIColor.white

        let buttonImageInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)

        backgroundView.backgroundColor = .black
        addSubview(backgroundView)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false

        backgroundView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        let optionView = UIView(frame: .zero)
        optionView.clipsToBounds = true
        optionView.backgroundColor = .black
        addSubview(optionView)
        optionView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(cameraView)
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        cameraView.topAnchor.constraint(equalTo: optionView.bottomAnchor).isActive = true
        cameraView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        
        let widthMaximumLayout = cameraView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor)
        widthMaximumLayout.isActive = true

        let widthLayout = cameraView.widthAnchor.constraint(equalTo: widthAnchor)
        widthLayout.priority = .defaultLow
        widthLayout.isActive = true

        let heightLayout = cameraView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor)
        heightLayout.priority = .defaultLow
        heightLayout.isActive = true

        cameraAspectRatioLayout = cameraView.heightAnchor.constraint(equalTo: cameraView.widthAnchor, multiplier: 1.333333)
        cameraAspectRatioLayout?.isActive = true

        backgroundView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor).isActive = true
        backgroundView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor).isActive = true

        optionBackgroundView.clipsToBounds = true
        optionBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        addSubview(optionBackgroundView)
        optionBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        optionBackgroundView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        optionBackgroundView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor).isActive = true
        optionBackgroundView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor).isActive = true
        optionBackgroundView.heightAnchor.constraint(equalToConstant: OptionViewHeightAnchorConstant).isActive = true

        optionView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        optionView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor).isActive = true
        optionView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor).isActive = true
        optionViewHeightLayout = optionView.heightAnchor.constraint(equalToConstant: 0)
        optionViewHeightLayout?.isActive = true
        
        photoOptionView.axis = .horizontal
        photoOptionView.alignment = UIStackView.Alignment.fill
        photoOptionView.distribution = .fill
        addSubview(photoOptionView)
        
        photoOptionView.translatesAutoresizingMaskIntoConstraints = false
        photoOptionView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor).isActive = true
        photoOptionView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        photoOptionView.heightAnchor.constraint(equalToConstant: OptionViewHeightAnchorConstant).isActive = true
        
        depthPhotoButton.imageEdgeInsets = buttonImageInsets
        depthPhotoButton.imageView?.contentMode = .scaleAspectFit
        depthPhotoButton.contentHorizontalAlignment = .fill
        depthPhotoButton.contentVerticalAlignment = .fill
        depthPhotoButton.setImage(depthPhotoBadgeIcon, for: .normal)
        depthPhotoButton.addTarget(self, action: #selector(self.toggleDepthPhotoEnabled), for: .touchUpInside)
        if UICamera.isDepthPhotoSupported {
            photoOptionView.addArrangedSubview(depthPhotoButton)
        }
        
        depthPhotoButton.heightAnchor.constraint(equalToConstant: OptionViewHeightAnchorConstant).isActive = true
        depthPhotoButton.widthAnchor.constraint(equalTo: depthPhotoButton.heightAnchor, multiplier: 0.75).isActive = true

        livePhotoButton.imageEdgeInsets = buttonImageInsets
        livePhotoButton.imageView?.contentMode = .scaleAspectFit
        livePhotoButton.contentHorizontalAlignment = .fill
        livePhotoButton.contentVerticalAlignment = .fill
        livePhotoButton.setImage(livePhotoBadgeIcon, for: .normal)
        livePhotoButton.addTarget(self, action: #selector(self.toggleLivePhotoEnabled), for: .touchUpInside)
        photoOptionView.addArrangedSubview(livePhotoButton)
        
        livePhotoButton.heightAnchor.constraint(equalToConstant: OptionViewHeightAnchorConstant).isActive = true
        livePhotoButton.widthAnchor.constraint(equalTo: livePhotoButton.heightAnchor, multiplier: 1).isActive = true
        
        rawPhotoButton.imageEdgeInsets = buttonImageInsets
        rawPhotoButton.imageView?.contentMode = .scaleAspectFit
        rawPhotoButton.contentHorizontalAlignment = .fill
        rawPhotoButton.contentVerticalAlignment = .fill
        rawPhotoButton.setImage(rawPhotoBadgeIcon, for: .normal)
        rawPhotoButton.addTarget(self, action: #selector(self.toggleRawPhotoEnabled), for: .touchUpInside)
        photoOptionView.addArrangedSubview(rawPhotoButton)
    
        rawPhotoButton.heightAnchor.constraint(equalToConstant: OptionViewHeightAnchorConstant).isActive = true
        rawPhotoButton.widthAnchor.constraint(equalTo: rawPhotoButton.heightAnchor, multiplier: 0.75).isActive = true

        let controlView = UIView(frame: .zero)
        controlView.clipsToBounds = true
        controlView.backgroundColor = .black
        addSubview(controlView)

        controlView.translatesAutoresizingMaskIntoConstraints = false
        controlView.topAnchor.constraint(equalTo: cameraView.bottomAnchor).isActive = true
        controlView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor).isActive = true
        controlView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor).isActive = true
        controlView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        controlViewHeightLayout = controlView.heightAnchor.constraint(equalToConstant: 0)
        controlViewHeightLayout?.priority = .defaultLow
        controlViewHeightLayout?.isActive = true

        captureButton.addTarget(self, action: #selector(self.tapToCapture), for: .touchUpInside)
        captureButton.addTarget(self, action: #selector(self.tapDownToCapture), for: .touchDown)
        addSubview(captureButton)

        captureButton.translatesAutoresizingMaskIntoConstraints = false
        bottomAnchor.constraint(greaterThanOrEqualTo: captureButton.bottomAnchor, constant: 10).isActive = true
        captureButton.centerXAnchor.constraint(equalTo: controlView.centerXAnchor).isActive = true
        captureButton.heightAnchor.constraint(greaterThanOrEqualToConstant: CaptureButtonMinHeightAnchorConstant).isActive = true
        captureButton.heightAnchor.constraint(lessThanOrEqualToConstant: ControlViewHeightAnchorConstant).isActive = true
        captureButton.widthAnchor.constraint(equalTo: captureButton.heightAnchor, multiplier: 1).isActive = true

        let captureButtonTopLayout = captureButton.topAnchor.constraint(equalTo: controlView.topAnchor)
        captureButtonTopLayout.priority = .defaultLow - 1
        captureButtonTopLayout.isActive = true

        let captureButtonCenterYLayout = captureButton.centerYAnchor.constraint(equalTo: controlView.centerYAnchor)
        captureButtonCenterYLayout.priority = .defaultLow
        captureButtonCenterYLayout.isActive = true
        
        //location
        locationButton.imageEdgeInsets = buttonImageInsets
        locationButton.imageView?.contentMode = .scaleAspectFit
        locationButton.contentHorizontalAlignment = .fill
        locationButton.contentVerticalAlignment = .fill
        locationButton.setImage(locationIcon, for: .normal)
        locationButton.addTarget(self, action: #selector(self.toggleUsingLocation), for: .touchUpInside)
        addSubview(locationButton)
        
        locationButton.translatesAutoresizingMaskIntoConstraints = false
        locationButton.centerYAnchor.constraint(greaterThanOrEqualTo: captureButton.centerYAnchor).isActive = true
        locationButton.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor, constant: 2).isActive = true
        locationButton.widthAnchor.constraint(equalToConstant: OptionViewHeightAnchorConstant).isActive = true
        locationButton.heightAnchor.constraint(equalTo: locationButton.widthAnchor, multiplier: 0.75).isActive = true
        
        //zoom
        zoomButton.addTarget(self, action: #selector(self.zoomButtonDidTap), for: .touchUpInside)
        addSubview(zoomButton)
        
        zoomButton.translatesAutoresizingMaskIntoConstraints = false
        zoomButton.centerYAnchor.constraint(greaterThanOrEqualTo: captureButton.centerYAnchor).isActive = true
        cameraView.trailingAnchor.constraint(equalTo: zoomButton.trailingAnchor, constant: OptionViewHeightAnchorConstant - (OptionViewHeightAnchorConstant * 0.75)).isActive = true
        zoomButton.widthAnchor.constraint(equalToConstant: OptionViewHeightAnchorConstant * 0.75).isActive = true
        zoomButton.heightAnchor.constraint(equalTo: zoomButton.widthAnchor).isActive = true

        //position
        cameraPositionButton.imageEdgeInsets = buttonImageInsets
        cameraPositionButton.setImage(devicePositionIcon, for: .normal)
        cameraPositionButton.addTarget(self, action: #selector(self.switchDevicePosition), for: .touchUpInside)
        addSubview(cameraPositionButton)

        cameraPositionButton.translatesAutoresizingMaskIntoConstraints = false
        cameraPositionButton.topAnchor.constraint(greaterThanOrEqualTo: topAnchor).isActive = true
        cameraPositionButton.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor, constant: -2).isActive = true
        cameraPositionButton.heightAnchor.constraint(equalToConstant: OptionViewHeightAnchorConstant).isActive = true
        cameraPositionButton.widthAnchor.constraint(equalTo: cameraPositionButton.heightAnchor, multiplier: 1).isActive = true

        let cameraPositionButtonCenterYLayout = cameraPositionButton.centerYAnchor.constraint(equalTo: optionView.centerYAnchor)
        cameraPositionButtonCenterYLayout.priority = .defaultLow
        cameraPositionButtonCenterYLayout.isActive = true

        //flash
        cameraFlashButton.imageEdgeInsets = buttonImageInsets
        cameraFlashButton.setImage(flashModeIcon, for: .normal)
        cameraFlashButton.addTarget(self, action: #selector(self.switchFlash), for: .touchUpInside)
        addSubview(cameraFlashButton)

        cameraFlashButton.translatesAutoresizingMaskIntoConstraints = false
        cameraFlashButton.topAnchor.constraint(greaterThanOrEqualTo: topAnchor).isActive = true
        cameraFlashButton.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor, constant: 2).isActive = true
        cameraFlashButton.heightAnchor.constraint(equalToConstant: OptionViewHeightAnchorConstant).isActive = true
        cameraFlashButton.widthAnchor.constraint(equalTo: cameraFlashButton.heightAnchor, multiplier: 1).isActive = true

        let cameraFlashButtonCenterYLayout = cameraFlashButton.centerYAnchor.constraint(equalTo: optionView.centerYAnchor)
        cameraFlashButtonCenterYLayout.priority = .defaultLow
        cameraFlashButtonCenterYLayout.isActive = true
        
        // torch level
        cameraTorchLevelButton.imageEdgeInsets = buttonImageInsets
        cameraTorchLevelButton.imageView?.contentMode = .scaleAspectFit
        cameraTorchLevelButton.contentHorizontalAlignment = .fill
        cameraTorchLevelButton.contentVerticalAlignment = .fill
        cameraTorchLevelButton.addTarget(self, action: #selector(self.touchLevelButtonDidTap), for: .touchUpInside)
        addSubview(cameraTorchLevelButton)
        
        cameraTorchLevelButton.translatesAutoresizingMaskIntoConstraints = false
        cameraTorchLevelButton.centerYAnchor.constraint(equalTo: cameraFlashButton.centerYAnchor).isActive = true
        cameraTorchLevelButton.leadingAnchor.constraint(equalTo: cameraFlashButton.trailingAnchor, constant: 0).isActive = true
        cameraTorchLevelButton.heightAnchor.constraint(equalToConstant: OptionViewHeightAnchorConstant).isActive = true
        cameraTorchLevelButton.widthAnchor.constraint(equalTo: cameraTorchLevelButton.heightAnchor, multiplier: 0.75).isActive = true

        cameraView.configurationDidUpdate = {
            var defaults = defaults
            defaults?.isLivePhotoEnabled = self.cameraView.isLivePhotoEnabled
            defaults?.isRawPhotoEnabled = self.cameraView.isRawPhotoEnabled
            defaults?.cameraPosition = self.cameraView.cameraPosition
            defaults?.cameraFlashMode = self.cameraView.flashMode
            defaults?.isDepthPhotoEnabled = self.cameraView.isDepthPhotoEnabled
            defaults?.isUsingLocation = self.cameraView.usingLocation
            if self.cameraView.flashMode == .torch {
                defaults?.cameraTorchLevel = self.cameraView.torchLevel
            }
            
            DispatchQueue.mainAsyncIfNot {
                self.livePhotoButton.setImage(self.livePhotoBadgeIcon, for: .normal)
                self.livePhotoButton.tintColor = self.cameraView.isLivePhotoEnabled ? self.primaryColor : nil
                
                self.rawPhotoButton.setImage(self.rawPhotoBadgeIcon, for: .normal)
                self.rawPhotoButton.tintColor = self.cameraView.isRawPhotoEnabled ? self.primaryColor : nil
                
                self.depthPhotoButton.setImage(self.depthPhotoBadgeIcon, for: .normal)
                self.depthPhotoButton.tintColor = self.cameraView.isDepthPhotoEnabled ? self.primaryColor : nil
                
                self.cameraFlashButton.setImage(self.flashModeIcon, for: .normal)
                self.cameraFlashButton.tintColor = (self.cameraView.flashMode == .on || self.cameraView.flashMode == .torch) ? self.primaryColor : nil
                
                self.locationButton.setImage(self.locationIcon, for: .normal)
                self.locationButton.isEnabled = self.cameraView.isUsingLocationSupported
                self.locationButton.tintColor = self.cameraView.usingLocation ? self.primaryColor : nil
                
                self.zoomButton.isHidden = !self.cameraView.isZoomEnabled
                self.zoomButton.zoomFactor = self.cameraView.videoZoomFactor
                
                self.cameraTorchLevelButton.setImage(self.torchLevelIcon(self.cameraView.torchLevel), for: .normal)
                self.cameraTorchLevelButton.isHidden = self.isCompactMode || self.cameraView.flashMode != .torch
                
                if self.isCompactMode {
                    self.updatePhotoOptionButtons()
                }
            }
        }
        
        addGestureRecognizer(pinchGesture)

        self.isCompactMode = true
    }

    private var devicePositionIcon: UIImage {
        return { () -> UIImage in
            return (self.isCompactMode ? R.image.appUICameraPositionIntaglio() : R.image.appUICameraPositionEmboss()) ?? UIImage()
        }().withRenderingMode(.alwaysTemplate)
    }

    private var livePhotoBadgeIcon: UIImage {
        return { () -> UIImage in
            guard cameraView.isLivePhotoSupported else { return PHLivePhotoView.livePhotoBadgeImage(options: .liveOff) }
            return cameraView.isLivePhotoEnabled ? PHLivePhotoView.livePhotoBadgeImage(options: .overContent) : PHLivePhotoView.livePhotoBadgeImage(options: .liveOff)
        }().withRenderingMode(.alwaysTemplate)
    }
    
    private var rawPhotoBadgeIcon: UIImage {
        return (R.image.appUICameraRawPhoto() ?? UIImage()).withRenderingMode(.alwaysTemplate)
    }
    
    private var depthPhotoBadgeIcon: UIImage {
        return (R.image.cell_icon_depth() ?? UIImage()).withRenderingMode(.alwaysTemplate)
    }
    
    private var locationIcon: UIImage {
        return (R.image.appActionIconLocation() ?? UIImage()).withRenderingMode(.alwaysTemplate)
    }
    
    private func torchLevelIcon(_ level: Float) -> UIImage {
        return (UIImage(path: UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: 20, height: 20)).insetBy(dx: 5, dy: 5)), fillColor: self.primaryColor.withAlphaComponent(CGFloat(level)), strokeColor: self.primaryColor) ?? UIImage()).withRenderingMode(.alwaysOriginal)
    }

    private var flashModeIcon: UIImage{
        return { () -> UIImage in
            switch cameraView.flashMode {
                case .on, .auto:
                    return R.image.appUICameraFlashOn() ?? UIImage()
                case .torch:
                    return R.image.appUICameraTorchOn() ?? UIImage()
                case .off:
                    return R.image.appUICameraFlashOff() ?? UIImage()
            }
        }().withRenderingMode(.alwaysTemplate)
    }

    @objc func tapToCapture(sender: Any) {
        if isCompactMode || sender is CaptureButton {
            UIFeedback.impact(.light)
            cameraView.takePhoto()
        }
        else if let gesture = sender as? UITapGestureRecognizer {
            cameraView.focusAndExposure(at: gesture.location(in: cameraView), focusMode: .autoFocus, exposureMode: .autoExpose)
        }
    }

    @objc func tapDownToCapture(sender: Any) {
        UIFeedback.select()
    }
    
    @objc func pinchToZoom(sender: UIPinchGestureRecognizer) {
        if sender.state == .began {
            sender.scale = cameraView.videoZoomFactor
        }
        
        cameraView.zoom(sender.scale)
        zoomButton.zoomFactor = cameraView.videoZoomFactor
    }
    
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

    @objc func switchDevicePosition(sender: Any) {
        cameraView.switchCaptureDevicePosition()

        UIFeedback.select()
    }

    @objc func switchFlash(sender: Any) {
        cameraView.flashMode = [
            UICamera.FlashMode.auto:UICamera.FlashMode.on,
            UICamera.FlashMode.on:UICamera.FlashMode.torch,
            UICamera.FlashMode.off:UICamera.FlashMode.auto,
            UICamera.FlashMode.torch:UICamera.FlashMode.off
        ][cameraView.flashMode]!

        UIFeedback.select()
    }

    @objc func toggleLivePhotoEnabled(sender: Any) {
        guard cameraView.isLivePhotoSupported else { return }
        cameraView.isLivePhotoEnabled = !cameraView.isLivePhotoEnabled
        
        UIFeedback.select()
    }
    
    @objc func toggleRawPhotoEnabled(sender: Any) {
        cameraView.isRawPhotoEnabled = !cameraView.isRawPhotoEnabled
        
        UIFeedback.select()
    }
    
    @objc func toggleDepthPhotoEnabled(sender: Any) {
        cameraView.isDepthPhotoEnabled = !cameraView.isDepthPhotoEnabled
        
        UIFeedback.select()
    }
    
    @objc func toggleUsingLocation(sender: Any) {
        cameraView.usingLocation = !cameraView.usingLocation
        
        UIFeedback.select()
    }
    
    @objc func touchLevelButtonDidTap(sender: Any) {
        cameraView.torchLevel = max(0.25, (cameraView.torchLevel + 0.25).truncatingRemainder(dividingBy: 1.25))
        
        UIFeedback.select()
    }

    var hasZeroOptionViewMargin:Bool{
        layoutIfNeeded()
        return height-(cameraView.height + ControlViewHeightAnchorConstant) < OptionViewHeightAnchorConstant
    }
    
    private func updatePhotoOptionButtons() {
        depthPhotoButton.removeFromSuperview()
        rawPhotoButton.removeFromSuperview()
        
        if isCompactMode {
            photoOptionView.spacing = 0
            
            if UICamera.isDepthPhotoSupported, cameraView.isDepthPhotoEnabled {
                photoOptionView.insertArrangedSubview(depthPhotoButton, at: 0)
            }
            if UICamera.isRawPhotoSupported, cameraView.isRawPhotoEnabled {
                photoOptionView.addArrangedSubview(rawPhotoButton)
            }
        }
        else {
            photoOptionView.spacing = 2
            
            if UICamera.isDepthPhotoSupported {
                photoOptionView.insertArrangedSubview(depthPhotoButton, at: 0)
            }
            photoOptionView.addArrangedSubview(rawPhotoButton)
        }
    }

    var isCompactMode: Bool = true {
        didSet {
            if isCompactMode {
                optionViewHeightLayout?.constant = 0
                controlViewHeightLayout?.constant = 0
            }
            else {
                controlViewHeightLayout?.constant = ControlViewHeightAnchorConstant
                optionViewHeightLayout?.constant = self.hasZeroOptionViewMargin ? 0 : OptionViewHeightAnchorConstant
            }
            
            updatePhotoOptionButtons()

            let compactControlViewLayoutRequired = isCompactMode || optionViewHeightLayout?.constant ?? 0 > 0

            captureButton.isEnabled = !isCompactMode
            captureButton.transform = compactControlViewLayoutRequired ? CGAffineTransform.identity : CGAffineTransform(scaleX: 0.9, y: 0.9)

            cameraPositionButton.setImage(devicePositionIcon, for: .normal)

            optionBackgroundView.isHidden = compactControlViewLayoutRequired
            backgroundView.isHidden = isCompactMode
            
            cameraTorchLevelButton.isHidden = isCompactMode || cameraView.flashMode != .torch
            
            //TODO: ignore layer implicit animation
            layoutIfNeeded()
            
            cameraView.resetFocusAndExposure(showsGuide: !isCompactMode)
        }
    }
}
