import Testing
@testable import Core

@Suite("Currency.find(byAlias:)")
struct CurrencyAliasTests {

    @Test("ISO code matches exactly (case-insensitive)")
    func isoCodeMatch() {
        #expect(Currency.find(byAlias: "USD")?.id == "USD")
        #expect(Currency.find(byAlias: "usd")?.id == "USD")
        #expect(Currency.find(byAlias: "  RUB  ")?.id == "RUB")
        #expect(Currency.find(byAlias: "EUR")?.id == "EUR")
    }

    @Test("English aliases resolve to expected currency")
    func englishAliases() {
        #expect(Currency.find(byAlias: "dollars")?.id == "USD")
        #expect(Currency.find(byAlias: "bucks")?.id == "USD")
        #expect(Currency.find(byAlias: "euros")?.id == "EUR")
        #expect(Currency.find(byAlias: "pounds")?.id == "GBP")
        #expect(Currency.find(byAlias: "quid")?.id == "GBP")
        #expect(Currency.find(byAlias: "yen")?.id == "JPY")
        #expect(Currency.find(byAlias: "dirhams")?.id == "AED")
        #expect(Currency.find(byAlias: "rubles")?.id == "RUB")
        #expect(Currency.find(byAlias: "roubles")?.id == "RUB")
    }

    @Test("Russian aliases resolve to expected currency")
    func russianAliases() {
        #expect(Currency.find(byAlias: "рубли")?.id == "RUB")
        #expect(Currency.find(byAlias: "рубль")?.id == "RUB")
        #expect(Currency.find(byAlias: "доллары")?.id == "USD")
        #expect(Currency.find(byAlias: "баксы")?.id == "USD")
        #expect(Currency.find(byAlias: "евро")?.id == "EUR")
        #expect(Currency.find(byAlias: "дирхамы")?.id == "AED")
        #expect(Currency.find(byAlias: "юань")?.id == "CNY")
    }

    @Test("Arabic aliases resolve to expected currency")
    func arabicAliases() {
        #expect(Currency.find(byAlias: "درهم")?.id == "AED")
        #expect(Currency.find(byAlias: "ريال سعودي")?.id == "SAR")
        #expect(Currency.find(byAlias: "دولار")?.id == "USD")
        #expect(Currency.find(byAlias: "يورو")?.id == "EUR")
        #expect(Currency.find(byAlias: "روبل")?.id == "RUB")
    }

    @Test("Currency symbols resolve where unambiguous")
    func currencySymbols() {
        #expect(Currency.find(byAlias: "€")?.id == "EUR")
        #expect(Currency.find(byAlias: "£")?.id == "GBP")
        #expect(Currency.find(byAlias: "₽")?.id == "RUB")
        #expect(Currency.find(byAlias: "₹")?.id == "INR")
        #expect(Currency.find(byAlias: "₩")?.id == "KRW")
    }

    @Test("Empty / whitespace / unknown returns nil")
    func nilCases() {
        #expect(Currency.find(byAlias: "") == nil)
        #expect(Currency.find(byAlias: "   ") == nil)
        #expect(Currency.find(byAlias: "xyz") == nil)
        #expect(Currency.find(byAlias: "klingon credits") == nil)
    }

    @Test("Ambiguous '$' falls through (no match)")
    func ambiguousDollarSign() {
        #expect(Currency.find(byAlias: "$") == nil)
    }

    @Test("Plain 'peso' biases to MXN (most common)")
    func pesoBias() {
        #expect(Currency.find(byAlias: "peso")?.id == "MXN")
        #expect(Currency.find(byAlias: "pesos")?.id == "MXN")
    }

    @Test("Plain 'dollar' biases to USD")
    func dollarBias() {
        #expect(Currency.find(byAlias: "dollar")?.id == "USD")
        #expect(Currency.find(byAlias: "dollars")?.id == "USD")
    }

    @Test("Plain 'rial' biases to SAR (largest economy among rial users)")
    func rialBias() {
        #expect(Currency.find(byAlias: "riyal")?.id == "SAR")
        #expect(Currency.find(byAlias: "ريال")?.id == "SAR")
    }

    @Test("All currencies have non-empty aliases")
    func aliasesPopulated() {
        for currency in Currency.allCurrencies {
            #expect(!currency.aliases.isEmpty, "Currency \(currency.id) has no aliases")
        }
    }

    @Test("All aliases are lowercased after init")
    func aliasesLowercased() {
        for currency in Currency.allCurrencies {
            for alias in currency.aliases {
                #expect(alias == alias.lowercased(), "Alias '\(alias)' on \(currency.id) is not lowercased")
            }
        }
    }

    @Test("First alias hit wins (no duplicate ambiguity)")
    func noAmbiguousAliases() {
        // Each alias should map to exactly one currency.
        var seen: [String: String] = [:]
        for currency in Currency.allCurrencies {
            for alias in currency.aliases {
                if let existing = seen[alias] {
                    Issue.record("Alias '\(alias)' duplicated on \(existing) and \(currency.id)")
                }
                seen[alias] = currency.id
            }
        }
    }
}
