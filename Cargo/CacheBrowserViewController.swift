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
        fetch.predicate = NSPredicate(value: true)
        fetch.sortDescriptors = [
            NSSortDescriptor(key: "name", ascending: true),
            NSSortDescriptor(key: "cacheKey", ascending: true)
        ]
        fetch.fetchBatchSize = 100
        return NSFetchedResultsController(fetchRequest: fetch, managedObjectContext: self.context, sectionNameKeyPath: nil, cacheName: nil)
    }()

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.reloadData()
    }

    // MARK: - Table View
    public override func numberOfSections(in tableView: UITableView) -> Int {
        return self.fetchController.sections?.count ?? 0
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sections = self.fetchController.sections else {
            return 0
        }
        return sections[section].numberOfObjects
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let file = self.fetchController.object(at: indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: FileCell.identifier, for: indexPath)
        cell.selectionStyle = .none
        cell.textLabel?.text = file.value(forKey: "name") as? String

        if let size = file.value(forKey: "fileSize") as? Int64 {
            cell.detailTextLabel?.text = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        } else {
            cell.detailTextLabel?.text = nil
        }

        return cell
    }

    public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let file = self.fetchController.object(at: indexPath)
            self.context.delete(file)
            if self.context.hasChanges {
                try? self.context.save()
            }
            tableView.reloadData()
        }
    }
}

fileprivate class FileCell : UITableViewCell {
    static let identifier = "fileCell"

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

