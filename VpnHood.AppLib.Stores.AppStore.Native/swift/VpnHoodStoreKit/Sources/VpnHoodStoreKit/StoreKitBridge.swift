// StoreKitBridge.swift — the C ABI facade over StoreKit 2 that
// NativeStoreKitBridge.cs P/Invokes.
//
// Contract (mirrored on the C# side, keep in sync):
//   - every function is @_cdecl, takes UTF-8 C strings, and completes exactly
//     once through the callback: (context, success, resultJsonUtf8)
//   - success=1 → resultJson is the payload; success=0 → resultJson is the
//     error message
//   - JSON field names are camelCase (System.Text.Json web defaults)
//
// It mirrors StoreKit and decides nothing for the app: which products it sells,
// what an introductory offer makes the first price, which entitlement counts and
// when a transaction is finished are the caller's, so changing any of them never
// needs this binary rebuilt.
//
// Why this exists: Microsoft.iOS and Microsoft.tvOS do not bind StoreKit 2's Swift-async API.
// This file is intentionally the package's ONLY Swift — everything above it is C#.

import Foundation
import StoreKit
import UIKit

public typealias VhskCallback = @convention(c) (
    UnsafeMutableRawPointer?, UInt8, UnsafePointer<CChar>?
) -> Void

private func complete(_ context: UnsafeMutableRawPointer?, _ callback: VhskCallback, ok: Bool, _ json: String) {
    json.withCString { callback(context, ok ? 1 : 0, $0) }
}

private func completeError(_ context: UnsafeMutableRawPointer?, _ callback: VhskCallback, _ error: Error) {
    complete(context, callback, ok: false, String(describing: error))
}

// ---------------------------------------------------------------- products --

@_cdecl("vhsk_load_products")
public func vhsk_load_products(
    _ productIdsJson: UnsafePointer<CChar>,
    _ context: UnsafeMutableRawPointer?,
    _ callback: @escaping VhskCallback
) {
    let idsData = Data(bytes: productIdsJson, count: strlen(productIdsJson))
    Task {
        do {
            let ids = try JSONDecoder().decode([String].self, from: idsData)
            let products = try await Product.products(for: ids)

            let mapped: [[String: Any]] = await withTaskGroup(of: [String: Any].self) { group in
                for product in products {
                    group.addTask { await mapProduct(product) }
                }
                var results: [[String: Any]] = []
                for await item in group { results.append(item) }
                return results
            }

            let json = try JSONSerialization.data(withJSONObject: mapped)
            complete(context, callback, ok: true, String(data: json, encoding: .utf8) ?? "[]")
        } catch {
            completeError(context, callback, error)
        }
    }
}

private func mapProduct(_ product: Product) async -> [String: Any] {
    var item: [String: Any] = [
        "id": product.id,
        "type": productType(product.type),
        "price": decimalToDouble(product.price),
        "currencyCode": product.priceFormatStyle.currencyCode,
        "currencySymbol": product.priceFormatStyle.locale.currencySymbol ?? product.priceFormatStyle.currencyCode
    ]

    // auto-renewable subscriptions only; StoreKit gives no other type this info
    if let subscription = product.subscription {
        let isEligibleForIntroOffer = await subscription.isEligibleForIntroOffer
        var mappedSubscription: [String: Any] = [
            "periodIso": isoDuration(subscription.subscriptionPeriod),
            "isEligibleForIntroOffer": isEligibleForIntroOffer
        ]
        if let offer = subscription.introductoryOffer {
            let mappedOffer: [String: Any] = [
                "paymentMode": paymentMode(offer.paymentMode),
                "price": decimalToDouble(offer.price),
                "periodIso": isoDuration(offer.period),
                "periodCount": offer.periodCount
            ]
            mappedSubscription["introductoryOffer"] = mappedOffer
        }
        item["subscription"] = mappedSubscription
    }
    return item
}

private func productType(_ type: Product.ProductType) -> String {
    switch type {
    case .consumable: return "consumable"
    case .nonConsumable: return "nonConsumable"
    case .autoRenewable: return "autoRenewable"
    case .nonRenewable: return "nonRenewable"
    default: return type.rawValue
    }
}

private func paymentMode(_ mode: Product.SubscriptionOffer.PaymentMode) -> String {
    switch mode {
    case .freeTrial: return "freeTrial"
    case .payAsYouGo: return "payAsYouGo"
    case .payUpFront: return "payUpFront"
    default: return mode.rawValue
    }
}

// NSDecimalNumber.doubleValue is lossy (46.99 becomes 46.989999999999995 — it multiplies the
// mantissa out by powers of ten), and that noise rides the JSON all the way into the price UI.
// Round-tripping through Decimal's canonical string yields the nearest double, which formats
// back to the exact store price.
private func decimalToDouble(_ value: Decimal) -> Double {
    Double("\(value)") ?? NSDecimalNumber(decimal: value).doubleValue
}

private func isoDuration(_ period: Product.SubscriptionPeriod) -> String {
    switch period.unit {
    case .day: return "P\(period.value)D"
    case .week: return "P\(period.value)W"
    case .month: return "P\(period.value)M"
    case .year: return "P\(period.value)Y"
    @unknown default: return "P\(period.value)D"
    }
}

// ------------------------------------------------------------ transactions --

