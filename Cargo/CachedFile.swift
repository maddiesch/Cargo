//
//  CachedFile.swift
//  Cargo
//
//  Created by Skylar Schipper on 5/4/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation
import CoreData

internal class CachedFile : NSManagedObject {
    static func createEntityDescription() -> NSEntityDescription {
        let desc = NSEntityDescription()
        desc.name = "CachedFile"
        desc.managedObjectClassName = "Cargo.CachedFile"
        desc.properties = [
            CreateAttribute("uuid", .stringAttributeType, true, false),
            CreateAttribute("createdAt", .dateAttributeType, false, false),
            CreateAttribute("expiresAt", .dateAttributeType, true, false),
            CreateAttribute("cacheKey", .stringAttributeType, true, false),
            CreateAttribute("fileKey", .stringAttributeType, true, false),
            CreateAttribute("fileSize", .integer64AttributeType),
            CreateAttribute("fingerprint", .stringAttributeType),
            CreateAttribute("name", .stringAttributeType),
            CreateAttribute("cacheName", .stringAttributeType),
            CreateAttribute("location", .stringAttributeType),
            CreateAttribute("viewable", .booleanAttributeType, defaultValue: true)
        ]
        desc.uniquenessConstraints = [
            ["uuid"],
            ["cacheKey", "fileKey"]
        ]
        desc.compoundIndexes = [
            ["cacheKey", "fileKey"],
            ["viewable", "expiresAt"]
        ]
        return desc
    }

    @discardableResult
    static func create(inContext context: NSManagedObjectContext, forFileAtLocation location: URL, withKey key: String, fileKey: String, fileName: String, isVisible: Bool) throws -> CachedFile {
        let file: CachedFile = NSEntityDescription.insertNewObject(forEntityName: "CachedFile", into: context) as! CachedFile
        let info = try FileManager.default.attributesOfItem(atPath: location.path)
        let digest = try Digest.sha256Fingerprint(fileURL: location)
        guard let fingerprint = String(digest: digest) else {
            throw CacheError(.fingerprintFailed, "Failed to create file fingerprint")
        }

        let path = self.createStoreLocation(location)

        file.setValue(key, forKey: "cacheKey")
        file.setValue(fileKey, forKey: "fileKey")
        file.setValue(fileName, forKey: "name")
        file.setValue(info[.size], forKey: "fileSize")
        file.setValue(fingerprint, forKey: "fingerprint")
        file.setValue(location.lastPathComponent, forKey: "cacheName")
        file.setValue(path, forKey: "location")
        file.setValue(isVisible, forKey: "viewable")

        return file
    }

    private static func createStoreLocation(_ location: URL) -> String {
        let components = location.pathComponents.reversed()
        var parts: [String] = []
        for part in components {
            if part != BaseCacheDirectoryName {
                parts.append(part)
            } else {
                break
            }
        }
        return parts.reversed().joined(separator: "/")
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()

        self.setPrimitiveValue(UUID().uuidString, forKey: "uuid")
        self.setPrimitiveValue(Date(), forKey: "createdAt")
        self.setPrimitiveValue(Date.distantFuture, forKey: "expiresAt")
    }

    override func didSave() {
        if self.isDeleted {
            if let path = self.value(forKey: "location") as? String {
                try? Cache.shared.remove(fileWithPath: path)
            }
        }
        super.didSave()
    }

    static func find(inContext context: NSManagedObjectContext, forKey key: String, fileKey: String) throws -> CachedFile {
        let fetch = NSFetchRequest<CachedFile>(entityName: "CachedFile")
        fetch.predicate = NSPredicate(format: "cacheKey = %@ AND fileKey = %@", key, fileKey)
        fetch.fetchLimit = 1
        fetch.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let results = try context.fetch(fetch)
        guard let file = results.first else {
            throw CacheError(.fileNotFound, "File not found", "Failed to fetch file metadata", nil, ["key": key, "fKey": fileKey])
        }
        return file
    }

    static func files(forKey key: String, inContext context: NSManagedObjectContext) throws -> [CachedFile] {
        let fetch = NSFetchRequest<CachedFile>(entityName: "CachedFile")
        fetch.predicate = NSPredicate(format: "cacheKey = %@", key)
        fetch.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return try context.fetch(fetch)
    }
}
