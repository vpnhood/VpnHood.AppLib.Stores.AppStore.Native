# VpnHoodStoreKit — the StoreKit 2 Swift facade

Microsoft.iOS does not bind StoreKit 2's Swift-async API, so this tiny Swift
package exposes exactly the four calls the C# side needs over a **C ABI**
(`@_cdecl` functions + JSON strings + one completion callback):

| C function | StoreKit 2 |
| --- | --- |
| `vhsk_load_products` | `Product.products(for:)` + intro-offer eligibility |
| `vhsk_purchase` | `product.purchase(options: [.appAccountToken(uuid)])` |
| `vhsk_current_entitlement` | `Transaction.currentEntitlements` (newest) |
| `vhsk_show_manage_subscriptions` | `AppStore.showManageSubscriptions(in: scene)` |

The C# binding lives in `../NativeStoreKitBridge.cs`; the two
files are a matched pair — change the contract in both or not at all.

## Building

On a Mac with Xcode 15+:

```bash
./build-xcframework.sh
```

This produces `swift/VpnHoodStoreKit.xcframework`, which the csproj references
as a `NativeReference` — check the built xcframework in, so packing and
consumer builds never need a Swift toolchain. The reference is unconditional:
a missing xcframework fails the pack instead of shipping a package that throws
at runtime. The `build-xcframework` GitHub workflow (manual dispatch, macOS
runner) runs this script and commits the result.

## Design notes

- `transaction.finish()` is called immediately after a successful purchase:
  with the portal flow, delivery acknowledgment happens SERVER-side
  (POST /billing/purchases re-fetches the transaction from Apple), so an unfinished
  transaction would only cause repeated `updates` replays on the device.
- Purchases carry `appAccountToken` = the portal's external uid (a UUID), the
  same value Google receives as `obfuscatedAccountId` — the backend owns that
  mapping.
- Only auto-renewable subscriptions are mapped by `vhsk_load_products`;
  one-time products can be added to the same seam when Windows/consumables
  land.
