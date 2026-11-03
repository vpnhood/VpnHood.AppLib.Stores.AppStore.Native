# VpnHoodStoreKit — the StoreKit 2 Swift facade

Microsoft.iOS and Microsoft.tvOS do not bind StoreKit 2's Swift-async API, so
this tiny Swift package exposes the five calls the C# side needs (four on tvOS)
over a **C ABI** (`@_cdecl` functions + JSON strings + one completion callback):

| C function | StoreKit 2 |
| --- | --- |
| `vhsk_load_products` | `Product.products(for:)`, every type, with each subscription's introductory offer and eligibility |
| `vhsk_purchase` | `product.purchase(options:)`, the account token optional; the transaction is left unfinished |
| `vhsk_current_entitlements` | `Transaction.currentEntitlements`, all of them |
| `vhsk_finish_transaction` | `transaction.finish()` for the unfinished transaction with that id |
| `vhsk_show_manage_subscriptions` | `AppStore.showManageSubscriptions(in: scene)`; iOS alone, as tvOS has no such sheet |

The C# binding lives in `../NativeStoreKitBridge.cs`; the two
files are a matched pair — change the contract in both or not at all.

## Building

On a Mac with Xcode 15+:

```bash
./build-xcframework.sh
```

This produces `swift/VpnHoodStoreKit.xcframework`, with slices for iOS, the iOS
simulator, tvOS and the tvOS simulator, which the csproj references
as a `NativeReference` — check the built xcframework in, so packing and
consumer builds never need a Swift toolchain. The reference is unconditional:
a missing xcframework fails the pack instead of shipping a package that throws
at runtime. The `build-xcframework` GitHub workflow (manual dispatch, macOS
runner) runs this script and commits the result.

## Design notes

- The facade mirrors StoreKit and decides nothing: every product type, the raw
  introductory offer beside the user's eligibility for it, every current
  entitlement. An app's rules live in its own C#, so changing them never needs
  this binary rebuilt.
- A purchased transaction is left unfinished, as Apple asks until the purchase
  is delivered; the caller finishes it with `vhsk_finish_transaction`. Until
  then StoreKit keeps it in `Transaction.unfinished` and replays it in
  `Transaction.updates`; a subscription is in `currentEntitlements` either way.
- Only verified transactions cross: an unverified one fails the purchase or the
  entitlement call. A server holding the JWS verifies it again itself.
