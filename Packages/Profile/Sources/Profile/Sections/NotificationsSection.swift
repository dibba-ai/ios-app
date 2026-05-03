import Analytics
import ApiClient
import Dependencies
import Servicing
import SwiftUI

struct NotificationsSection: View {
    let profile: Servicing.Profile
    let onUpdate: (UpdateProfileInput) async -> Void

    @Dependency(\.analytics) private var analytics

    var body: some View {
        Section("Notifications") {
            NotificationToggle(
                title: "Daily Reports",
                isOn: profile.notifyDailyReport
            ) { newValue in
                captureToggle(category: "daily", enabled: newValue)
                await onUpdate(UpdateProfileInput(notifyDailyReport: newValue))
            }

            NotificationToggle(
                title: "Weekly Reports",
                isOn: profile.notifyWeeklyReport
            ) { newValue in
                captureToggle(category: "weekly", enabled: newValue)
                await onUpdate(UpdateProfileInput(notifyWeeklyReport: newValue))
            }

            NotificationToggle(
                title: "Monthly Reports",
                isOn: profile.notifyMonthlyReport
            ) { newValue in
                captureToggle(category: "monthly", enabled: newValue)
                await onUpdate(UpdateProfileInput(notifyMonthlyReport: newValue))
            }

            NotificationToggle(
                title: "Annual Reports",
                isOn: profile.notifyAnnualReport
            ) { newValue in
                captureToggle(category: "annual", enabled: newValue)
                await onUpdate(UpdateProfileInput(notifyAnnualReport: newValue))
            }
        }
    }

    private func captureToggle(category: String, enabled: Bool) {
        let event: AnalyticsEvent = enabled ? .notificationsEnabled : .notificationsDisabled
        analytics.capture(event, properties: ["category": .string(category)])
    }
}
