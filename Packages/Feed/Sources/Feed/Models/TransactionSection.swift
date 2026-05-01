import Foundation
import Servicing

struct TransactionSection: Identifiable {
    let date: String
    let transactions: [Servicing.Transaction]
    var id: String { date }
}

let sectionDateParser: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

func formatSectionDate(_ dateString: String) -> String {
    guard let date = sectionDateParser.date(from: dateString) else { return dateString }

    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return "Today" }
    if calendar.isDateInYesterday(date) { return "Yesterday" }

    let formatter = DateFormatter()
    formatter.locale = Locale.current
    if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
        formatter.dateFormat = "MMMM d"
    } else {
        formatter.dateFormat = "MMMM d, yyyy"
    }
    return formatter.string(from: date)
}
