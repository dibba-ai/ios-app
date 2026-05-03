import Core
import Servicing

/// Resolves a spoken currency term to an ISO 4217 code.
///
/// Lookup order:
/// 1. If `term` matches a known alias (or ISO code), use that.
/// 2. Else fall back to the user's profile currency.
/// 3. Else `"USD"`.
enum CurrencyResolver {
    static func resolve(term: String?) async -> String {
        if let term = term?.nilIfEmpty, let hit = Currency.find(byAlias: term) {
            return hit.id
        }
        let cachedCurrency = await Services.profile.cachedProfile?.currency?.nilIfEmpty
        return cachedCurrency ?? "USD"
    }
}
