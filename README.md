# VpnHood.AppLib.Stores.AppStore.Native

Formerly `VpnHood.AppLib.Ios.StoreKitNative`: the id and the namespace changed in 2026-09 so that no
VpnHood package id starts with an OS. The namespace is the package id.

StoreKit 2 for .NET iOS and tvOS, self-contained in one NuGet:

- **`VpnHoodStoreKit.xcframework`** — a tiny Swift facade exposing StoreKit 2's
  Swift-async API over a C ABI (`@_cdecl` functions + JSON strings + one
  completion callback). Prebuilt and committed, so consumers never need a Swift
  toolchain.
- **The C# binding** — `NativeStoreKitBridge` (P/Invoke over `__Internal`),
  the `IStoreKitBridge` interface, and its DTOs (`StoreKitProduct`,
  `StoreKitSubscription`, `StoreKitOffer`, `StoreKitPurchase`,
  `StoreKitTransaction`).

The two sides are a matched pair: change the contract in both or not at all.
That is why they live in the same repository and ship as one atomically
versioned package.

It mirrors StoreKit and decides nothing for the app: which products it sells,
what an introductory offer makes the first price, which entitlement counts and
when a purchase is delivered are the caller's.

| C function | StoreKit 2 |
| --- | --- |
| `vhsk_load_products` | `Product.products(for:)`, every type, with each subscription's introductory offer and eligibility |
| `vhsk_purchase` | `product.purchase(options:)`, the account token optional; the transaction is left unfinished |
| `vhsk_current_entitlements` | `Transaction.currentEntitlements`, all of them |
| `vhsk_finish_transaction` | `transaction.finish()` for the unfinished transaction with that id |
| `vhsk_show_manage_subscriptions` | `AppStore.showManageSubscriptions(in: scene)`; iOS alone, as tvOS has no such sheet |

## Why a facade?

Microsoft.iOS and Microsoft.tvOS do not bind StoreKit 2's Swift-async API. This package is the
documented seam: plain C functions taking/returning JSON, completion via a C
callback, statically linked into the app binary (`DllImport "__Internal"`).

## Usage

```xml
<PackageReference Include="VpnHood.AppLib.Stores.AppStore.Native" Version="x.y.z" />
```

```csharp
IStoreKitBridge bridge = new NativeStoreKitBridge();
var products = await bridge.LoadProducts(["my.product.id"], cancellationToken);
var purchase = await bridge.Purchase("my.product.id", appAccountToken: null, cancellationToken);
if (purchase.Transaction != null) {
    // deliver it first (say, your server verifies purchase.Transaction.Jws), then:
    await bridge.FinishTransaction(purchase.Transaction.Id, cancellationToken);
}
```

The xcframework, with its iOS and tvOS slices, is embedded in the NuGet, and an
app links its own platform's slice into the main executable automatically; no
`NativeReference` is needed in the consuming project. Requires `net11.0-ios` or
`net11.0-tvos`, minimum OS version 15.0. On tvOS, `ShowManageSubscriptions`
throws `PlatformNotSupportedException` and is marked
`[UnsupportedOSPlatform("tvos")]`: tvOS has no such sheet, the TV's Settings
manage subscriptions.

## Building

Day-to-day (C#-only changes) needs no Mac, only the `ios` and `tvos` workloads:
the xcframework is committed.

Rebuilding the native facade (only when `StoreKitBridge.swift` changes) needs a
Mac with Xcode 15+, or the `build-xcframework` GitHub workflow:

```bash
cd VpnHood.AppLib.Stores.AppStore.Native/swift && ./build-xcframework.sh
```

See [swift/README.md](https://github.com/vpnhood/VpnHood.AppLib.Stores.AppStore.Native/blob/main/VpnHood.AppLib.Stores.AppStore.Native/swift/README.md) for
design notes.

## Publishing

Every push to `main` bumps `pub/PubVersion.json`, packs, and publishes to
nuget.org (`.github/workflows/publish-nuget.yml`). Consumers pin an exact
version and upgrade deliberately — the package intentionally changes rarely.

## License

[LGPL-2.1](https://github.com/vpnhood/VpnHood.AppLib.Stores.AppStore.Native/blob/main/LICENSE)
