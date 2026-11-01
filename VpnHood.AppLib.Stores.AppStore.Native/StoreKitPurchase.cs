namespace VpnHood.AppLib.Stores.AppStore.Native;

/// <summary>The outcome of a StoreKit 2 purchase.</summary>
public class StoreKitPurchase
{
    public const string StatePurchased = "purchased";
    public const string StatePending = "pending";
    public const string StateCancelled = "cancelled";

    public required string State { get; init; }

    /// <summary>
    /// The new transaction when <see cref="State" /> is purchased. It stays unfinished until
    /// <see cref="IStoreKitBridge.FinishTransaction" />.
    /// </summary>
    public StoreKitTransaction? Transaction { get; init; }
}
