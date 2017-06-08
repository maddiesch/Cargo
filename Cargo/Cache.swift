//
//  Cache.swift
//  Cargo
//
//  Created by Skylar Schipper on 5/3/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

internal let BaseCacheDirectoryName = "com.skylarsch.cargo-cache-v1"

@objc(CARCache)
public final class Cache : NSObject, FileManagerDelegate {
    @objc(sharedCache)
    public static let shared = Cache()

    private var location: URL = {
        guard let support = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first else {
            fatalError("Can't find application support directory")
        }
        return URL(fileURLWithPath: "\(support)/\(BaseCacheDirectoryName)/")
    }()

    // MARK: - File System Access
    private lazy var fileManager: FileManager = {
        let fm = FileManager()
        fm.delegate = self
        return fm
    }()

    private lazy var fileSystemQueue: DispatchQueue = {
        return DispatchQueue(label: "com.skylarsch.cargo-fs", qos: .userInitiated)
    }()

    internal func fs<T>(_ block: (FileManager) throws -> (T)) rethrows -> T {
        return try self.fileSystemQueue.sync {
            return try block(self.fileManager)
        }
    }

    // MARK: - Preperation
    private let prepareQueue = DispatchQueue(label: "com.skylarsch.cargo-prep")
    public var isPrepared: Bool {
        return self.prepareQueue.sync {
            return self._isPrepared
        }
    }
    private var _isPrepared: Bool = false

    public func prepareIfNeeded() throws {
        try self.prepareQueue.sync {
            if !self._isPrepared {
                try self.prepare()
            }
        }
    }
    private func prepare() throws {
        try self.fs { fm in
            try fm.createDirectory(at: self.location, withIntermediateDirectories: true, attributes: nil)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try self.location.setResourceValues(values)
        }
        try self.metadata.openIfNeeded()
        #if DEBUG
            print("Cargo: Cache prepared at location: \"\(self.location.path)\"")
        #endif
        self._isPrepared = true
    }

    // MARK: - Metadata
    internal lazy var metadata: CacheMetadata = {
        return CacheMetadata(self.location)
    }()

    /// Move a file into the cache
    ///
    /// - Parameters:
    ///   - location: The current location of the file
    ///   - key: The key where the file should be cached
    ///   - name: The file name for the file
    @objc(moveFileAtLocation:intoCacheForKey:withName:error:)
    public func move(fileAtLocation location: URL, intoCacheForKey key: String, withName name: String) throws {
        let key = try CacheKey(rawKey: key)
        let cName = try CacheKey.normailize(name)
        let base = key.location(self.location)
        let destination = base.appendingPathComponent(UUID().uuidString).appendingPathExtension((name as NSString).pathExtension)
        try self.fs { fm in
            try fm.createDirectory(at: base, withIntermediateDirectories: true, attributes: nil)
            try fm.moveItem(at: location, to: destination)
        }
        try self.metadata.perform { ctx in
            try CachedFile.create(inContext: ctx, forFileAtLocation: destination, withKey: key.key, fileKey: cName, fileName: name)
            if ctx.hasChanges {
                try ctx.save()
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
        guard let url = location else {
            throw CacheError(.fileNotFound, "File not found", "Failed to find file location", nil, meta)
        }
        if !self.fs { $0.fileExists(atPath: url.path) } {
            throw CacheError(.fileNotFound, "File not found", "Failed to find file", nil, meta)
        }
        return url
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
            _ = try self.location(ofFileForKey: key, withName: name)
            return true
        } catch {
            return false
        }
    }

    /// Delete all cached files for the key
    ///
    /// - Parameter key: The key to remove
    public func delete(filesForKey key: String) throws {
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
    }

    /// Delete a single file from the cached key
    ///
    /// - Parameters:
    ///   - key: The key where the file is located
    ///   - name: The name of the file to delete
    public func delete(fileForKey key: String, withName name: String) throws {
        let key = try CacheKey(rawKey: key)
        let cName = try CacheKey.normailize(name)
        try self.metadata.perform { ctx in
            let file = try CachedFile.find(inContext: ctx, forKey: key.key, fileKey: cName)
            ctx.delete(file)
            if ctx.hasChanges {
                try ctx.save()
            }
        }
    }

    // MARK: - Internal management
    internal func remove(fileWithPath path: String) throws {
        let location = self.location.appendingPathComponent(path)
        try self.fs {
            try $0.removeItem(at: location)
        }
    }

    // MARK: - FileManager Delegate
    public func fileManager(_ fileManager: FileManager, shouldProceedAfterError error: Error, movingItemAt srcURL: URL, to dstURL: URL) -> Bool {
        // Allow overwrite
        return true
    }
}
