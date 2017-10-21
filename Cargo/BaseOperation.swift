//
//  BaseOperation.swift
//  Cargo
//
//  Created by Skylar Schipper on 4/25/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

@objc
internal protocol OperationObserver : ManagedObserver {
    func operation(_ operation: BaseOperation, didCompleteWithError error: Error?)

    func operationDidStart(_ operation: BaseOperation)
}

internal class BaseOperation : Operation {
    internal enum State {
        case ready
        case executing
        case finished
    }

    private let mutex = Mutex()

    private var _state = State.ready
    private var state: State {
        get {
            return self.mutex.synchronized { self._state }
        }
        set {
            self.willChangeValue(forKey: "state")
            self.mutex.synchronized { self._state = newValue }
            self.didChangeValue(forKey: "state")
        }
    }

    let observers = ObserverManager<OperationObserver>()

    var container: Container? = nil

    // MARK: - State Management
    public final override var isReady: Bool {
        return self.state == .ready && super.isReady
    }

    public final override var isExecuting: Bool {
        return self.state == .executing
    }

    public final override var isFinished: Bool {
        return self.state == .finished
    }

    public final override var isAsynchronous: Bool {
        return true
    }

    @objc private dynamic class func keyPathsForValuesAffectingIsReady() -> Set<String> {
        return ["state"]
    }

    @objc private dynamic class func keyPathsForValuesAffectingIsExecuting() -> Set<String> {
        return ["state"]
    }

    @objc private dynamic class func keyPathsForValuesAffectingIsFinished() -> Set<String> {
        return ["state"]
    }

    // MARK: - Running
    override final func start() {
        super.start()

        if self.isCancelled {
            self.finish()
            return
        }

        self.state = .executing

        self.observers.allObservers().forEach {
            $0.operationDidStart(self)
        }

        self.execute()
    }

    open func execute() {
        self.finish()
    }

    func finish(_ error: Error? = nil) {
        self.observers.allObservers().forEach {
            $0.operation(self, didCompleteWithError: error)
        }
        self.state = .finished
        self.container?.addError(error)
        self.operation(completedWithError: error)
    }

    open func operation(completedWithError error: Error?) {
        if let e = error {
            print("Error: \(e)")
        }
    }
}
