import Servicing
import SwiftUI

// MARK: - Section Header

private struct SectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.blue)
            Text(title)
                .font(.title3.bold())
        }
    }
}

// MARK: - Target Detail View

struct TargetDetailView: View {
    let target: Servicing.Target
    var isScrollDisabled = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                overviewSection
                planSection
                actionsSection
            }
            .padding()
        }
        .scrollDisabled(isScrollDisabled)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray4), lineWidth: 4)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: target.progress)
                    .stroke(
                        target.progress >= 1.0 ? Color.green : Color.blue,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))

                Text(target.emoji)
                    .font(.system(size: 32))
            }

            Text(target.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("\(target.progressPercent)%")
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(target.progress >= 1.0 ? .green : .blue)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(icon: "info.circle.fill", title: "Overview")

            LabeledContent("Target amount", value: formattedInteger(target.amountTarget))
            LabeledContent("Saved amount", value: formattedInteger(target.amountSaved))
            LabeledContent("Remaining", value: formattedInteger(target.amountRemaining))
            LabeledContent("Target date", value: formattedDate(target.expectedEndAt))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Plan

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(icon: "calendar.badge.clock", title: "Plan")

            let days = target.daysRemaining
            let remaining = target.amountRemaining

            if days > 0, remaining > 0 {
                let daily = Int(ceil(remaining / Double(days)))
                LabeledContent(
                    "\(formattedInteger(Double(daily))) / day",
                    value: "\(days) days"
                )

                let weeks = max(days / 7, 1)
                let weekly = Int(ceil(remaining / Double(weeks)))
                LabeledContent(
                    "\(formattedInteger(Double(weekly))) / week",
                    value: "\(weeks) weeks"
                )

                let months = max(days / 30, 1)
                let monthly = Int(ceil(remaining / Double(months)))
                LabeledContent(
                    "\(formattedInteger(Double(monthly))) / month",
                    value: formattedTimeRemaining(months: months)
                )
            } else if remaining <= 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Target reached!")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Target date has passed")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "bolt.circle.fill", title: "Actions")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ],
                spacing: 12
            ) {
                actionButton(
                    title: "Top Up",
                    icon: "plus.circle.fill",
                    color: .blue
                )
                actionButton(
                    title: "Complete",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                actionButton(
                    title: "Change Date",
                    icon: "calendar.circle.fill",
                    color: .orange
                )
                actionButton(
                    title: "Archive",
                    icon: "archivebox.circle.fill",
                    color: .red
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionButton(title: String, icon: String, color: Color) -> some View {
        Button {} label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func formattedInteger(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = target.currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formattedTimeRemaining(months: Int) -> String {
        if months >= 12 {
            let years = months / 12
            let remainingMonths = months % 12
            if remainingMonths == 0 {
                return "\(years) \(years == 1 ? "year" : "years")"
            }
            return "\(years) \(years == 1 ? "year" : "years") \(remainingMonths) \(remainingMonths == 1 ? "month" : "months")"
        }
        return "\(months) \(months == 1 ? "month" : "months")"
    }
}
