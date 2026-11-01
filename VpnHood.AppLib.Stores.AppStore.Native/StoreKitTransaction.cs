namespace VpnHood.AppLib.Stores.AppStore.Native;

/// <summary>A transaction StoreKit 2 has verified on the device.</summary>
public class StoreKitTransaction
{
    public required string Id { get; init; }

    /// <summary>The id of the first transaction of its subscription's renewals; its own id otherwise.</summary>
    public required string OriginalId { get; init; }

    public required string ProductId { get; init; }
    public required DateTime PurchaseDate { get; init; }

    /// <summary>When the subscription period it bought ends; null for other products.</summary>
    public DateTime? ExpirationDate { get; init; }

    /// <summary>The signed transaction (JWS): what a server verifies again with Apple's keys.</summary>
    public required string Jws { get; init; }
}
