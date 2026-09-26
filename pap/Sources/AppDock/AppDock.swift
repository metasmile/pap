//
// Created by BLACKGENE on 04/04/2018.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

// AppDock
public protocol AppDock {
    var contentLayoutState: AppDockContentLayoutState {get}
    func expandDockIfNeeded(reloadContents:Bool?) // nil means it should act with default behavior
    func contractDockIfNeeded(reloadContents:Bool?)
    var contentInsets: UIEdgeInsets {get}
}

public protocol AppDockDelegate {
    func dockWillExpand(_ dock:AppDock)
    func dockDidExpand(_ dock:AppDock)

    func dockWillContract(_ dock:AppDock)
    func dockDidContract(_ dock:AppDock)
}

extension AppDockDelegate{
    func dockWillExpand(_ dock: AppDock) {}
    func dockDidExpand(_ dock: AppDock) {}

    func dockWillContract(_ dock: AppDock) {}
    func dockDidContract(_ dock: AppDock) {}
}

// AppDock Window
public enum AppDockContentLayoutState: Int{
    case minimized
    case neutralized
    case maximized
}


// AppDockContentPreferable
public protocol AppDockContentPreferable {
    var preferredHeight: CGFloat {get}
}

public struct AppDockContentPreferences: AppDockContentPreferable {
    public static let GreatestHeight = CGFloat.greatestFiniteMagnitude

    public var preferredHeight: CGFloat = 0

    init(){}

    init(preferredHeight:CGFloat){
        self.preferredHeight = preferredHeight
    }
}

// AppDockContent
public protocol AppDockContent {
    //INFO: `lazy var view: UIView = UIView()` is recommended to prevent creating new instance always.
    var view: UIView {get}
    var preferences: AppDockContentPreferable? {get}
    var delegate: AppDockDelegate? {get}
    var contentScrollable: AppDockContentScrollable? {get}

    //INFO: initializer codes should locate on `willSetContentView` (e.g. assigning delegate object)
    func willSetContentView(_ view:UIView, dock:AppDock)
    func didSetContentView(_ view:UIView, dock:AppDock)

    func willRemoveContentView()
    
    func willLayoutSubviews()
    func didLayoutSubviews()
}

extension AppDockContent{
    public var delegate: AppDockDelegate? { return nil }
    public var contentScrollable: AppDockContentScrollable? { return nil }

    public func willSetContentView(_ view:UIView, dock:AppDock) {}
    public func didSetContentView(_ view:UIView, dock:AppDock) {}

    public func willRemoveContentView() {}
    
    public func willLayoutSubviews() {}
    public func didLayoutSubviews() {}
}

// AppDockContentScrollable
public protocol AppDockContentScrollable {
    var scrollView: UIScrollView { get }
    func makeScrollableContent()
    func invalidateCollectionViewLayout()
}

public struct AppDockScrollableContent: AppDockContentScrollable {
    private(set) public var scrollView: UIScrollView

    init(_ scrollView: UIScrollView) {
        self.scrollView = scrollView
    }
    
    public func makeScrollableContent() {
        self.scrollView.alwaysBounceVertical = false
        self.scrollView.alwaysBounceHorizontal = false
    }
    
    public func invalidateCollectionViewLayout() {
        if let collectionView = scrollView as? UICollectionView {
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }
}

public protocol AppDockContentPlayerControllable {
    var player: AVPlayer? { get set }
}

public struct AppDockContentItem: AppDockContent {
    public var view: UIView
    public var preferences: AppDockContentPreferable? = nil
    public var contentScrollable: AppDockContentScrollable? = nil
}

// AppDockReloadableContentView
protocol AppDockContentView: AnyObject{
    func reloadContent()
    func reloadContentThatFits(size:CGSize)
}

// AppDockReloadableContentView default behavior
extension AppDockContentView where Self:UIView{
    func reloadContentThatFits(size: CGSize) {
        reloadContent()
    }

    func reloadContent() {
        layoutIfNeeded()
    }
}
