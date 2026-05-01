import Foundation
import Servicing

extension FeedView {
    /// Loads pages until a section matching `date` becomes available, then scrolls to it.
    func scrollToDate(_ date: Date) async {
        let cal = Calendar.current
        let targetTimestamp = Int64(cal.startOfDay(for: date).timeIntervalSince1970)

        if let target = matchingSectionId(for: date) {
            pendingScrollTarget = target
            return
        }

        while hasMore {
            await loadNextPage()
            if let last = transactions.last, last.createdAt.timeIntervalSince1970 < TimeInterval(targetTimestamp) {
                break
            }
            if let target = matchingSectionId(for: date) {
                pendingScrollTarget = target
                return
            }
        }

        if let target = matchingSectionId(for: date) ?? nearestSectionId(for: date) {
            pendingScrollTarget = target
        }
    }

    func scrollToEnd() async {
        while hasMore {
            await loadNextPage()
        }
        if let last = groupedTransactions.last?.date {
            pendingScrollTarget = last
        }
    }

    private func matchingSectionId(for date: Date) -> String? {
        let cal = Calendar.current
        for section in groupedTransactions {
            guard let secDate = sectionDateParser.date(from: section.date) else { continue }
            if cal.isDate(secDate, inSameDayAs: date) { return section.date }
        }
        return nil
    }

    private func nearestSectionId(for date: Date) -> String? {
        var bestId: String?
        var bestDistance = TimeInterval.infinity
        for section in groupedTransactions {
            guard let secDate = sectionDateParser.date(from: section.date) else { continue }
            let distance = abs(secDate.timeIntervalSince(date))
            if distance < bestDistance {
                bestDistance = distance
                bestId = section.date
            }
        }
        return bestId
    }
}
