namespace VpnHood.AppLib.Stores.AppStore.Native;

/// <summary>An auto-renewable subscription's terms, as StoreKit 2 reports them.</summary>
public class StoreKitSubscription
{
    /// <summary>ISO 8601 duration of the billing period, e.g. "P1M".</summary>
    public required string PeriodIso { get; init; }

    /// <summary>The product's introductory offer, whether or not this user may still take it.</summary>
    public StoreKitOffer? IntroductoryOffer { get; init; }

    /// <summary>Whether this user may still take the subscription group's introductory offer.</summary>
    public required bool IsEligibleForIntroOffer { get; init; }
}
