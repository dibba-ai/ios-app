import AppIntents
import Intents

struct DibbaAppShortcuts: AppShortcutsProvider {
    static let appShortcuts: [AppShortcut] = [
        AppShortcut(
            intent: LogPurchaseIntent(),
            phrases: [
                "Log purchase in \(.applicationName)",
                "Add purchase in \(.applicationName)",
                "I spent in \(.applicationName)",
                "Log spending in \(.applicationName)",
                "Add expense in \(.applicationName)",
            ],
            shortTitle: "Log Purchase",
            systemImageName: "creditcard"
        ),
        AppShortcut(
            intent: LogIncomeIntent(),
            phrases: [
                "Log income in \(.applicationName)",
                "Add income in \(.applicationName)",
                "Got paid in \(.applicationName)",
                "Record income in \(.applicationName)",
            ],
            shortTitle: "Log Income",
            systemImageName: "arrow.down.circle"
        ),
        AppShortcut(
            intent: LogTransferIntent(),
            phrases: [
                "Log transfer in \(.applicationName)",
                "Move money in \(.applicationName)",
                "Add transfer in \(.applicationName)",
                "Record transfer in \(.applicationName)",
            ],
            shortTitle: "Log Transfer",
            systemImageName: "arrow.left.arrow.right"
        ),
    ]
}
