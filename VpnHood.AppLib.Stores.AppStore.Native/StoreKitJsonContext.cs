using System.Text.Json.Serialization;

namespace VpnHood.AppLib.Stores.AppStore.Native;

/// <summary>
/// Source-generated JSON contract for the Swift facade's payloads. Matches the reflection
/// "Web" defaults the facade was written against (camelCase, case-insensitive, numbers from
/// strings) while staying fully trim/AOT safe — no IL2026, nothing for the trimmer to break.
/// </summary>
[JsonSourceGenerationOptions(
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    PropertyNameCaseInsensitive = true,
    NumberHandling = JsonNumberHandling.AllowReadingFromString)]
[JsonSerializable(typeof(IReadOnlyList<string>))]
[JsonSerializable(typeof(List<StoreKitProduct>))]
[JsonSerializable(typeof(StoreKitPurchase))]
internal partial class StoreKitJsonContext : JsonSerializerContext;
