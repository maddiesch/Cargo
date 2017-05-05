//
//  Manager.swift
//  Cargo
//
//  Created by Skylar Schipper on 4/25/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

/// Manager.  Handles Container scheduling
@objc(CARManager)
public final class Manager: NSObject {
    /// The singleton instance of the container
    @objc(defaultManager)
    public static let `default` = Manager()

    internal let queue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "com.skylarsch.Cargo"
        queue.maxConcurrentOperationCount = OperationQueue.defaultMaxConcurrentOperationCount
        queue.qualityOfService = .userInitiated
        return queue
    }()

    /// The caching instance
    public let cache = Cache()

    /// Schedule a container to perform all downloads.
    ///
    /// - Parameter container: The container to be scheduled
    /// - Throws: A scheduling error
    @objc(scheduleContainer:error:)
    public func schedule(container: Container) throws {
        try container.schedule(withManager: self, inQueue: self.queue)
        self.forEachObserver {
            $0.manager?(self, scheduledContainer: container)
        }
    }

    // MARK: - Observers
    private let manager = ObserverManager<Observer>()

    /// Add an observer object
    ///
    /// - Parameter obs: The observer to add. Will be stored weakly
    public func addObserver(_ obs: Observer) {
        self.manager.addObserver(obs)
    }

    /// The observer to remove
    ///
    /// - Parameter obs: Observer to remove
    public func removeObserver(_ obs: Observer) {
        self.manager.removeObserver(obs)
    }

    /// Return all observers
    public var allObservers: [Observer] {
        return self.manager.allObservers()
    }

    internal func forEachObserver(_ block: (Observer) -> (Void)) {
        self.manager.forEachObserver(block)
    }
}
