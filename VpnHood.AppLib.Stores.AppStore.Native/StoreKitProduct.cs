namespace VpnHood.AppLib.Stores.AppStore.Native;

/// <summary>A product as StoreKit 2 reports it, of any type.</summary>
public class StoreKitProduct
{
    public const string TypeConsumable = "consumable";
    public const string TypeNonConsumable = "nonConsumable";
    public const string TypeAutoRenewable = "autoRenewable";
    public const string TypeNonRenewable = "nonRenewable";

    public required string Id { get; init; }

    /// <summary>One of the Type constants.</summary>
    public required string Type { get; init; }

    /// <summary>Decimal price in the store currency; for a subscription, the recurring one, without any offer.</summary>
    public required double Price { get; init; }

    public required string CurrencyCode { get; init; }
    public required string CurrencySymbol { get; init; }

    /// <summary>Present for an auto-renewable subscription only.</summary>
    public StoreKitSubscription? Subscription { get; init; }
}
