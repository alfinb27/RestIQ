//
//  PurchaseManager.swift
//  RestIQ
//
//  StoreKit 2 purchase manager for the Expert level one-time unlock.
//
//  TO ACTIVATE:
//  1. In App Store Connect, create a Non-Consumable IAP with the product ID below.
//  2. Add a StoreKit configuration file to your Xcode project for local testing.
//  3. Replace `expertUnlockProductID` with your real product ID.
//  4. Remove the `#if DEBUG` stub and the `isStubbed` flag once your product is live.
//
//  Android mirror: use Google Play Billing Library 6+ with the same product ID string.
//

import StoreKit

@MainActor
final class PurchaseManager {
    static let shared = PurchaseManager()

    // MARK: - Config
    // Replace with your real App Store Connect product ID before submitting.
    static let expertUnlockProductID = "com.alfin.restiq.expert_unlock"

    // MARK: - State
    private(set) var expertProduct: Product? = nil
    private(set) var isPurchasing = false
    private(set) var purchaseError: String? = nil

    private var transactionListenerTask: Task<Void, Never>? = nil

    private init() {
        transactionListenerTask = listenForTransactions()
        Task { await loadProducts() }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.expertUnlockProductID])
            expertProduct = products.first
        } catch {
            // Product not found — likely running without a StoreKit config file.
            // This is expected in Simulator without a .storekit file.
            print("[PurchaseManager] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchaseExpert() async {
        guard let product = expertProduct else {
            // Stub fallback: in debug/simulator with no StoreKit config, grant directly.
            #if DEBUG
            UserStatsManager.shared.unlockExpert()
            #endif
            return
        }

        isPurchasing = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                UserStatsManager.shared.unlockExpert()
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                // Transaction pending external approval (e.g. Ask to Buy)
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed. Please try again."
            print("[PurchaseManager] Purchase error: \(error)")
        }

        isPurchasing = false
    }

    // MARK: - Restore

    func restorePurchases() async {
        isPurchasing = true
        purchaseError = nil

        do {
            try await AppStore.sync()
            await checkCurrentEntitlements()
        } catch {
            purchaseError = "Restore failed. Please try again."
            print("[PurchaseManager] Restore error: \(error)")
        }

        isPurchasing = false
    }

    // MARK: - Transaction Listener
    // Handles transactions that complete outside the app (e.g. Ask to Buy approval, refunds).

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached(priority: .background) {
            for await result in Transaction.updates {
                do {
                    let transaction = try await MainActor.run { [self] in
                        try self.checkVerified(result)
                    }
                    await MainActor.run {
                        UserStatsManager.shared.unlockExpert()
                    }
                    await transaction.finish()
                } catch {
                    print("[PurchaseManager] Unverified transaction: \(error)")
                }
            }
        }
    }

    // MARK: - Entitlement Check
    // Call on app launch to restore state without requiring user action.

    func checkCurrentEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.expertUnlockProductID,
               transaction.revocationDate == nil {
                UserStatsManager.shared.restoreExpertUnlock()
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    // MARK: - Formatted Price

    var expertPriceFormatted: String {
        expertProduct?.displayPrice ?? "$0.99"
    }
}
