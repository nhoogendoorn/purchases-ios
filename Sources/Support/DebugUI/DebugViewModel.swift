//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  DebugViewModel.swift
//
//  Created by Nacho Soto on 5/30/23.

import Foundation

#if DEBUG && os(iOS) && swift(>=5.8)

import SwiftUI

@MainActor
@available(iOS 16.0, *)
final class DebugViewModel: ObservableObject {

    struct Configuration {

        let observerMode: Bool
        let sandbox: Bool
        let storeKit2Enabled: Bool
        let offlineCustomerInfoSupport: Bool
        let verificationMode: Signing.ResponseVerificationMode

    }

    var configuration: LoadingState<Configuration, Never> = .loading

    @Published
    var diagnosticsResult: LoadingState<(), NSError> = .loading
    @Published
    var offerings: LoadingState<Offerings, NSError> = .loading
    #if !ENABLE_CUSTOM_ENTITLEMENT_COMPUTATION
    @Published
    var customerInfo: LoadingState<CustomerInfo, NSError> = .loading
    #endif

    @Published
    var navigationPath = NavigationPath()

    func load() async {
        self.configuration = .loaded(.create())

        self.diagnosticsResult = await .create { try await PurchasesDiagnostics.default.testSDKHealth() }
        self.offerings = await .create { try await Purchases.shared.offerings() }
        #if !ENABLE_CUSTOM_ENTITLEMENT_COMPUTATION
        self.customerInfo = await .create { try await Purchases.shared.customerInfo() }

        for await info in Purchases.shared.customerInfoStream {
            self.customerInfo = .loaded(info)
        }
        #endif
    }

}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
extension DebugViewModel {

    var diagnosticsStatus: String {
        switch self.diagnosticsResult {
        case .loading: return "Loading..."
        case .loaded: return "Configuration OK"
        case let .failed(error): return "Error: \(error.localizedDescription)"
        }
    }

    @ViewBuilder
    var diagnosticsIcon: some View {
        switch self.diagnosticsResult {
        case .loading:
            Image(systemName: "gear.circle")
                .foregroundColor(.gray)
        case .loaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
        }
    }

}

// MARK: -

enum LoadingState<Value, Error: Swift.Error> {

    case loading
    case loaded(Value)
    case failed(Error)

}

extension LoadingState where Error == NSError {

    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.2, *)
    static func create(_ loader: @Sendable () async throws -> Value) async -> Self {
        do {
            return .loaded(try await loader())
        } catch {
            return .failed(error as NSError)
        }
    }

}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
private extension DebugViewModel.Configuration {

    static func create(with purchases: Purchases = .shared) -> Self {
        return .init(
            observerMode: purchases.observerMode,
            sandbox: purchases.isSandbox,
            storeKit2Enabled: purchases.storeKit2Setting.isEnabledAndAvailable,
            offlineCustomerInfoSupport: purchases.offlineCustomerInfoEnabled,
            verificationMode: purchases.responseVerificationMode
        )
    }

}

#endif