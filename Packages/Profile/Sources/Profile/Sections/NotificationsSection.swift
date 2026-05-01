import ApiClient
import Servicing
import SwiftUI

struct NotificationsSection: View {
    let profile: Servicing.Profile
    let onUpdate: (UpdateProfileInput) async -> Void

    var body: some View {
        Section("Notifications") {
            NotificationToggle(
                title: "Daily Reports",
                isOn: profile.notifyDailyReport
            ) { newValue in
                await onUpdate(UpdateProfileInput(notifyDailyReport: newValue))
            }

            NotificationToggle(
                title: "Weekly Reports",
                isOn: profile.notifyWeeklyReport
            ) { newValue in
                await onUpdate(UpdateProfileInput(notifyWeeklyReport: newValue))
            }

            NotificationToggle(
                title: "Monthly Reports",
                isOn: profile.notifyMonthlyReport
            ) { newValue in
                await onUpdate(UpdateProfileInput(notifyMonthlyReport: newValue))
            }

            NotificationToggle(
                title: "Annual Reports",
                isOn: profile.notifyAnnualReport
            ) { newValue in
                await onUpdate(UpdateProfileInput(notifyAnnualReport: newValue))
            }
        }
    }
}
