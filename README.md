# VpnHood.AppLib.StoreKit.IosNative

StoreKit 2 for .NET iOS, self-contained in one NuGet:

- **`VpnHoodStoreKit.xcframework`** — a tiny Swift facade exposing StoreKit 2's
  Swift-async API over a C ABI (`@_cdecl` functions + JSON strings + one
  completion callback). Prebuilt and committed, so consumers never need a Swift
  toolchain.
- **The C# binding** — `NativeStoreKitBridge` (P/Invoke over `__Internal`),
  the `IStoreKitBridge` interface, and the `StoreKitProduct` /
  `StoreKitPurchase` DTOs.

The two sides are a matched pair: change the contract in both or not at all.
That is why they live in the same repository and ship as one atomically
versioned package.

| C function | StoreKit 2 |
| --- | --- |
| `vhsk_load_products` | `Product.products(for:)` + intro-offer eligibility |
| `vhsk_purchase` | `product.purchase(options: [.appAccountToken(uuid)])` |
| `vhsk_current_entitlement` | `Transaction.currentEntitlements` (newest) |
| `vhsk_show_manage_subscriptions` | `AppStore.showManageSubscriptions(in: scene)` |

## Why a facade?

Microsoft.iOS does not bind StoreKit 2's Swift-async API. This package is the
documented seam: plain C functions taking/returning JSON, completion via a C
callback, statically linked into the app binary (`DllImport "__Internal"`).

## Usage

```xml
<PackageReference Include="VpnHood.AppLib.StoreKit.IosNative" Version="x.y.z" />
```

```csharp
IStoreKitBridge bridge = new NativeStoreKitBridge();
var products = await bridge.LoadProducts(["my.product.id"], cancellationToken);
```

The xcframework is embedded in the NuGet and linked into the main executable
automatically; no `NativeReference` is needed in the consuming project.
Requires `net11.0-ios`, minimum OS version 15.0.

## Building

Day-to-day (C#-only changes) needs no Mac — the xcframework is committed.

Rebuilding the native facade (only when `StoreKitBridge.swift` changes) needs a
Mac with Xcode 15+, or the `build-xcframework` GitHub workflow:

```bash
cd VpnHood.AppLib.StoreKit.IosNative/swift && ./build-xcframework.sh
```

See [swift/README.md](VpnHood.AppLib.StoreKit.IosNative/swift/README.md) for
design notes.

## Publishing

Every push to `main` bumps `pub/PubVersion.json`, packs, and publishes to
nuget.org (`.github/workflows/publish-nuget.yml`). Consumers pin an exact
version and upgrade deliberately — the package intentionally changes rarely.

## License

[LGPL-2.1](LICENSE)
