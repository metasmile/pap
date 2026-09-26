//
//  PhotoPickerViewController.swift
//  batch
//
//  Created by Hyojin Mo on 2017. 7. 11..
//  Copyright © 2017년 Codeful. All rights reserved.
//

import UIKit
import Photos
import PhotosUI

class PhotoPickerViewController: AppDockViewController {
    private lazy var undoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(R.image.systemIconUndo(), for: .normal)
        button.addTarget(self, action: #selector(self.undo), for: .touchUpInside)
        return button
    }()
    private lazy var redoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(R.image.systemIconRedo(), for: .normal)
        button.addTarget(self, action: #selector(self.redo), for: .touchUpInside)
        return button
    }()
    private lazy var undoRedoControl: UIStackView = {
        let view = UIStackView(arrangedSubviews: [undoButton, redoButton])
        view.axis = .horizontal
        view.spacing = 12
        return view
    }()
    private lazy var undoRedoControlItem: UIBarButtonItem = UIBarButtonItem(customView: undoRedoControl)

    @IBOutlet weak var photoCollectionView: UICollectionView!

    var batchPreviewView: PreviewView!
    private var appDockContentLayoutStateRestoringAfterProcessing: AppDockContentLayoutState?

    var progressBar: UIProgressView!
    private var taskProgress: Float = 0

    var dragSelectionGesture: DragSelectionGestureRecognizer!

    var collection: PHAssetCollection?
    var defaultCollection: PHAssetCollection?{
        return PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject
    }
    var isCurrentCollectionDefault:Bool{
        return self.collection?.localIdentifier == self.defaultCollection?.localIdentifier
    }
    var queuedPhotoLibraryChanges = ItemQueue<PHChange>()

    private var animatesUpdatingPhotoCollectionContentInset = false

    internal var needsScrollToBottom = false

    func setNeedsScrollToBottom() {
        needsScrollToBottom = true
    }

    var scrollingBottomOffsetY:CGFloat{
        return max(-photoCollectionView.adjustedContentInset.top, photoCollectionView.contentSize.height - photoCollectionView.bounds.size.height + photoCollectionView.adjustedContentInset.bottom - collectionView(photoCollectionView, layout: photoCollectionView.collectionViewLayout, referenceSizeForFooterInSection: 0).height)
    }

    var scrollBottomOffsetYIncludingMargin:CGFloat{
        return photoCollectionView.contentSize.height - photoCollectionView.bounds.size.height + photoCollectionView.adjustedContentInset.bottom
    }

    func scrollToBottomIfNeeded(animated:Bool=false) {
        guard needsScrollToBottom else { return }
        needsScrollToBottom = false

        photoCollectionView.setContentOffset(CGPoint(x: 0, y: scrollingBottomOffsetY), animated: animated)
    }

    var isSelectionMode = false {
        didSet {
            if isSelectionMode == true {
                updateNavigationLeftBarButton()

                updateUIDisplays()
                updateVisibleCellsEnabled()
            }
            else {
                if let indexPaths = photoCollectionView.indexPathsForSelectedItems {
                    for indexPath in indexPaths {
                        photoCollectionView.deselectItem(at: indexPath, animated: true)
                    }
                }

                batchPreviewView.removeAllCollectionViewItems()
                updateUIDisplays()
                updateVisibleCellsEnabled()

                AppCenter.default.currentInstanceAs(PhotoPickerCollectionViewDelegatableApp.self)?.didDeselectAll(callee: self)
            }
        }
    }