// StoreKit has verified the JWS on the device; a server that receives it verifies it again itself.
private func mapTransaction(_ verification: VerificationResult<Transaction>) throws -> [String: Any] {
    let transaction = try checked(verification)
    var item: [String: Any] = [
        "id": String(transaction.id),
        "originalId": String(transaction.originalID),
        "productId": transaction.productID,
        "purchaseDate": transaction.purchaseDate.ISO8601Format(),
        "jws": verification.jwsRepresentation
    ]
    if let expirationDate = transaction.expirationDate {
        item["expirationDate"] = expirationDate.ISO8601Format()
    }
    return item
}

// ---------------------------------------------------------------- purchase --

// The account token is optional, as StoreKit's own option is. The transaction is left unfinished:
// StoreKit keeps one until the app has delivered the purchase, so the caller finishes it with
// vhsk_finish_transaction once it has.
@_cdecl("vhsk_purchase")
public func vhsk_purchase(
    _ productIdC: UnsafePointer<CChar>,
    _ appAccountTokenC: UnsafePointer<CChar>?,
    _ context: UnsafeMutableRawPointer?,
    _ callback: @escaping VhskCallback
) {
    let productId = String(cString: productIdC)
    let appAccountToken = appAccountTokenC.map { String(cString: $0) }
    Task {
        do {
            var options: Set<Product.PurchaseOption> = []
            if let appAccountToken {
                guard let uuid = UUID(uuidString: appAccountToken) else {
                    throw NSError(domain: "vhsk", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "appAccountToken is not a UUID"])
                }
                options.insert(.appAccountToken(uuid))
            }
            guard let product = try await Product.products(for: [productId]).first else {
                throw NSError(domain: "vhsk", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "unknown product: \(productId)"])
            }

            let result = try await product.purchase(options: options)
            switch result {
            case .success(let verification):
                let payload: [String: Any] = [
                    "state": "purchased",
                    "transaction": try mapTransaction(verification)
                ]
                let json = try JSONSerialization.data(withJSONObject: payload)
                complete(context, callback, ok: true, String(data: json, encoding: .utf8) ?? "{}")
            case .pending:
                complete(context, callback, ok: true, #"{"state":"pending"}"#)
            case .userCancelled:
                complete(context, callback, ok: true, #"{"state":"cancelled"}"#)
            @unknown default:
                complete(context, callback, ok: true, #"{"state":"pending"}"#)
            }
        } catch {
            completeError(context, callback, error)
        }
    }
}

// ------------------------------------------------------------ entitlements --

// Every current entitlement: the latest transaction of each product the user owns.
@_cdecl("vhsk_current_entitlements")
public func vhsk_current_entitlements(
    _ context: UnsafeMutableRawPointer?,
    _ callback: @escaping VhskCallback
) {
    Task {
        do {
            var mapped: [[String: Any]] = []
            for await verification in Transaction.currentEntitlements {
                mapped.append(try mapTransaction(verification))
            }
            let json = try JSONSerialization.data(withJSONObject: mapped)
            complete(context, callback, ok: true, String(data: json, encoding: .utf8) ?? "[]")
        } catch {
            completeError(context, callback, error)
        }
    }
}

// ------------------------------------------------------------------ finish --

// Finishes the transaction with this id while it is unfinished, answering true; false when none
// is (finished already, or never this device's), so finishing twice is harmless. The caller has
// decided it is delivered, so it is finished whatever the device's own verification said.
@_cdecl("vhsk_finish_transaction")
public func vhsk_finish_transaction(
    _ transactionIdC: UnsafePointer<CChar>,
    _ context: UnsafeMutableRawPointer?,
    _ callback: @escaping VhskCallback
) {
    let transactionIdText = String(cString: transactionIdC)
    Task {
        do {
            guard let transactionId = UInt64(transactionIdText) else {
                throw NSError(domain: "vhsk", code: 5,
                              userInfo: [NSLocalizedDescriptionKey: "not a transaction id: \(transactionIdText)"])
            }
            for await verification in Transaction.unfinished {
                let transaction = verification.unsafePayloadValue
                if transaction.id == transactionId {
                    await transaction.finish()
                    complete(context, callback, ok: true, "true")
                    return
                }
            }
            complete(context, callback, ok: true, "false")
        } catch {
            completeError(context, callback, error)
        }
    }
}

// ------------------------------------------------------- manage subscriptions --

// Apple's own manage-subscriptions sheet, presented INSIDE the app: no browser, no
// switch to the App Store. Returns once the sheet is dismissed. In the sandbox the
// sheet is empty (StoreKit testing has no real subscriptions) — that is an
// environment limit, not a failure, so it still completes successfully.
// iOS alone: StoreKit has no such sheet on tvOS, whose Settings manage subscriptions,
// so the tvOS slices export no such function.
#if os(iOS)
@_cdecl("vhsk_show_manage_subscriptions")
public func vhsk_show_manage_subscriptions(
    _ context: UnsafeMutableRawPointer?,
    _ callback: @escaping VhskCallback
) {
    Task { @MainActor in
        do {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            guard let scene = scenes.first(where: { $0.activationState == .foregroundActive })
                    ?? scenes.first else {
                throw NSError(domain: "vhsk", code: 4,
                              userInfo: [NSLocalizedDescriptionKey: "no window scene to present in"])
            }
            try await AppStore.showManageSubscriptions(in: scene)
            complete(context, callback, ok: true, "null")
        } catch {
            completeError(context, callback, error)
        }
    }
}
#endif

private func checked<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .verified(let value): return value
    case .unverified(_, let error): throw error
    }
}
