// Required placeholder for the binding project (see the csproj comment): there is no
// Objective-C API to bind — the facade exposes plain C functions consumed via DllImport
// in NativeStoreKitBridge.cs. IsBindingProject=true is only used so `dotnet pack` embeds
// the xcframework into the NuGet.
