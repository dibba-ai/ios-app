// MARK: - Paywall Module
//
// Wrapper around the RevenueCat SDK + RevenueCatUI. The only place in the app
// that imports `RevenueCat` / `RevenueCatUI` directly. Other modules talk to
// `PaywallServicing` and use `PaywallContainer` / `PaywallFlow` for UI.
//
// Multiple paywall variations are supported by referring to RevenueCat
// "offering" identifiers configured on the dashboard (e.g. "default",
// "winter_sale", "premium_only"). Pass an identifier to `PaywallFlow` /
// `PaywallContainer`; pass `nil` to use the offering marked Current on the
// dashboard.
//
// Setup checklist (see SETUP.md or the project README):
// 1. RevenueCat dashboard → create app, products, entitlements, offerings.
// 2. Add the public iOS API key as `RevenueCatPublicAPIKey` in Info.plist.
// 3. Call `paywallService.configure(apiKey:)` once at app launch.
// 4. Call `paywallService.identify(userId:)` after Auth0 sign-in,
//    `paywallService.logout()` on sign-out.
