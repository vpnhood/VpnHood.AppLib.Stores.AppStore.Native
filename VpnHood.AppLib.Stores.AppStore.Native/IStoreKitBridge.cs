namespace VpnHood.AppLib.Stores.AppStore.Native;

/// <summary>
/// StoreKit 2 as it is, as a seam: the native implementation crosses into the VpnHoodStoreKit
/// Swift facade; tests can substitute a fake without any Swift. It decides nothing for the app —
/// which products to sell, what an offer makes the first price, which entitlement counts and when
/// a purchase is delivered are the caller's.
/// </summary>
public interface IStoreKitBridge
{
    /// <summary>The products among these ids that StoreKit knows, of every type; an unknown id is left out.</summary>
    Task<IReadOnlyList<StoreKitProduct>> LoadProducts(IReadOnlyList<string> productIds,
        CancellationToken cancellationToken);

    /// <summary>
    /// Runs the purchase flow. appAccountToken, when given, becomes Apple's per-purchase account
    /// binding. A purchased transaction is left unfinished: call <see cref="FinishTransaction" /> once
    /// the purchase is delivered.
    /// </summary>
    Task<StoreKitPurchase> Purchase(string productId, Guid? appAccountToken, CancellationToken cancellationToken);

    /// <summary>Every current entitlement: the latest transaction of each product the user owns; empty when none.</summary>
    Task<IReadOnlyList<StoreKitTransaction>> CurrentEntitlements(CancellationToken cancellationToken);

    /// <summary>
    /// Tells StoreKit the purchase is delivered. True when the transaction was unfinished; false
    /// when it was not (finished already, or never this device's), so finishing twice is harmless.
    /// </summary>
    Task<bool> FinishTransaction(string transactionId, CancellationToken cancellationToken);

    /// <summary>
    /// Presents Apple's manage-subscriptions sheet inside the app and returns when it is
    /// dismissed. Nothing leaves the app: no browser, no switch to the App Store.
    /// </summary>
    Task ShowManageSubscriptions(CancellationToken cancellationToken);
}
