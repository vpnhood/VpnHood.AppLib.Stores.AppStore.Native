namespace VpnHood.AppLib.Stores.AppStore.Native;

/// <summary>A subscription offer, as StoreKit 2 reports it.</summary>
public class StoreKitOffer
{
    public const string PaymentModeFreeTrial = "freeTrial";
    public const string PaymentModePayAsYouGo = "payAsYouGo";
    public const string PaymentModePayUpFront = "payUpFront";

    /// <summary>One of the PaymentMode constants.</summary>
    public required string PaymentMode { get; init; }

    /// <summary>
    /// Decimal price in the store currency: per period when paid as you go, for all of them when
    /// paid up front, zero for a free trial.
    /// </summary>
    public required double Price { get; init; }

    /// <summary>ISO 8601 duration of one of the offer's periods, e.g. "P1W".</summary>
    public required string PeriodIso { get; init; }

    public required int PeriodCount { get; init; }
}
