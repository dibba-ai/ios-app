//
//  Currency.swift
//  Core
//
//  Created by Klim on 10/11/25.
//
import Foundation

public struct Currency: Identifiable, Codable, Sendable, Equatable, Hashable {
    public var id: String
    public var label: String
    public var emoji: String
    public var continent: String
    public var timezones: [String]
    public var aliases: [String]

    public init(
        id: String,
        label: String,
        emoji: String,
        continent: String,
        timezones: [String],
        aliases: [String] = []
    ) {
        self.id = id
        self.label = label
        self.emoji = emoji
        self.continent = continent
        self.timezones = timezones
        self.aliases = aliases.map { $0.lowercased() }
    }

    public var displayLabel: String {
        "\(emoji) \(label)"
    }

    public static func find(by id: String?) -> Currency? {
        guard let id else { return nil }
        return allCurrencies.first { $0.id == id }
    }

    /// Match a free-form term (spoken word, ISO code, localized name) to a supported currency.
    /// Lowercased + trimmed before lookup. ISO code matched first, then aliases.
    public static func find(byAlias term: String) -> Currency? {
        let needle = term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        if let exact = allCurrencies.first(where: { $0.id.lowercased() == needle }) {
            return exact
        }
        return allCurrencies.first { $0.aliases.contains(needle) }
    }
}

// MARK: - All Supported Currencies