    override func viewDidLoad() {
        self.appDockView?.delegate = self

        super.viewDidLoad()

        //preview
        batchPreviewView = PreviewView(frame: .zero)
        batchPreviewView.delegate = self

        //photos collection
        photoCollectionView.register(PhotoCollectionViewCell.self, forCellWithReuseIdentifier: String(describing: PhotoCollectionViewCell.self))
        photoCollectionView.register(PhotoPickerFooterView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "PhotoPickerFooterView")
        photoCollectionView.allowsMultipleSelection = true

        //peek and pop
        if traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: photoCollectionView)  // self here is UIViewController type, and view is property of UIViewController
            registerForPreviewing(with: self, sourceView: batchPreviewView)
        }
        
        currentTraitCollection = traitCollection

        //listen PHPhotoLibrary changes
        PhotosManager.default.watch(\PhotosManager.changes) {
            guard let changeInstance = PhotosManager.default.changes else { return }

            DispatchQueue.main.async{
                self.queuedPhotoLibraryChanges.enqueue(changeInstance)

                self.cancelPreheatingIfNeeded()

                if AppCenter.default.task.isRunning == false{
                    self.flushQueuedPhotoLibraryChanges()
                }
            }
        }

        //monitor latest AppCenter task
        AppCenter.default.task.watch(\AppTaskManager.appIdentifiersFinished) {
            DispatchQueue.main.async{
                self.flushQueuedPhotoLibraryChanges()
            }

            //remove temp files after current all tasks are finished.
            //TODO: domain-driven disk management. (if app did mark for maintaining cache resources, skip)
            DispatchQueue.global(qos: .background).async{
                FileManager.default.clearTemporaryDirectory()
            }

            papLog.allTasksAreFinished()
        }

        navigationItem.setLeftBarButtonItems(nil, animated: false)
        navigationItem.setRightBarButtonItems(nil, animated: false)

        //check photo library permission and load
        loadPhotoLibraryIfNeeded()

        //navigation bar progress
        if let navigationVC = self.navigationController {
            progressBar = UIProgressView(progressViewStyle: .bar)
            progressBar.isHidden = false

            navigationVC.navigationBar.addSubview(progressBar)

            let bottomConstraint = NSLayoutConstraint(item: navigationVC.navigationBar, attribute: .bottom, relatedBy: .equal, toItem: progressBar, attribute: .bottom, multiplier: 1, constant: 1)
            let leftConstraint = NSLayoutConstraint(item: navigationVC.navigationBar, attribute: .leading, relatedBy: .equal, toItem: progressBar, attribute: .leading, multiplier: 1, constant: 0)
            let rightConstraint = NSLayoutConstraint(item: navigationVC.navigationBar, attribute: .trailing, relatedBy: .equal, toItem: progressBar, attribute: .trailing, multiplier: 1, constant: 0)

            progressBar.translatesAutoresizingMaskIntoConstraints = false
            navigationVC.view.addConstraints([bottomConstraint, leftConstraint, rightConstraint])
        }

        dragSelectionGesture = DragSelectionGestureRecognizer(target: self, action: #selector(self.dragSelectionGestureDidRecognize))
        dragSelectionGesture.delegate = self
        dragSelectionGesture.maximumNumberOfTouches = 1
        photoCollectionView.addGestureRecognizer(dragSelectionGesture)

        //AppCenter.chargeManager related (charge removed; reimplement later)

        //INFO: maintain last
        updateUIDisplays()
    }
    
    internal var currentTraitCollection: UITraitCollection?

    @objc private func loadPhotoLibraryIfNeeded() {
        PhotosManager.default.authorizeIfNeeded { authorized in
            DispatchQueue.main.async{ // if not call from DispatchQueue.main.async, scroll will not work.
                if authorized {
                    self.loadPhotoLibraryInCurrentCollection()
                }
                self.updateNavigationLeftBarButton()
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        currentTraitCollection = traitCollection
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        appDockNavigationController?.setAppDockHidden(false, animated: animated)

        AppCenter.default.openCurrentApp()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        animatesUpdatingPhotoCollectionContentInset = true

        if let app = AppCenter.default.currentInstanceAs(EditableApp.self) {
            app.selectEditState(value:app.defaultEditStateValue, in: (app as? AppDockApp)?.content)
        }

        if let app = AppCenter.default.currentInstanceAs(Recordable.self) {
            self.updateUndoButtonStatus(app)
        }

        updateUIDisplays()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        cancelPreheatingIfNeeded()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        batchPreviewView.collectionView.collectionViewLayout.invalidateLayout()
        photoCollectionView.collectionViewLayout.invalidateLayout()
    }

    private func loadPhotoLibraryInCurrentCollection(){
        if self.collection == nil {
            self.collection = self.defaultCollection
            self.titleFade = self.collection?.localizedTitle ?? Bundle.main.displayName
        }

        //QA: attach initial progress activity view + non-mainqueue.async
        if let collection = self.collection {
            PHAssets.fetched.load(from: collection)
        }
        else {
            PHAssets.fetched.load(with: .smartAlbum, subtype: .smartAlbumUserLibrary) // iphone x: .028702974319458s
        }

        if let numberOfSection = PHAssets.fetched.results?.count, numberOfSection > 0
        , let numberOfItemsInSection = PHAssets.fetched.results?[numberOfSection - 1].count
        , numberOfItemsInSection > 0 {
            self.setNeedsScrollToBottom()
        }
        self.photoCollectionView.reloadData()
        self.photoCollectionView.performBatchUpdates(nil, completion: { result in
            self.performPrefetchIfNeeded(includingCurrentVisibleItems: true)
            self.scrollToBottomIfNeeded(animated: true)
        })

        //navigation controller accessories
        self.title = self.collection?.localizedTitle ?? Bundle.main.displayName
    }

    private func flushQueuedPhotoLibraryChanges(){
        assert(Thread.isMainThread, "flushQueuedPhotoLibraryChanges must be called in main")

        var countOfOtherFetched = 0
        while let changeInstance = self.queuedPhotoLibraryChanges.dequeue() {
            //changed, but if found actual changes from other collection has existed (e.g. current == Favorite, but captured on Camera app)
            if self.photoLibraryDidChangeInCurrentFetched(changeInstance) == nil{
                countOfOtherFetched += 1
            }
        }

        //FIXME: after pop -> entered any album again -> some other PHChange is arriving (probably seems Album's PHChange_. strange.
//        if !self.isCurrentCollectionDefault && countOfOtherFetched > 0{
//            self.navigationController?.popViewController(animated: true)
//        }
    }

    override var appDockItems: [AppDockItem] {
        return AppCenter.default.apps(by: .default).map { AppDockItem(app: $0) }
    }

    override func appDidChange() {
        super.appDidChange()

        AppAssets.selected.reloadAll()

        if let app = AppCenter.default.currentInstanceAs(EditableApp.self) {
            let value = app.defaultEditStateValue
            if let value = value {
                AppAssets.selected.appendValue(value)
            }

            app.selectEditState(value:value, in: (app as? AppDockApp)?.content)
        }

        if let app = AppCenter.default.currentInstanceAs(Recordable.self) {
            self.updateUndoButtonStatus(app)
        }

        redisplayVisibleCellsEnabled()
        appDockView?.reloadKeepingDrawerOpened()
        batchPreviewView.updatePreviews(forced: true)

        updateUIDisplays()
        showAndRevertTitleByCurrentAppIfNeeded() //INFO: show app name after update title

        // interrupt preheating.
        cancelPreheatingIfNeeded()

        // restart preheating.
        performPrefetchIfNeeded(includingCurrentVisibleItems: true)
    }

    override func appDidAppear() {
        super.appDidAppear()

        AppCenter.default.currentInstanceAs(PhotoPickerCollectionViewDelegatableApp.self)?.didAppear(callee: self)
    }

    func appendImageEditState(_ value: ImageEditStateValue) {
        AppAssets.selected.appendValue(value)

        if let app = AppCenter.default.currentInstanceAs(EditableApp.self) {
            app.setDefaultEditState(value:value)
        }

        batchPreviewView.updatePreviews()

        if let app = AppCenter.default.currentInstanceAs(Recordable.self) {
            self.updateUndoButtonStatus(app)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if animatesUpdatingPhotoCollectionContentInset {
            UIView.animateAsSpring(animations: {
                self.photoCollectionView.contentInset.bottom = self.appDockInsets.bottom
                self.photoCollectionView.verticalScrollIndicatorInsets.bottom = self.photoCollectionView.contentInset.bottom
            })
        }
        else {
            self.photoCollectionView.contentInset.bottom = self.appDockInsets.bottom
            self.photoCollectionView.verticalScrollIndicatorInsets.bottom = self.photoCollectionView.contentInset.bottom
        }

        let interitemSpacing: CGFloat = 1
        let scaleTransform = CGAffineTransform(scaleX: 1 / UIScreen.main.nativeScale, y: 1 / UIScreen.main.nativeScale)
        let gridWidth = (UIScreen.main.nativeBounds.applying(scaleTransform).inset(by: photoCollectionView.contentInset).width - interitemSpacing * (numberOfItemsInRow - 1)) / numberOfItemsInRow
        preferredPhotoPickerCollectionItemSize = CGSize(width: gridWidth, height: gridWidth)
    }

    var preferredPhotoPickerCollectionItemSize: CGSize = .zero

    override func applyTheme(_ colorTheme: AppColorTheme) {
        super.applyTheme(colorTheme)

        photoCollectionView.tintColor = colorTheme.textColor
    }

    override func cancelButtonDidTap(sender: Any) {
        super.cancelButtonDidTap(sender: sender)

        UIFeedback.impact(.medium)

        cancelAllInCurrentContext()
    }

    override func doneButtonDidTap(sender: Any) {
        super.doneButtonDidTap(sender: sender)

        batchPreviewView.runBatchProcessing()

        updateVisibleCellsEnabled()

        cancelPreheatingIfNeeded()
    }

    private func showAndRevertTitleByCurrentAppIfNeeded(){
        let timerId = "picker_title_change_timer"
        if self.selectedAssetsInCollectionView?.count ?? 0 == 0 {
            let defaultTitle = self.collection?.localizedTitle ?? Bundle.main.displayName
            let revertingTitle = self.title == defaultTitle ? self.title : defaultTitle
            self.titleFade = AppCenter.default.current?.info.displayName
            Timer.scheduledTimer(identifier: timerId, withTimeInterval: 2, repeats: false) { timer in
                if self.selectedAssetsInCollectionView?.count ?? 0 == 0{
                    self.titleFade = revertingTitle
                }
            }
        }else{
            Timer.getScheduledTimer(identifier: timerId)?.invalidate()
        }
    }

    func redisplayVisibleCells() {
        AppAssets.selected.reloadAll()
        redisplayVisibleCellsEnabled()
        appDockView?.reloadKeepingDrawerOpened()
    }

    func redisplayVisibleCellsEnabled(){
        deselectCollectionViewItems(self.photoCollectionView.indexPathsForSelectedItems?.filter({ !shouldSelectPhoto(at: $0) }) ?? [])
        updateVisibleCellsEnabled()
    }

    func updateUIDisplays() {
        updateSelectedItemsTitle()
        updateControlsReadyingToPerform()
    }

    //TODO: mod for all media types - numberOfPhotos + numberOfVideos
    private func updateSelectedItemsTitle() {
        let selectedAssets = self.selectedAssetsInCollectionView
        let numberOfVideos = selectedAssets?.filter({ $0.mediaType == .video }).count ?? 0
        let numberOfPhotos = selectedAssets?.filter({ $0.mediaType == .image }).count ?? 0
        let numberOfItems = numberOfPhotos + numberOfVideos

        if numberOfItems == 0 {
            if isSelectionMode {
                title = "Select items".localized
            }
            else {
                title = self.collection?.localizedTitle ?? Bundle.main.displayName
            }
        }
        else {
            if numberOfPhotos > 0 && numberOfVideos == 0 {
                let pluralizedString = "Photo" + (numberOfPhotos == 1 ? "" : "s")
                title = "%d \(pluralizedString)".localizedFormatted(numberOfPhotos.decimalStyleString)
            }
            else if numberOfVideos > 0 && numberOfPhotos == 0 {
                let pluralizedString = "Video" + (numberOfVideos == 1 ? "" : "s")
                title = "%d \(pluralizedString)".localizedFormatted(numberOfVideos.decimalStyleString)
            }
            else {
                let pluralizedString = "Item" + (numberOfItems == 1 ? "" : "s")
                title = "%d \(pluralizedString)".localizedFormatted(numberOfItems.decimalStyleString)
            }
        }
    }

    private func updateControlsReadyingToPerform() {

        //update done button
        if AppCenter.default.current == nil{
            doneButton.isEnabled = false
            doneButton.title = nil
        }else{
            doneButton.isEnabled = true

            let definedTitle = AppCenter.default.currentInstanceAs(PhotoPickerViewControllerAppearanceDelegatableApp.self)?.doneButtonTitle
            doneButton.title = definedTitle ?? "Start".localized
        }

        //update done execution state
        updateNavigationLeftBarButton()

        if true {
            if appDockView?.accessory == nil {
                appDockView?.accessory = batchPreviewView
            }
        } else {
            if appDockView?.accessory != nil {
                appDockView?.accessory = nil
                batchPreviewView.reloadContent()
            }
        }
    }

    @objc private func undo() {
        if var app = AppCenter.default.currentInstanceAs(Recordable.self) {
            app.undo()

            self.updateUndoButtonStatus(app)
        }
    }

    @objc private func redo() {
        if var app = AppCenter.default.currentInstanceAs(Recordable.self) {
            app.redo()

            self.updateUndoButtonStatus(app)
        }
    }

    private func updateUndoButtonStatus(_ app: Recordable) {
        self.undoButton.isEnabled = app.canUndo
        self.redoButton.isEnabled = app.canRedo
    }

    internal func updateNavigationLeftBarButton() {
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            navigationItem.hidesBackButton = false
            if true || self.isSelectionMode {
                if let app = AppCenter.default.currentInstanceAs(Recordable.self) {
                    self.updateUndoButtonStatus(app)

                    let spacing = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
                    spacing.width = 14

                    navigationItem.setLeftBarButtonItems([
                        cancelButton,
                        spacing,
                        self.undoRedoControlItem
                        ], animated: true)
                }
                else {
                    navigationItem.setLeftBarButtonItems([self.cancelButton], animated: true)
                }
            }
            else {
                navigationItem.setLeftBarButtonItems(nil, animated: true)
            }
        }
        else {
            navigationItem.hidesBackButton = true
            navigationItem.setLeftBarButtonItems([UIBarButtonItem(image: R.image.systemIconWarning(), style: .plain, target: self, action: #selector(self.loadPhotoLibraryIfNeeded))], animated: true)
        }
    }

    var estimatedAvailableSelectedItems:Int{
        let selectedAssets = self.selectedAssetsInCollectionView
        let numberOfVideos = selectedAssets?.filter({ $0.mediaType == .video }).count ?? 0
        let numberOfPhotos = selectedAssets?.filter({ $0.mediaType == .image }).count ?? 0
        return numberOfPhotos + numberOfVideos
    }

    var formattedStringForAllPhotos: String {
        var numberOfImages = 0
        var numberOfVideos = 0

        PHAssets.fetched.results?.forEach { fetchResult in
            numberOfImages += fetchResult.countOfAssets(with: PHAssetMediaType.image)
            numberOfVideos += fetchResult.countOfAssets(with: PHAssetMediaType.video)
        }

        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal

        var footerText = ""
        if numberOfImages > 0 {
            if numberOfImages == 1 {
                footerText += "%d Photo".localizedFormatted(numberOfImages.decimalStyleString)
            }
            else {
                footerText += "%d Photos".localizedFormatted(numberOfImages.decimalStyleString)
            }
        }

        if numberOfVideos > 0 {
            if numberOfImages > 0 {
                footerText += ", "
            }

            if numberOfVideos == 1 {
                footerText += "%d Video".localizedFormatted(numberOfVideos.decimalStyleString)
            }
            else {
                footerText += "%d Videos".localizedFormatted(numberOfVideos.decimalStyleString)
            }
        }

        return footerText
    }

    private func updateAllPhotosTitle() {
        if let footer = self.photoCollectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionFooter).last as? PhotoPickerFooterView {
            footer.text = self.formattedStringForAllPhotos
        }
    }

    func updateVisibleCellsEnabled() {
        for indexPath in photoCollectionView.indexPathsForVisibleItems{
            let cell = photoCollectionView.cellForItem(at: indexPath) as? PhotoCollectionViewCell
            cell?.isEnabled = shouldSelectPhoto(at: indexPath)
            cell?.isSelectable = self.isSelectionMode
        }
    }

    private func arePhotoLibraryChangesInCurrentFetched(_ changeInstance: PHChange) -> [(Int, PHFetchResultChangeDetails<PHAsset>)]?{
        guard let fetchResults = PHAssets.fetched.results else {
            return nil
        }

        let fetchResultChanges = fetchResults.enumerated().compactMap { results -> (Int, PHFetchResultChangeDetails<PHAsset>)? in
            let (section, result) = results
            if let details = changeInstance.changeDetails(for: result){
                return (section, details)
            }
            return nil
        }

        guard !fetchResultChanges.isEmpty else {
            return nil
        }

        return fetchResultChanges
    }

    @discardableResult
    private func photoLibraryDidChangeInCurrentFetched(_ changeInstance: PHChange) -> (inserted:[PHAsset],changed:[PHAsset],removed:[PHAsset])? {
        guard let fetchResultChanges = arePhotoLibraryChangesInCurrentFetched(changeInstance), !fetchResultChanges.isEmpty else {
            return nil
        }

        /*
            Handle Tasks while batch performing
        */
        let removedAssets = fetchResultChanges.compactMap { (_, changes) in changes.removedObjects}.reduce([],+)
        let changedAssets = fetchResultChanges.compactMap { (_, changes) in changes.insertedObjects}.reduce([],+)
        let insertedAssets = fetchResultChanges.compactMap { (_, changes) in changes.changedObjects}.reduce([],+)

        let tasksWereRanAndRemoved = AppCenter.default.task.isRunning && removedAssets.count > 0
        if tasksWereRanAndRemoved {
            AppCenter.default.task.suspend()

            for removedAsset in removedAssets{
                //delete task item
                if let appTaskItem = AppCenter.default.task.currentTaskItems.first(where:{ item in
                    (item.request.param as? AppAsset)?.asset.localIdentifier==removedAsset.localIdentifier
                }){
                    AppCenter.default.task.remove(request: appTaskItem.request)
                }
            }
        }

        //remove preview items
        self.batchPreviewView.removeCollectionViewItems(with: removedAssets)

        var indexPathToScroll: IndexPath?
        var needsToRestoreSelection = false
        let selectedIndexPathsToRestore = self.photoCollectionView.indexPathsForSelectedItems
        var insertedIndexes = [IndexPath]()

        //perform batch update
        //confirm and remove: https://console.firebase.google.com/project/batch-photos/crashlytics/app/ios:com.stells.batch/issues/5ac8295036c7b23527c249dd?time=1523145600000:1523231999000&sessionId=18f49e20db084ed8b9c8b26e72871bad_DNE_0_v2
        self.photoCollectionView.performBatchUpdates({
            for (section, changes) in fetchResultChanges {
                // Update data collection before items updated
                if false == PHAssets.fetched.update(result: changes.fetchResultAfterChanges, at: section){
                    assert(false, "section is changed but didn't collected.")
                    continue
                }

                // Reload the collection view if incremental diffs are not available.
                if false == (changes.hasIncrementalChanges || changes.hasMoves) {
                    self.photoCollectionView.reloadData()
                    break
                }

                // If there are incremental diffs, animate them in the collection view.
                // For indexes to make sense, updates must be in this order:
                // delete, insert, reload, move
                var removedIndexPaths: [IndexPath]?
                if let removed = changes.removedIndexes, removed.count > 0 {
                    let indexPaths = removed.map { IndexPath(item: $0, section:section) }
                    needsToRestoreSelection = true
                    self.photoCollectionView.deleteItems(at: indexPaths)

                    if PHAssets.fetched.results?[section].count == 0 {
                        self.photoCollectionView.reloadSections(IndexSet(integer: section))
                    }

                    removedIndexPaths = indexPaths
                }
                if let inserted = changes.insertedIndexes, inserted.count > 0 {
                    let indexPaths = inserted.map { IndexPath(item: $0, section:section) }
                    indexPathToScroll = indexPaths.last
                    needsToRestoreSelection = true

                    insertedIndexes.append(contentsOf: indexPaths)
                    self.photoCollectionView.insertItems(at: indexPaths)
                }
                if let changed = changes.changedIndexes, changed.count > 0 {
                    needsToRestoreSelection = true
                    let indexPaths = changed.map { IndexPath(item: $0, section:section) }
                    self.photoCollectionView.reloadItems(at: indexPaths.filter { removedIndexPaths?.contains($0) != true })
                }
                changes.enumerateMoves { fromIndex, toIndex in
                    needsToRestoreSelection = true
                    self.photoCollectionView.moveItem(at: IndexPath(item: fromIndex, section: section), to: IndexPath(item: toIndex, section: section))
                }
            }
        }, completion: { _ in
            if tasksWereRanAndRemoved {
                AppCenter.default.task.perform(self.batchPreviewView.createTaskReaction())
                papLog.performWhenPhotoLibraryDidChanged()
            }else{
                self.updateAllPhotosTitle()
                self.updateUIDisplays()
            }

            if let indexPathToScroll = indexPathToScroll {
                //TODO: test for scroll inserted items instead of restore previous selections
                self.photoCollectionView.scrollToItem(at: indexPathToScroll, at: UICollectionView.ScrollPosition.bottom, animated: true)
            }

            if needsToRestoreSelection {
                let selectedAssetIdentifiers = selectedIndexPathsToRestore?.compactMap({ PHAssets.fetched.asset(at: $0)?.localIdentifier })
                self.restoreSelectionByUser(selectedAssetIdentifiers)
            }

            self.appDockView?.reloadKeepingDrawerOpened()

            // PhotoPickerCollectionViewDisplayableApp.shouldSelectWhenInserted
            let collectionViewDelegatableApp = AppCenter.default.currentInstanceAs(PhotoPickerCollectionViewDelegatableApp.self)

            if insertedIndexes.count > 0{
                collectionViewDelegatableApp?.didInsert(callee:self, indexPaths:insertedIndexes)
            }

            if let allowedSelectionIndexPaths = collectionViewDelegatableApp?.shouldSelectWhenInserted(indexPaths: insertedIndexes.nilEmpty){
                Timer.scheduledTimer(identifier: fileName()+#function, withTimeInterval: 0) { timer in
                    for indexPath in allowedSelectionIndexPaths {
                        self.selectCollectionViewItem(at: indexPath)
                    }

                    DispatchQueue.mainAsyncAfter(qos: .background) {
                        self.viewDidLayoutSubviews()
                        self.setNeedsScrollToBottom()
                        self.scrollToBottomIfNeeded(animated: true)
                    }

                    collectionViewDelegatableApp?.didSelectWhenInserted(callee:self, indexPaths:allowedSelectionIndexPaths)
                }
            }
        })

        return (inserted: insertedAssets, changed:changedAssets, removed:removedAssets)
    }
}

extension UIView {
    func asImage() -> UIImage? {
        return UIGraphicsImageRenderer(bounds: bounds).imageWithCurrentContext { [weak self] (ctx) in
            self?.layer.render(in: ctx)
        }
    }
}

extension PhotoPickerViewController: EditViewControllerDelegate {
    func showPhotoEditor(with editItem: AppAsset?, animated: Bool = false) {
        DispatchQueue.main.async{
            self._showPhotoEditor(with:editItem, animated: animated)
        }
    }

    private func _showPhotoEditor(with editItem: AppAsset?, animated: Bool = false) {
        guard let editItem = editItem else { return }

        if let photoEditViewController = R.storyboard.appStoryboard.photoEditViewController(){
            photoEditViewController.assetItem = editItem
            photoEditViewController.preferredEditState = editItem.editState
            photoEditViewController.asset = editItem.asset
            photoEditViewController.delegate = self
            photoEditViewController.indexPathInPicker = PHAssets.fetched.indexPath(of:editItem.asset)
            photoEditViewController.selectedInPicker = AppAssets.selected.by(editItem.asset) != nil

            if let index = AppAssets.selected.index(of: editItem), let cell = batchPreviewView.collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? PreviewCollectionViewCell {
                let snapshot = cell.assetView.asImage()?.applyTransform(editItem.editState.transform)
                photoEditViewController.placeholderImage = snapshot

                let placeholderView = UIImageView(frame: cell.assetView.frame)
                placeholderView.image = snapshot
                placeholderView.contentMode = .scaleAspectFit

                photoEditViewController.transitionAnimator.sourceView = cell
                photoEditViewController.transitionAnimator.transitionView = placeholderView
                let rectInCollectionView = cell.convert(placeholderView.frame, to: batchPreviewView.collectionView)
                placeholderView.frame = view.convert(rectInCollectionView, from: batchPreviewView.collectionView)

                photoEditViewController.transitionAnimator.sourceRect = placeholderView.frame
            }
            else if let indexPath = photoEditViewController.indexPathInPicker, let cell = photoCollectionView.cellForItem(at: indexPath) as? PhotoCollectionViewCell {
                let snapshot = editItem.asset.requestThumbnailImage(targetSize: cell.imageView.frame.size)
                photoEditViewController.placeholderImage = snapshot

                let placeholderView = UIImageView(frame: cell.imageView.frame)
                placeholderView.image = snapshot
                placeholderView.contentMode = .scaleAspectFill

                photoEditViewController.transitionAnimator.sourceView = cell
                photoEditViewController.transitionAnimator.transitionView = placeholderView
                let rectInCollectionView = cell.convert(placeholderView.frame, to: photoCollectionView)
                placeholderView.frame = view.convert(rectInCollectionView, from: photoCollectionView)

                photoEditViewController.transitionAnimator.sourceRect = placeholderView.frame
            }

            if !animated {
                photoEditViewController.transitionAnimator.sourceView?.isHidden = true
            }

            appDockContentLayoutStateRestoringAfterProcessing = appDockView?.contentLayoutState

            let navigationController = AppDockNavigationController(rootViewController: photoEditViewController)
            navigationController.transitioningDelegate = photoEditViewController
            navigationController.modalPresentationStyle = .fullScreen

            present(navigationController, animated: animated) {
                AppCenter.default.currentInstanceAs(ConfigurableApp.self)?.setConfigValues(AppConfigUIAttribute(tintColor: self.view.colorTheme.textColor))
            }
        }
    }

    func editViewController(_ photoEditor: PhotoEditViewController, didFinishWith editItem: StateValueSet<ImageEditStateValue>?, at indexPath: IndexPath?) {
        assert(photoEditor.asset != nil, "photoEditor.asset!=nil")

        guard let asset = photoEditor.asset else { return }

        if let indexPath = indexPath {
            if let editItem = editItem, (editItem.hasChanges || !isSelectionMode) {
                if !isSelectionMode {
                    isSelectionMode = true
                }

                if AppAssets.selected.by(asset) == nil{
                    self.selectCollectionViewItem(at: indexPath, animated: false)
                }
                assert(AppAssets.selected.by(photoEditor.asset!) != nil, "AppAssets.selected.by(photoEditor.asset!) != nil")
                AppAssets.selected.by(asset)?.editState.concat(with: editItem)

                //INFO: sync edit states between dock content and photo editor dock content for a single photo
                if let app = AppCenter.default.currentInstanceAs(EditableApp.self), AppAssets.selected.count == 1 {
                    app.setDefaultEditState(value:AppAssets.selected.by(asset)?.editState.imageEditStateValue)
                }
            }
        }

        let tintColorToRestore = ((AppCenter.default.current as? ConfigurableApp.Type)?.defaultConfigValue as? AppConfigUIAttributeValuable)?.tintColor

        AppCenter.default.currentInstanceAs(ConfigurableApp.self)?.setConfigValues(AppConfigUIAttribute(tintColor: tintColorToRestore))

        appDockView?.setDrawerDisplay(forState: appDockContentLayoutStateRestoringAfterProcessing ?? .neutralized, reloadDockContentViews: true)

        batchPreviewView.reloadCollectionViewItems(animated: false)

        if let editItem = editItem {
            if let _ = photoEditor.transitionAnimator.sourceView as? PhotoCollectionViewCell, let index = AppAssets.selected.index(for: asset), let cell = batchPreviewView.collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? PreviewCollectionViewCell {

                photoEditor.transitionAnimator.sourceView?.isHidden = false
                cell.isHidden = true

                photoEditor.transitionAnimator.sourceView = cell
                photoEditor.transitionAnimator.sourceRect = cell.frame
            }

            let transformedSize = photoEditor.transitionAnimator.sourceRect.size.applying(editItem.transform).magnitude
            photoEditor.transitionAnimator.sourceRect.size = transformedSize

            if let cell = photoEditor.transitionAnimator.sourceView as? PreviewCollectionViewCell {
                let point = batchPreviewView.collectionView.convert(cell.frame, to: view).origin
                photoEditor.transitionAnimator.sourceRect.origin = CGPoint(x: point.x + (cell.bounds.width - transformedSize.width) / 2, y: point.y + (cell.bounds.height - transformedSize.height) / 2)
            }
        }

        photoEditor.dismiss(animated: true, completion: nil)
    }
}

extension PhotoPickerViewController: PreviewViewDelegate {
    var currentDisplayableApp: PhotoPickerViewControllerAppearanceDelegatableApp?{
        if AppCenter.default.current is PhotoPickerViewControllerAppearanceDelegatableApp.Type{
            return AppCenter.default.currentInstanceAs(PhotoPickerViewControllerAppearanceDelegatableApp.self)
        }
        return nil
    }

    func batchPreviewView(_ view: PreviewView, didSelectItemAt indexPath: IndexPath) {
        guard let selectedAssetItem = AppAssets.selected.at(unsafeIndex: indexPath.item) else { return }

        if let _ = AppCenter.default.currentInstanceAs(PhotoEditViewControllerDelegatableApp.self), appDockView?.contentLayoutState == .maximized {
            showPhotoEditor(with: selectedAssetItem, animated: true)
        }
        else {
            guard let indexPathInPhotoPicker = PHAssets.fetched.indexPath(of: selectedAssetItem.asset) else { return }
            photoCollectionView.scrollToItem(at: indexPathInPhotoPicker, at: .centeredVertically, animated: true)
        }
    }

    func batchPreviewViewWillBeginEdit(_ view: PreviewView) {
        titleFade = currentDisplayableApp?.titleWillBegin ?? "Starting the Process...".localized
        taskProgress = 0

        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.startAnimating()
        navigationItem.setRightBarButtonItems([UIBarButtonItem(customView: loadingIndicator)], animated: true)

        progressBar.isHidden = false
        progressBar.progress = 0
        UIView.animate(withDuration: 0.2) {
            self.progressBar.alpha = 1
        }

        updateAppDockViewProcessingStart()
    }

    private func updateProgress(_ progress: Float, title: String, animated: Bool = true) {
        let progress = progress.clamped(to: 0...1)
        let progressText = currentDisplayableApp?.titleDidUpdate(progress: progress)
            ?? title + " \(Int(progress * 100))%"

        if animated {
            titleFade = progressText
        }
        else {
            self.title = progressText
        }

        progressBar.setProgress(progress, animated: animated)
    }

    func batchPreviewView(_ view: PreviewView, didUpdateProgress progress: Progress) {
        let progressValue = (Float(progress.fractionCompleted) * Float(AppAssets.selected.count)) / Float(AppAssets.selected.count + 1)
        if progressBar.progress < progressValue {
            taskProgress = progressValue
            updateProgress(progressValue, title: "Processing...".localized)
        }
    }

    func batchPreviewView(_ view: PreviewView, didUpdateRemoteFetchingProgress progress: Progress) {
        guard AppAssets.selected.count > 0 else { return }
        let fetchingProgressPerTask = Float(progress.fractionCompleted) / Float(AppAssets.selected.count)
        let currentProgress = taskProgress + fetchingProgressPerTask / 2 // for split progress into fetching and processing
        let progressValue = (currentProgress * Float(AppAssets.selected.count)) / Float(AppAssets.selected.count + 1)
        if progressBar.progress < progressValue {
            updateProgress(progressValue, title: "Downloading...".localized)
        }
    }

    func batchPreviewView(_ view: PreviewView, didUpdateInternalProgress progress: Progress) {
        guard AppAssets.selected.count > 0 else { return }

        let fetchingProgressPerTask = Float(progress.fractionCompleted) / Float(AppAssets.selected.count + 1)
        let currentProgress = taskProgress + fetchingProgressPerTask / 2 // for split progress into fetching and processing
        let progressValue = (currentProgress * Float(AppAssets.selected.count)) / Float(AppAssets.selected.count + 1)
        if progressBar.progress < progressValue {
            updateProgress(progressValue, title: "Processing...".localized)
        }
    }

    func batchPreviewViewWillCancelProgress(_ view: PreviewView) {
        titleFade = currentDisplayableApp?.titleWillCancel ?? "Cancelling...".localized

        UIView.animate(withDuration: 0.6) {
            self.progressBar.alpha = 0
        }
    }

    func batchPreviewViewWillFinalize(_ view: PreviewView) {
        updateProgress(taskProgress, title: currentDisplayableApp?.titleWillFinalize ?? "Saving Results...".localized)

        //INFO: update PHPhotoLibraryChangeObserver immediately
        DispatchQueue.main.async {
            PhotosManager.default.cachingImageManager.stopCachingImagesForAllAssets()
        }
    }

    func batchPreviewView(_ view: PreviewView, didUpdateFinalizingProgress progress: Progress) {
        guard AppAssets.selected.count > 0 else { return }

        let fetchingProgressPerTask = Float(progress.fractionCompleted) / Float(AppAssets.selected.count + 1)
        let progressValue = taskProgress + fetchingProgressPerTask
        if progressBar.progress < progressValue {
            updateProgress(progressValue, title: currentDisplayableApp?.titleWillFinalize ?? "Saving Results...".localized)
        }
    }

    func batchPreviewViewDidCancelEdit(_ view: PreviewView) {
        progressBar.isHidden = true

        updateAllPhotosTitle()
        updateUIDisplays()
        updateVisibleCellsEnabled()

        updateAppDockViewProcessingEnd()
    }

    func batchPreviewViewDidEndEdit(_ view: PreviewView, assetsForFinished assets: [PHAsset]) {
        progressBar.isHidden = true

        if !assets.isEmpty {
            isSelectionMode = false
        }

        //POLICY: no keeps selected items
        deselectCollectionViewItems(assets.compactMap({ asset -> IndexPath? in
            return PHAssets.fetched.indexPath(of: asset)
        }))

        updateAllPhotosTitle()
        updateUIDisplays()
        updateVisibleCellsEnabled()

        updateAppDockViewProcessingEnd()

        //POLICY: add recently used shortcut item
        ShortcutItemAppDelegate.appendShortcutItem(by: AppCenter.default.current)
    }

    private func updateAppDockViewProcessingStart() {
        appDockContentLayoutStateRestoringAfterProcessing = appDockView?.contentLayoutState
        appDockView?.setDrawerDisplay(forState: .minimized, reloadDockContentViews: true)

        appDockView?.disabled = true
    }

    private func updateAppDockViewProcessingEnd() {
        if let state = appDockContentLayoutStateRestoringAfterProcessing {
            appDockView?.setDrawerDisplay(forState:state, reloadDockContentViews: true)
            appDockContentLayoutStateRestoringAfterProcessing = nil
        }

        appDockView?.disabled = false
    }

    func batchPreviewView(_ view: PreviewView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        if let _ = AppCenter.default.currentInstanceAs(PhotoEditViewControllerDelegatableApp.self), appDockView?.contentLayoutState != .maximized {
            return true
        }
        else {
            return false
        }
    }

    func batchPreviewView(_ view: PreviewView, titleForMenuItemAt indexPath: IndexPath) -> String? {
        if let _ = AppCenter.default.currentInstanceAs(PhotoEditViewControllerDelegatableApp.self) {
            return "Edit".localized
        }
        else if let app = AppCenter.default.currentInstanceAs(AppPreviewActionable.self) {
            return app.titleForAction
        }
        else {
            return nil
        }
    }

    func batchPreviewView(_ view: PreviewView, didSelectMenuItemAt indexPath: IndexPath) {
        guard let selectedAssetItem = AppAssets.selected.at(unsafeIndex: indexPath.item) else { return }
        if let _ = AppCenter.default.currentInstanceAs(PhotoEditViewControllerDelegatableApp.self) {
            showPhotoEditor(with: selectedAssetItem, animated: true)
        }
        else if let app = AppCenter.default.currentInstanceAs(AppPreviewActionable.self) {
            DispatchQueue(label: #function + "AppPreviewActionable", qos: .utility).async {
                app.didAction(with: selectedAssetItem)
            }
        }
    }
}

extension PhotoPickerViewController: AppDockViewDelegate{
    func appDockView(_ view: AppDockView, needsScrollToBottom: Bool) {
        self.needsScrollToBottom = needsScrollToBottom
    }

    func appDockView(_ view: AppDockView, didSelectItemWith item: AppDockItem) {
        let willAppChange = AppCenter.default.current != item.app

        AppCenter.default.current = item.app

        view.loadControllerContentIfNeeded()

        if willAppChange {
            appDidChange()
        }
        else {
            if photoCollectionView.contentOffset.y >= self.scrollingBottomOffsetY{
                if appDockView?.contentLayoutState == .minimized {
                    appDockView?.openDrawer()
                }
            }
            else {
                scrollToBottomIfNeeded(animated: true)
            }
        }

        appDidAppear()
    }

    func appDockView(_ view: AppDockView, didOpenDrawer isOpened: Bool) {
        setViewControllerDisabled(isOpened)
    }
}
