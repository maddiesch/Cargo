//
//  CacheBrowserViewController.swift
//  Cargo
//
//  Created by Skylar Schipper on 6/8/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation
import UIKit
import CoreData

@objc(CARCacheBrowserViewController)
public final class CacheBrowserViewController : UITableViewController, NSFetchedResultsControllerDelegate {
    private enum DismissMode {
        case pop
        case dismiss
    }

    private var dismissMode: DismissMode = .dismiss

    public final class func present(from viewController: UIViewController, animated: Bool) {
        let controller = CacheBrowserViewController(style: .grouped)
        if let navigation = viewController as? UINavigationController {
            controller.dismissMode = .pop
            navigation.pushViewController(controller, animated: animated)
        } else {
            let navigation = UINavigationController(rootViewController: controller)
            viewController.present(navigation, animated: animated, completion: nil)
        }
    }

    public override func loadView() {
        super.loadView()

        self.tableView.register(FileCell.self, forCellReuseIdentifier: FileCell.identifier)
        self.tableView.allowsMultipleSelectionDuringEditing = false
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.title = NSLocalizedString("Cache Manager", comment: "Cargo cache manager view controller title")

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissButtonAction))

        self.fetchController.delegate = self
        try? self.fetchController.performFetch()
    }

    @objc private func dismissButtonAction(_ sender: Any) {
        switch self.dismissMode {
        case .pop:
            self.navigationController?.popViewController(animated: true)
        case .dismiss:
            self.presentingViewController?.dismiss(animated: true, completion: nil)
        }
    }

    lazy var context: NSManagedObjectContext = {
        return Cache.shared.metadata.createViewerContext()
    }()

    // MARK: - Fetch Controller
    lazy var fetchController: NSFetchedResultsController<CachedFile> = {
        let fetch = NSFetchRequest<CachedFile>(entityName: "CachedFile")
        fetch.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "viewable = YES"),
            NSPredicate(format: "expiresAt >= %@", Date() as CVarArg)
            ])
        fetch.sortDescriptors = [
            NSSortDescriptor(key: "name", ascending: true),
            NSSortDescriptor(key: "cacheKey", ascending: true)
        ]
        fetch.fetchBatchSize = 100
        return NSFetchedResultsController(fetchRequest: fetch, managedObjectContext: self.context, sectionNameKeyPath: nil, cacheName: nil)
    }()

    private var hiddenFileCount: (Int, Int) {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "CachedFile")
        fetch.resultType = .dictionaryResultType
        fetch.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "viewable = NO"),
            NSPredicate(format: "expiresAt >= %@", Date() as CVarArg)
            ])

        do {
            let count = NSExpressionDescription()
            count.name = "total"
            count.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "cacheKey")])
            count.expressionResultType = .integer64AttributeType

            let size = NSExpressionDescription()
            size.name = "bytes"
            size.expression = NSExpression(forFunction: "sum:", arguments: [NSExpression(forKeyPath: "fileSize")])
            size.expressionResultType = .integer64AttributeType

            fetch.propertiesToFetch = [count, size]
        }

        guard let result = try? self.context.fetch(fetch) else {
            return (0, 0)
        }

        guard let hash = result.first as? [String: Int] else {
            return (0, 0)
        }

        let count = hash["total"] ?? 0
        let size = hash["bytes"] ?? 0

        return (count, size)
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.reloadData()
    }

    // MARK: - Table View
    public override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return self.fetchController.fetchedObjects?.count ?? 0
        case 1:
            return 1
        case 2:
            return 1

        default:
            return 0
        }
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FileCell.identifier, for: indexPath)
        cell.selectionStyle = .none
        cell.textLabel?.textColor = .black

        switch indexPath.section {
        case 0:
            let file = (self.fetchController.fetchedObjects ?? [])[indexPath.row]
            cell.textLabel?.text = file.value(forKey: "name") as? String
            if let size = file.value(forKey: "fileSize") as? Int64 {
                cell.detailTextLabel?.text = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            } else {
                cell.detailTextLabel?.text = nil
            }
            return cell
        case 1:
            let (count, bytes) = self.hiddenFileCount
            if count == 1 {
                cell.textLabel?.text = NSLocalizedString("\(count) other miscellaneous file", comment: "")
            } else {
                cell.textLabel?.text = NSLocalizedString("\(count) other miscellaneous files", comment: "")
            }
            cell.detailTextLabel?.text = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            return cell
        case 2:
            cell.textLabel?.text = NSLocalizedString("Delete All", comment: "Delete all PDFs from cache")
            cell.selectionStyle = .default
            cell.textLabel?.textColor = UIColor(red: 0.896, green: 0.264, blue: 0.282, alpha: 1.0)
            cell.detailTextLabel?.text = nil
            return cell
        default:
            return cell
        }
    }

    public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            switch indexPath.section {
            case 0:
                self.deleteFileAtIndex(indexPath.row)
            case 1:
                self.deleteHiddenFiles()
            default:
                break
            }
            tableView.reloadData()
        }
    }

    public override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch indexPath.section {
        case 2:
            return false
        default:
            return true
        }
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 2:
            self.deleteAllFiles()
        default:
            break
        }
    }

    public override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch indexPath.section {
        case 2:
            return indexPath
        default:
            return nil
        }
    }

    private func deleteHiddenFiles() {
        do {
            let fetch = NSFetchRequest<CachedFile>(entityName: "CachedFile")
            fetch.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "viewable = NO")
                ])
            let results = try self.context.fetch(fetch)
            for result in results {
                self.context.delete(result)
            }
            if self.context.hasChanges {
                try self.context.save()
            }
        } catch {
            print(error)
        }
    }

    private func deleteFileAtIndex(_ index: Int) {
        let file = (self.fetchController.fetchedObjects ?? [])[index]
        self.context.delete(file)
        if self.context.hasChanges {
            try? self.context.save()
        }
    }

    private func deleteAllFiles() {
        for file in self.fetchController.fetchedObjects ?? [] {
            self.context.delete(file)
        }
        self.deleteHiddenFiles()
    }
}

fileprivate class FileCell : UITableViewCell {
    static let identifier = "fileCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