public extension Currency {
    static let allCurrencies: [Currency] = [
        // North America
        Currency(id: "USD", label: "US Dollars", emoji: "🇺🇸", continent: "North America", timezones: [
            "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles",
            "America/Phoenix", "America/Anchorage", "Pacific/Honolulu", "America/Detroit",
            "America/Indianapolis", "America/Louisville", "America/Menominee"
        ], aliases: [
            "dollar", "dollars", "usd", "buck", "bucks", "us dollar", "us dollars", "american dollar", "american dollars",
            "доллар", "доллары", "долларов", "бакс", "баксы", "усд", "американский доллар",
            "دولار", "دولارات", "دولار أمريكي",
        ]),
        Currency(id: "CAD", label: "Canadian Dollars", emoji: "🇨🇦", continent: "North America", timezones: [
            "America/Toronto", "America/Vancouver", "America/Montreal", "America/Calgary",
            "America/Edmonton", "America/Winnipeg", "America/Halifax", "America/St_Johns"
        ], aliases: [
            "canadian dollar", "canadian dollars", "cad", "loonie",
            "канадский доллар", "канадские доллары", "кад",
            "دولار كندي",
        ]),
        Currency(id: "MXN", label: "Mexican Pesos", emoji: "🇲🇽", continent: "North America", timezones: [
            "America/Mexico_City", "America/Cancun", "America/Merida", "America/Monterrey",
            "America/Mazatlan", "America/Chihuahua", "America/Tijuana"
        ], aliases: [
            "peso", "pesos", "mexican peso", "mexican pesos", "mxn",
            "песо", "мексиканский песо", "мексиканские песо", "мхн",
            "بيسو", "بيسو مكسيكي",
        ]),

        // South America
        Currency(id: "BRL", label: "Brazilian Real", emoji: "🇧🇷", continent: "South America", timezones: [
            "America/Sao_Paulo", "America/Rio_Branco", "America/Manaus",
            "America/Fortaleza", "America/Recife", "America/Bahia"
        ], aliases: [
            "real", "reais", "brazilian real", "brl",
            "реал", "реалы", "бразильский реал", "брл",
            "ريال برازيلي",
        ]),
        Currency(id: "ARS", label: "Argentine Peso", emoji: "🇦🇷", continent: "South America", timezones: [
            "America/Argentina/Buenos_Aires", "America/Argentina/Cordoba", "America/Argentina/Mendoza"
        ], aliases: [
            "argentine peso", "argentine pesos", "argentinian peso", "ars",
            "аргентинский песо", "арс",
            "بيسو أرجنتيني",
        ]),
        Currency(id: "CLP", label: "Chilean Pesos", emoji: "🇨🇱", continent: "South America", timezones: ["America/Santiago"], aliases: [
            "chilean peso", "chilean pesos", "clp",
            "чилийский песо", "члп",
            "بيسو تشيلي",
        ]),
        Currency(id: "COP", label: "Colombian Peso", emoji: "🇨🇴", continent: "South America", timezones: ["America/Bogota"], aliases: [
            "colombian peso", "colombian pesos", "cop",
            "колумбийский песо", "коп",
            "بيسو كولومبي",
        ]),

        // Europe
        Currency(id: "EUR", label: "Euro", emoji: "🇪🇺", continent: "Europe", timezones: [
            "Europe/Berlin", "Europe/Paris", "Europe/Rome", "Europe/Madrid", "Europe/Amsterdam",
            "Europe/Brussels", "Europe/Vienna", "Europe/Prague", "Europe/Budapest", "Europe/Warsaw",
            "Europe/Helsinki", "Europe/Stockholm", "Europe/Copenhagen", "Europe/Oslo", "Europe/Zurich"
        ], aliases: [
            "euro", "euros", "eur", "€",
            "евро", "еур",
            "يورو",
        ]),
        Currency(id: "GBP", label: "British Pounds", emoji: "🇬🇧", continent: "Europe", timezones: [
            "Europe/London", "Europe/Belfast", "Europe/Dublin"
        ], aliases: [
            "pound", "pounds", "british pound", "british pounds", "sterling", "pound sterling", "gbp", "quid", "£",
            "фунт", "фунты", "фунтов", "фунт стерлингов", "британский фунт", "гбп",
            "جنيه", "جنيه إسترليني", "باوند",
        ]),
        Currency(id: "CHF", label: "Swiss Francs", emoji: "🇨🇭", continent: "Europe", timezones: ["Europe/Zurich"], aliases: [
            "franc", "francs", "swiss franc", "swiss francs", "chf",
            "франк", "франки", "франков", "швейцарский франк", "чхф",
            "فرنك", "فرنك سويسري",
        ]),
        Currency(id: "RUB", label: "Russian Rubles", emoji: "🇷🇺", continent: "Europe", timezones: [
            "Europe/Moscow", "Asia/Yekaterinburg", "Asia/Novosibirsk", "Asia/Krasnoyarsk",
            "Asia/Irkutsk", "Asia/Yakutsk", "Asia/Vladivostok", "Asia/Magadan", "Asia/Kamchatka"
        ], aliases: [
            "ruble", "rubles", "rouble", "roubles", "russian ruble", "russian rubles", "rub", "₽",
            "рубль", "рубли", "рублей", "руб", "российский рубль",
            "روبل", "روبل روسي",
        ]),
        Currency(id: "TRY", label: "Turkish Lira", emoji: "🇹🇷", continent: "Europe", timezones: ["Europe/Istanbul"], aliases: [
            "lira", "turkish lira", "try", "₺",
            "лира", "турецкая лира", "тры",
            "ليرة", "ليرة تركية",
        ]),
        Currency(id: "SEK", label: "Swedish Krona", emoji: "🇸🇪", continent: "Europe", timezones: ["Europe/Stockholm"], aliases: [
            "krona", "swedish krona", "sek",
            "шведская крона", "сек",
            "كرونة سويدية",
        ]),
        Currency(id: "NOK", label: "Norwegian Krone", emoji: "🇳🇴", continent: "Europe", timezones: ["Europe/Oslo"], aliases: [
            "krone", "norwegian krone", "nok",
            "норвежская крона", "нок",
            "كرونة نرويجية",
        ]),
        Currency(id: "DKK", label: "Danish Krone", emoji: "🇩🇰", continent: "Europe", timezones: ["Europe/Copenhagen"], aliases: [
            "danish krone", "dkk",
            "датская крона", "дкк",
            "كرونة دنماركية",
        ]),
        Currency(id: "PLN", label: "Polish Zloty", emoji: "🇵🇱", continent: "Europe", timezones: ["Europe/Warsaw"], aliases: [
            "zloty", "zlotys", "polish zloty", "pln",
            "злотый", "злотые", "злотых", "польский злотый", "плн",
            "زلوتي", "زلوتي بولندي",
        ]),
        Currency(id: "CZK", label: "Czech Koruna", emoji: "🇨🇿", continent: "Europe", timezones: ["Europe/Prague"], aliases: [
            "koruna", "czech koruna", "czk",
            "чешская крона", "крона чешская", "чзк",
            "كرونة تشيكية",
        ]),
        Currency(id: "HUF", label: "Hungarian Forint", emoji: "🇭🇺", continent: "Europe", timezones: ["Europe/Budapest"], aliases: [
            "forint", "forints", "hungarian forint", "huf",
            "форинт", "форинты", "форинтов", "венгерский форинт", "хуф",
            "فورنت", "فورنت مجري",
        ]),

        // Middle East
        Currency(id: "AED", label: "UAE Dirham", emoji: "🇦🇪", continent: "Middle East", timezones: ["Asia/Dubai"], aliases: [
            "dirham", "dirhams", "uae dirham", "emirati dirham", "aed",
            "дирхам", "дирхамы", "дирхамов", "оаэ дирхам", "аэд",
            "درهم", "درهم إماراتي", "درهم اماراتي",
        ]),
        Currency(id: "SAR", label: "Saudi Riyal", emoji: "🇸🇦", continent: "Middle East", timezones: ["Asia/Riyadh"], aliases: [
            "riyal", "saudi riyal", "sar",
            "риял", "саудовский риял", "сар",
            "ريال", "ريال سعودي",
        ]),
        Currency(id: "QAR", label: "Qatari Riyal", emoji: "🇶🇦", continent: "Middle East", timezones: ["Asia/Qatar"], aliases: [
            "qatari riyal", "qar",
            "катарский риал", "кар",
            "ريال قطري",
        ]),
        Currency(id: "KWD", label: "Kuwaiti Dinar", emoji: "🇰🇼", continent: "Middle East", timezones: ["Asia/Kuwait"], aliases: [
            "dinar", "dinars", "kuwaiti dinar", "kwd",
            "динар", "динары", "динаров", "кувейтский динар", "квд",
            "دينار", "دينار كويتي",
        ]),
        Currency(id: "OMR", label: "Omani Rial", emoji: "🇴🇲", continent: "Middle East", timezones: ["Asia/Muscat"], aliases: [
            "omani rial", "omr",
            "оманский риал", "омр",
            "ريال عماني",
        ]),

        // Asia
        Currency(id: "JPY", label: "Japanese Yen", emoji: "🇯🇵", continent: "Asia", timezones: ["Asia/Tokyo", "Asia/Osaka"], aliases: [
            "yen", "japanese yen", "jpy", "¥", "円",
            "иена", "йена", "иены", "йены", "иен", "йен", "японская иена", "японская йена", "жпы",
            "ين", "ين ياباني",
        ]),
        Currency(id: "CNY", label: "Chinese Yuan", emoji: "🇨🇳", continent: "Asia", timezones: [
            "Asia/Shanghai", "Asia/Beijing", "Asia/Chongqing", "Asia/Harbin", "Asia/Urumqi"
        ], aliases: [
            "yuan", "chinese yuan", "renminbi", "rmb", "cny", "元", "人民币",
            "юань", "юани", "юаней", "жэньминьби", "китайский юань", "кны",
            "يوان", "يوان صيني",
        ]),
        Currency(id: "INR", label: "Indian Rupees", emoji: "🇮🇳", continent: "Asia", timezones: ["Asia/Kolkata", "Asia/Mumbai", "Asia/Delhi"], aliases: [
            "rupee", "rupees", "indian rupee", "indian rupees", "inr", "₹",
            "рупия", "рупии", "рупий", "индийская рупия", "инр",
            "روبية", "روبية هندية",
        ]),
        Currency(id: "KRW", label: "South Korean Won", emoji: "🇰🇷", continent: "Asia", timezones: ["Asia/Seoul"], aliases: [
            "won", "korean won", "south korean won", "krw", "₩",
            "вона", "корейская вона", "крв",
            "وون", "وون كوري",
        ]),
        Currency(id: "SGD", label: "Singapore Dollars", emoji: "🇸🇬", continent: "Asia", timezones: ["Asia/Singapore"], aliases: [
            "singapore dollar", "singapore dollars", "sgd",
            "сингапурский доллар", "сгд",
            "دولار سنغافوري",
        ]),
        Currency(id: "HKD", label: "Hong Kong Dollars", emoji: "🇭🇰", continent: "Asia", timezones: ["Asia/Hong_Kong"], aliases: [
            "hong kong dollar", "hong kong dollars", "hkd",
            "гонконгский доллар", "хкд",
            "دولار هونغ كونغ",
        ]),
        Currency(id: "TWD", label: "New Taiwan Dollar", emoji: "🇹🇼", continent: "Asia", timezones: ["Asia/Taipei"], aliases: [
            "taiwan dollar", "new taiwan dollar", "twd",
            "тайваньский доллар", "твд",
            "دولار تايواني",
        ]),
        Currency(id: "MYR", label: "Malaysian Ringgit", emoji: "🇲🇾", continent: "Asia", timezones: ["Asia/Kuala_Lumpur"], aliases: [
            "ringgit", "malaysian ringgit", "myr",
            "ринггит", "малайзийский ринггит", "мыр",
            "رينغيت", "رينغيت ماليزي",
        ]),
        Currency(id: "THB", label: "Thai Baht", emoji: "🇹🇭", continent: "Asia", timezones: ["Asia/Bangkok"], aliases: [
            "baht", "thai baht", "thb", "฿",
            "бат", "тайский бат", "тхб",
            "بات", "بات تايلاندي",
        ]),
        Currency(id: "IDR", label: "Indonesian Rupiah", emoji: "🇮🇩", continent: "Asia", timezones: [
            "Asia/Jakarta", "Asia/Pontianak", "Asia/Makassar", "Asia/Jayapura"
        ], aliases: [
            "rupiah", "indonesian rupiah", "idr",
            "рупия индонезийская", "индонезийская рупия", "идр",
            "روبية إندونيسية",
        ]),
        Currency(id: "PHP", label: "Philippine Peso", emoji: "🇵🇭", continent: "Asia", timezones: ["Asia/Manila"], aliases: [
            "philippine peso", "philippine pesos", "filipino peso", "php", "₱",
            "филиппинский песо", "пхп",
            "بيسو فلبيني",
        ]),
        Currency(id: "VND", label: "Vietnamese Dong", emoji: "🇻🇳", continent: "Asia", timezones: ["Asia/Ho_Chi_Minh"], aliases: [
            "dong", "vietnamese dong", "vnd", "₫",
            "донг", "вьетнамский донг", "внд",
            "دونغ", "دونغ فيتنامي",
        ]),

        // Oceania
        Currency(id: "AUD", label: "Australian Dollars", emoji: "🇦🇺", continent: "Oceania", timezones: [
            "Australia/Sydney", "Australia/Melbourne", "Australia/Brisbane",
            "Australia/Perth", "Australia/Adelaide", "Australia/Darwin", "Australia/Hobart"
        ], aliases: [
            "australian dollar", "australian dollars", "aussie dollar", "aussie dollars", "aud",
            "австралийский доллар", "ауд",
            "دولار أسترالي",
        ]),
        Currency(id: "NZD", label: "New Zealand Dollars", emoji: "🇳🇿", continent: "Oceania", timezones: ["Pacific/Auckland", "Pacific/Chatham"], aliases: [
            "new zealand dollar", "new zealand dollars", "kiwi dollar", "kiwi dollars", "nzd",
            "новозеландский доллар", "нзд",
            "دولار نيوزيلندي",
        ]),

        // Africa
        Currency(id: "ZAR", label: "South African Rand", emoji: "🇿🇦", continent: "Africa", timezones: ["Africa/Johannesburg"], aliases: [
            "rand", "south african rand", "zar",
            "рэнд", "ранд", "южноафриканский рэнд", "зар",
            "راند", "راند جنوب أفريقي",
        ]),
        Currency(id: "EGP", label: "Egyptian Pound", emoji: "🇪🇬", continent: "Africa", timezones: ["Africa/Cairo"], aliases: [
            "egyptian pound", "egyptian pounds", "egp",
            "египетский фунт", "егп",
            "جنيه مصري",
        ]),
    ]
}
