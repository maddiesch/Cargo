//
//  Cache.swift
//  Cargo
//
//  Created by Skylar Schipper on 5/3/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

@objc(CARCache)
public final class Cache : NSObject, FileManagerDelegate {
    @objc(sharedCache)
    public static let shared = Cache()

    private lazy var fileManager: FileManager = {
        let fm = FileManager()
        fm.delegate = self
        return fm
    }()

    internal static let baseDirectory = "com.skylarsch.cargo-cache"

    private var location: URL = {
        guard let support = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first else {
            fatalError("Can't find application support directory")
        }
        return URL(fileURLWithPath: "\(support)/\(Cache.baseDirectory)/")
    }()

    private let mutex = Mutex()
    private var isPrepared: Bool = false

    /// Prepare the context for operations
    public func prepare() throws {
        try self.mutex.synchronized {
            if self.isPrepared {
                return
            }
            try self.queue.sync(flags: .barrier) {
                try self.fileManager.createDirectory(at: self.location, withIntermediateDirectories: true, attributes: nil)
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try self.location.setResourceValues(values)
            }
            try self.metadata.openIfNeeded()
            self.isPrepared = true
        }
    }

    private let queue = DispatchQueue(label: "com.skylarsch.Cargo-Cache", qos: .utility, attributes: .concurrent)

    internal lazy var metadata: CacheMetadata = {
        return CacheMetadata(self.location)
    }()

    /// Move a file into the cache
    ///
    /// - Parameters:
    ///   - location: The current location of the file
    ///   - key: The key where the file should be cached
    ///   - name: The file name for the file
    ///   - completion: An optional callback when the move is completed
    @objc(moveFileAtLocation:intoCacheForKey:withName:completion:)
    public func move(fileAtLocation location: URL, intoCacheForKey key: String, withName name: String, completion: ((Error?) -> (Void))?) {
        self.queue.async {
            do {
                try self.move(location, key, name)
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }

    /// Get a location for a cached file on disk.
    ///
    /// - Parameters:
    ///   - key: The key where the file should be cached
    ///   - name: The name of the file
    /// - Returns: A file location
    @objc(locationOfFileForKey:withName:error:)
    public func location(ofFileForKey key: String, withName name: String) throws -> URL {
        let key = try CacheKey(rawKey: key)
        let fn = try CacheKey.normailize(name)
        var location: URL? = nil
        var meta: [String: Any] = [:]

        try self.metadata.perform { ctx in
            let file = try CachedFile.find(inContext: ctx, forKey: key.key, fileKey: fn)
            if let path = file.value(forKey: "location") as? String {
                location = self.location.appendingPathComponent(path)
                meta["path"] = path
                meta["objectID"] = file.objectID
            }
        }
        if let result = location {
            return result
        }
        throw CacheError(.fileNotFound, "File not found", "Failed to find file location", nil, meta)
    }

    /// Check if a file exists in the cache.
    /// This method isn't 100% accurate because there could be other cache operations happening at the same time.
    ///
    /// - Parameters:
    ///   - key: The cache key used for file lookup
    ///   - name: The name of the file in the cache.
    /// - Returns: If the file exists or not
    @objc(fileExistsForKey:fileName:)
    public func file(existsForKey key: String, fileName name: String) -> Bool {
        do {
            let location = try self.location(ofFileForKey: key, withName: name)
            return self.queue.sync {
                return self.fileManager.fileExists(atPath: location.path)
            }
        } catch {
            return false
        }
    }

    /// Delete all cached files for the key
    ///
    /// - Parameter key: The key to remove
    public func delete(filesForKey key: String) {
        self.queue.async(group: nil, qos: .unspecified, flags: .barrier) {
            do {
                let key = try CacheKey(rawKey: key)
                try self.metadata.perform { ctx in
                    let files = try CachedFile.files(forKey: key.key, inContext: ctx)
                    for file in files {
                        ctx.delete(file)
                    }
                    if ctx.hasChanges {
                        try ctx.save()
                    }
                }
            } catch {
                print("Failed to delete: \(error)")
            }
        }
    }

    /// Delete a single file from the cached key
    ///
    /// - Parameters:
    ///   - key: The key where the file is located
    ///   - name: The name of the file to delete
    public func delete(fileForKey key: String, withName name: String) {
        self.queue.async(group: nil, qos: .unspecified, flags: .barrier) {
            do {
                let key = try CacheKey(rawKey: key)
                let cName = try CacheKey.normailize(name)
                try self.metadata.perform { ctx in
                    let file = try CachedFile.find(inContext: ctx, forKey: key.key, fileKey: cName)
                    ctx.delete(file)
                    if ctx.hasChanges {
                        try ctx.save()
                    }
                }
            } catch {
                print("Failed to delete: \(error)")
            }
        }
    }

    // MARK: - Internal management
    internal func remove(fileWithPath path: String) {
        self.queue.async {
            let location = self.location.appendingPathComponent(path)
            try? self.fileManager.removeItem(at: location)
        }
    }

    internal func move(fileAtLocation location: URL, intoCacheForKey key: String, withName name: String) throws {
        try self.queue.sync {
            try self.move(location, key, name)
        }
    }

    private func move(_ location: URL, _ key: String, _ name: String) throws {
        let key = try CacheKey(rawKey: key)
        let cName = try CacheKey.normailize(name)
        let base = key.location(self.location)
        let destination = base.appendingPathComponent(UUID().uuidString).appendingPathExtension((name as NSString).pathExtension)
        try self.fileManager.createDirectory(at: base, withIntermediateDirectories: true, attributes: nil)
        try self.fileManager.moveItem(at: location, to: destination)
        try self.metadata.perform { ctx in
            try CachedFile.create(inContext: ctx, forFileAtLocation: destination, withKey: key.key, fileKey: cName, fileName: name)
            if ctx.hasChanges {
                try ctx.save()
            }
        }
    }

    // MARK: - FileManager Delegate
    public func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, movingItemAt srcURL: URL, to dstURL: URL) -> Bool {
        // Allow overwrite
        return true
    }
}
