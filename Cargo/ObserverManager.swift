//
//  ObserverManager.swift
//  Cargo
//
//  Created by Skylar Schipper on 5/3/17.
//  Copyright © 2017 Skylar Schipper. All rights reserved.
//

import Foundation

@objc(CARManagedObserver)
public protocol ManagedObserver : NSObjectProtocol {
}

internal class ObserverManager<Element : ManagedObserver> {
    private let queue = DispatchQueue(label: "com.skylarsch.Cargo-obs-manager")

    fileprivate var observers: [WeakManagedObserver<Element>] = []

    func addObserver(_ obs: Element) {
        self.queue.async {
            let raw = WeakManagedObserver(obs)
            self.observers.append(raw)
        }
    }

    func removeObserver(_ obs: Element) {
        self.queue.async {
            self.observers = self.observers.filter { $0.observer != nil }
            let raw = WeakManagedObserver(obs)
            if let index = self.observers.index(of: raw) {
                self.observers.remove(at: index)
            }
        }
    }

    func allObservers() -> [Element] {
        var obs: [Element] = []
        self.queue.sync {
            self.observers.forEach {
                if let o = $0.observer {
                    obs.append(o)
                }
            }
        }
        return obs
    }

    func forEachObserver(_ block: (Element) -> (Void)) {
        self.queue.sync {
            self.observers.forEach {
                if let o = $0.observer {
                    block(o)
                }
            }
        }
    }
}

fileprivate struct WeakManagedObserver<Element : ManagedObserver> : Hashable {
    var observer: Element?

    init(_ observer: Element) {
        self.observer = observer
    }

    static func ==(lhs: WeakManagedObserver, rhs: WeakManagedObserver) -> Bool {
        if lhs.observer == nil && rhs.observer == nil {
            return true
        }
        guard let ro = rhs.observer else {
            return false
        }
        return lhs.observer?.isEqual(ro) ?? false
    }

    var hashValue: Int {
        return self.observer?.hash ?? 0
    }
}
