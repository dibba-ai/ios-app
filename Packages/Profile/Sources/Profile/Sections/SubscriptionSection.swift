import Paywall
import Servicing
import SwiftUI

struct SubscriptionSection: View {
    let profile: Servicing.Profile

    var body: some View {
        Section("Subscription") {
            LabeledContent("Plan") {
                HStack(spacing: 4) {
                    if profile.isPremium {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                    Text(profile.plan.displayName)
                }
            }

            if let startsAt = profile.planStartsAt {
                LabeledContent("Started", value: formatProfileDate(startsAt))
            }

            if let expiresAt = profile.planExpiresAt {
                LabeledContent("Expires", value: formatProfileDate(expiresAt))
            }

            // TODO: Re-enable once paywall is ready for users.
            // if !profile.isPremium {
            //     UpgradePremiumButton()
            // }
        }
    }
}
