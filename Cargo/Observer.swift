//
//  Observer.swift
//  Cargo
//
//  Created by Skylar Schipper on 4/26/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

/// Download observer protocol.
///
/// All methods will be called on an arbitrary queue.
///
/// Adding/removing observers within that method will result in a deadlock.
@objc(CARObserver)
public protocol Observer : ManagedObserver {
    @objc(manager:scheduledContainer:)
    optional func manager(_ manager: Manager, scheduledContainer container: Container)

    @objc(manager:didProgress:forContainer:)
    optional func manager(_ manager: Manager, didProgress progress: Progress, forContainer container: Container)

    @objc(manager:completedDownload:forContainer:)
    optional func manager(_ manager: Manager, completedDownload download: Int64, forContainer container: Container)
}
