//
// Created by BLACKGENE on 03.07.18.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation

import EventKit
import EventKitUI

extension EKEventEditViewController{

    private static var delegator:EKEventEditViewDelegator?

    public static func presentDialog(newEvent:EKEvent
            , onViewController:UIViewController?=nil
            , willPresent:((EKEventEditViewController) -> Bool)?=nil
            , didPresent:(() -> ())?=nil
            , willDismiss:((EKEventEditViewAction) -> ())?=nil
            , didDismiss:((EKEventEditViewAction) -> ())?=nil
    ){

        let presetingViewController = EKEventEditViewController()
        presetingViewController.event = newEvent
        presetingViewController.eventStore = EventKitUtil.shared.defaultEventStore

        let currentQueue = DispatchQueue.current

        if delegator == nil{
            delegator = EKEventEditViewDelegator()
        }

        if let delegator = delegator{
            delegator.watch(\EKEventEditViewDelegator.completedEKEventEditViewAction) {
                let completedAction = delegator.completedEKEventEditViewAction.action
                willDismiss?(completedAction)

                presetingViewController.dismiss(animated: true) {
                    didDismiss?(completedAction)

                    currentQueue.async {
                        self.delegator = nil
                    }
                }
            }
        }

        if let willPresent = willPresent, willPresent(presetingViewController) == false{
            return
        }
        assert(presetingViewController.delegate==nil, "Do not define delegate object at \(String(describing: willPresent))")

        presetingViewController.editViewDelegate = delegator

        (onViewController ?? UIViewController.presentable)?.present(presetingViewController, animated: true) {
            didPresent?()
        }
    }
}


private class EKEventEditViewActionObject:Object{
    let action:EKEventEditViewAction

    required init(action:EKEventEditViewAction){
        self.action = action
        super.init()
    }
}

private final class EKEventEditViewDelegator: Object, PropertyWatchable, EKEventEditViewDelegate{

    @objc dynamic
    var completedEKEventEditViewAction = EKEventEditViewActionObject(action: EKEventEditViewAction.canceled)

    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        self.completedEKEventEditViewAction = EKEventEditViewActionObject(action:action)
    }
}
