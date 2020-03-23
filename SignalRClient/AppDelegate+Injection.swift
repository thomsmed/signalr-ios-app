//
//  AppDelegate+Injection.swift
//  signalr
//
//  Created by thomsmed on 15/03/2020.
//  Copyright © 2020 Thomas A. Smedmann. All rights reserved.
//

import Foundation
import Resolver

extension Resolver: ResolverRegistering {
    public static func registerAllServices() {
        Resolver.register(factory: {
            SignalRHubConnectionBuilder() as SignalRHubConnectionBuilderProtocol
        })
    }
}
