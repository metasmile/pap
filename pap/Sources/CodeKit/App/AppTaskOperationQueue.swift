//
// Created by BLACKGENE on 24/01/2018.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation

protocol AppTaskOperationQueueDelegate: AnyObject {
    func delegatingQueue(from:AppTaskOperationQueue) -> DispatchQueue

    func willPerformTask(_ queue: AppTaskOperationQueue, _ workItem: AppTaskItem)
    func didCompleteTask(_ queue: AppTaskOperationQueue, _ workItem: AppTaskItem)
    func didCancelTask(_ queue: AppTaskOperationQueue, _ workItem: AppTaskItem)
    func didFailTask(_ queue: AppTaskOperationQueue, _ workItem: AppTaskItem)

    func didFinishAllTasksInQueue(_ queue: AppTaskOperationQueue, _ result: [AppTaskItem]?)
}

class AppTaskOperationQueue: ItemQueue<AppTaskItem> {

    private var finshedItemQueue = ItemQueue<AppTaskItem>()
    private weak var delegate: AppTaskOperationQueueDelegate?

    private(set) public var currentTaskInfo: AppTaskInfo?
    private(set) public var cancelled:Bool = false
    private(set) public var suspended = false

    private let queue:DispatchQueue = DispatchQueue(
            label: "com.stells_internal_\(UUID().uuidString)"
            , qos: .utility
            , attributes: []
            , autoreleaseFrequency: .workItem
            , target: nil
    )
    
    private let stateOperationQueue:DispatchQueue = DispatchQueue(
        label: "com.stells_internal_\(UUID().uuidString)"
        , qos: DispatchQoS(qosClass: .userInteractive, relativePriority: 0)
        , attributes: []
        , autoreleaseFrequency: .workItem
        , target: nil
    )

    private let asyncSignal = AsyncSignal()

    internal var label:String{
        return self.queue.label
    }

    required init(delegate: AppTaskOperationQueueDelegate) {
        self.delegate = delegate
    }

    //overriden
    final func isEnqueued(_ item: AppTaskItem) -> Bool{
        return self.iterator().contains { e -> Bool in
            e.info.requestToken == item.info.requestToken
        }
    }

    override func enqueue(_ item: AppTaskItem, reverse: Bool=false) {
        if isEnqueued(item) { return }

        item.info.queueLabel = self.label
        item.info.state = .idling
        super.enqueue(item, reverse:reverse)
    }

    //external interface
    private var callbackQueue:DispatchQueue {
        return self.delegate?.delegatingQueue(from: self) ?? DispatchQueue.main
    }

    private func dispatchFinishedForEach(item: AppTaskItem) {
        let d = self.delegate
        var exe:(() -> Void)?

        switch(item.info.state){
        case .performing:
            exe = { d?.willPerformTask(self, item) }

        case .cancelled:
            exe = { d?.didCancelTask(self, item) }

        case .failed:
            exe = { d?.didFailTask(self, item) }

        case .completed:
            exe = { d?.didCompleteTask(self, item) }

        default:
            assert(false, "item.info.state was wrongly setted [state]" + String(describing:item.info.state))
        }

        if let _exe = exe{
            _exe()
        }

        print("> "
                , item.info.state
                , item.task.info.requestToken, "->"
                , item.task.info.token, "->"
                , self.queue.label)
    }

    private func dispatchFinishedAll(){
        assert(self.count==0)
        assert(self.finshedItemQueue.count>0)
        print("dispatchFinishedResults", self.count, self.finshedItemQueue.count)

        let queueResult = self.finshedItemQueue.dequeueAll()
        self.callbackQueue.async {
            self.delegate?.didFinishAllTasksInQueue(self, queueResult)
        }
    }

    private func cancelItem(_ item: AppTaskItem, _ async: AsyncWaitSignalable & AsyncFinalSignalable) {
        let param = item.request.param

        async.done()
        item.task.cancel(param, async)
        item.response(.cancelled)
    }

    private func tryItem(_ item: AppTaskItem, _ async: AsyncWaitSignalable & AsyncFinalSignalable){
        let param = item.request.param

        do {

            if let result = try item.task.perform(param, async){
                item.result = result
                item.response(.completed)
                return
            }

            throw AppTaskError.invalidResult

        } catch let e as AppTaskError {
            async.done()
            _ = self.cancelled ? item.response(.cancelled) : item.response(.failed, e)

        } catch {
            async.done()
            item.response(.failed, AppTaskError.unknown)
        }
    }

    func perform() {
        if suspended{
            suspended = false
            return
        }

        guard let item = self.peek() else {
            if currentTaskInfo != nil {
                currentTaskInfo = nil
                cancelled = false

                dispatchFinishedAll()

                print("-------> finished queue", self.queue.label)
            }
            return
        }

        if currentTaskInfo?.token == item.info.token {
            return
        }

        currentTaskInfo = item.info

        let _cancelled = self.cancelled

        queue.async { [unowned self] in

            if _cancelled{
                self.cancelItem(item, self.asyncSignal)
            }else{
                self.tryItem(item, self.asyncSignal)
            }

            self.callbackQueue.async{

                // dequeue
                guard let finishedItem = self.dequeue() else {
                    assert(false,"dequeued item must not be nil at here.")
                    return
                }
                self.finshedItemQueue.enqueue(finishedItem)
                self.dispatchFinishedForEach(item:finishedItem)

                // perform next task
                self.perform()
            }
        }
    }

    func cancel(){
        assert(cancelled==false, "cancelled is already true. What's wrong??")
        if cancelled || self.count==0{
            return
        }

        //set cancel flag and then from next item may cancel before it performs.
        cancelled = true

        //cancel currently progressing item
        if let currentItem = self.peek() {
            stateOperationQueue.async { [unowned self] in
                self.cancelItem(currentItem, self.asyncSignal)
            }
        }

        if currentTaskInfo == nil{
            perform()
        }
    }

    func suspend(){
        if self.count==0 || currentTaskInfo == nil{
            return
        }

        suspended = true
    }
}


class AppTaskItem: AppTaskRespondable {
    let request:AppTaskRequest
    let info: AppTaskInfo
    let task: AppTaskable

    public fileprivate(set) var result: AppTaskResultable?

    init(request:AppTaskRequest, info: AppTaskInfo, task: AppTaskable){
        self.request=request
        self.info=info
        self.task=task
    }
}

extension AppTaskItem {

    // if canceled by requester, return false, passed, return true
    @discardableResult
    func response(_ state: AppTaskState, _ error: AppTaskError?=nil) -> Bool{
        task.info.state = state
        task.info.error = error

        var canceled = false
        request.responseHandler?(self, &canceled)
        return !canceled
    }

    static func ==(lhs: AppTaskItem, rhs: AppTaskItem) -> Bool {
        let lhsInfo = lhs.info, rhsInfo = rhs.info
        return lhsInfo.token == rhsInfo.token
                && lhsInfo.requestToken == rhsInfo.requestToken
                && lhsInfo.taskType == rhs.info.taskType
                && lhsInfo.state == rhsInfo.state
    }
}