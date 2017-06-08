//
//  CacheMetadata.swift
//  Cargo
//
//  Created by Skylar Schipper on 5/4/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation
import CoreData

internal final class CacheMetadata {
    private var isReady = false

    private var ctx: NSManagedObjectContext? = nil

    private let mutex = Mutex(type: .recursive)

    private let location: URL

    private var observer: NSObjectProtocol? = nil

    init(_ location: URL) {
        self.location = location.appendingPathComponent("metadata.sqlite")
    }

    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private let defaultOptions: [AnyHashable: Any] = [
        NSMigratePersistentStoresAutomaticallyOption: true,
        NSInferMappingModelAutomaticallyOption: true
    ]

    func perform(inContext block: @escaping (NSManagedObjectContext) throws -> (Void)) throws {
        guard let context = self.ctx else {
            return
        }
        var blockError: Error? = nil
        context.performAndWait {
            do {
                try block(context)
            } catch {
                blockError = error
            }
        }
        if let error = blockError {
            throw error
        }
    }

    func flush() throws {
        try self.mutex.synchronized {
            guard let ctx = self.ctx else {
                return
            }
            self.ctx = nil
            ctx.performAndWait {
                ctx.reset()
            }
            guard let psc = ctx.persistentStoreCoordinator else {
                return
            }
            try psc.destroyPersistentStore(at: self.location, ofType: NSSQLiteStoreType, options: self.defaultOptions)
            self.isReady = false
            try self.openIfNeeded()
        }
    }

    func openIfNeeded() throws {
        try self.mutex.synchronized {
            guard self.isReady == false else {
                return
            }

            let model = CreateManagedObjectModel()

            let psc = NSPersistentStoreCoordinator(managedObjectModel: model)

            _ = try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: self.location, options: self.defaultOptions)

            self.createContext(psc)

            if let observer = self.observer {
                NotificationCenter.default.removeObserver(observer)
            }

            self.observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: nil, queue: nil, using: { [weak self] (notif) in
                self?.mergeChangesFromSaveNotification(notif)
            })

            self.isReady = true
        }
    }

    internal func createViewerContext() -> NSManagedObjectContext {
        guard let psc = self.ctx?.persistentStoreCoordinator else {
            fatalError()
        }
        let ctx = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        ctx.persistentStoreCoordinator = psc
        ctx.mergePolicy = NSOverwriteMergePolicy
        ctx.retainsRegisteredObjects = false
        ctx.shouldDeleteInaccessibleFaults = true
        return ctx
    }

    private func createContext(_ psc: NSPersistentStoreCoordinator) {
        let ctx = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        ctx.persistentStoreCoordinator = psc
        ctx.mergePolicy = NSOverwriteMergePolicy
        ctx.retainsRegisteredObjects = false
        ctx.shouldDeleteInaccessibleFaults = true
        self.ctx = ctx
    }

    private func mergeChangesFromSaveNotification(_ notif: Notification) {
        guard let saved = notif.object as? NSManagedObjectContext else {
            return
        }
        guard let context = self.ctx else {
            return
        }
        guard context != saved else {
            return
        }
        guard context.persistentStoreCoordinator == saved.persistentStoreCoordinator else {
            return
        }
        context.performAndWait {
            context.mergeChanges(fromContextDidSave: notif)
        }
    }
}

func CreateManagedObjectModel() -> NSManagedObjectModel {
    let model = NSManagedObjectModel()
    model.entities = [
        CachedFile.createEntityDescription()
    ]
    return model
}

func CreateAttribute(_ name: String, _ type: NSAttributeType, _ indexed: Bool = false, _ optional: Bool = true, allowExternal: Bool = false) -> NSAttributeDescription {
    let desc = NSAttributeDescription()
    desc.name = name
    desc.attributeType = type
    desc.isIndexed = indexed
    desc.isOptional = optional
    desc.allowsExternalBinaryDataStorage = allowExternal
    return desc
}
