import CoreLocation
import MapKit
import Servicing
import SwiftUI
import UIKit

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

// MARK: - Transaction Detail View

struct TransactionDetailView: View {
    let transaction: Servicing.Transaction
    var isScrollDisabled = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                locationMapSection
                messageBubble
                detailsSection
                accountSection
                inputSection
                metadataSection
            }
            .padding()
        }
        .scrollDisabled(isScrollDisabled)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(transaction.success ? (transaction.isCredit ? Color.green.opacity(0.15) : Color(.systemGray5)) : Color.red.opacity(0.15))
                    .frame(width: 72, height: 72)

                if transaction.success {
                    Text(iconEmoji)
                        .font(.system(size: 32))
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.red)
                }
            }

            Text(transaction.name.isEmpty ? transaction.transactionType.displayName : transaction.name)
                .font(.title2.bold())
                .strikethrough(!transaction.success, color: .red)
                .multilineTextAlignment(.center)

            Text(amountText)
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(transaction.success ? (transaction.isCredit ? .green : .primary) : .red)
                .strikethrough(!transaction.success, color: .red)

            HStack(spacing: 6) {
                Image(systemName: transaction.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(transaction.success ? .green : .red)
                Text(transaction.success ? "Successful" : "Failed")
                    .foregroundStyle(transaction.success ? .green : .red)
            }
            .font(.subheadline.weight(.medium))

            if let errorMessage = transaction.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private var messageBubble: some View {
        if let text = transaction.input?.text, !text.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(icon: "message.fill", title: "Message")

                HStack {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 18))
                    Spacer(minLength: 48)
                }
            }
        }
    }

    // MARK: - Location Map

    @ViewBuilder
    private var locationMapSection: some View {
        if let location = transaction.input?.location, !location.isEmpty {
            LocationMapView(address: location)
        }
    }

    // MARK: - Details

    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(icon: "info.circle.fill", title: "Details")

            LabeledContent("Type", value: transaction.transactionType.displayName)

            if transaction.isPurchase, !transaction.merchantCategory.isEmpty {
                LabeledContent("Category", value: transaction.merchantCategory)
            }

            LabeledContent("Date", value: transaction.fullDate)

            LabeledContent("Time", value: formattedTime)

            if !transaction.orgName.isEmpty {
                LabeledContent {
                    VStack(alignment: .trailing) {
                        Text(transaction.orgName)
                        if !transaction.orgType.isEmpty {
                            Text(transaction.orgType)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } label: {
                    Text("Organization")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Account

    @ViewBuilder
    private var accountSection: some View {
        let hasCard = !transaction.cardNumber.isEmpty
        let hasAccount = !transaction.accountNumber.isEmpty

        if hasCard || hasAccount {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(icon: "creditcard.fill", title: "Account")

                if hasCard {
                    LabeledContent("Card", value: transaction.cardNumber)
                }

                if hasAccount {
                    LabeledContent("Account", value: transaction.accountNumber)
                }

                LabeledContent("Currency", value: transaction.currency)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Input

    @ViewBuilder
    private var inputSection: some View {
        if let input = transaction.input {
            let hasFields = input.from != nil || input.merchant != nil || input.card != nil || input.amount != nil

            if hasFields {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(icon: "square.and.pencil", title: "Input")

                    if let from = input.from, !from.isEmpty {
                        LabeledContent("From", value: from)
                    }
                    if let merchant = input.merchant, !merchant.isEmpty {
                        LabeledContent("Merchant", value: merchant)
                    }
                    if let card = input.card, !card.isEmpty {
                        LabeledContent("Card", value: card)
                    }
                    if let amount = input.amount, !amount.isEmpty {
                        LabeledContent("Amount", value: amount)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Metadata

    @ViewBuilder
    private var metadataSection: some View {
        if let metadata = transaction.metadata {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(icon: "gearshape.fill", title: "Metadata")

                LabeledContent("Type", value: metadata.type)

                if let userAgent = metadata.userAgent, !userAgent.isEmpty {
                    LabeledContent("User Agent", value: userAgent)
                }
                if let ipAddress = metadata.ipAddress, !ipAddress.isEmpty {
                    LabeledContent("IP Address", value: ipAddress)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private var iconEmoji: String {
        if transaction.isAtm { return "🏧" }
        if transaction.isTransfer { return "↔️" }
        if transaction.isPurchase {
            return merchantCategoryEmojis[transaction.merchantCategory] ?? "🛒"
        }
        return transaction.transactionType.emoji
    }

    private var amountText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = transaction.currency
        let absAmount = abs(transaction.amount)
        let formatted = formatter.string(from: NSNumber(value: absAmount)) ?? "\(absAmount)"
        return transaction.isCredit ? "+\(formatted)" : "-\(formatted)"
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: transaction.createdAt)
    }
}

// MARK: - Location Map View

private struct LocationMapView: View {
    let address: String

    @State private var coordinate: CLLocationCoordinate2D?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var isGeocoding = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(icon: "mappin.circle.fill", title: "Location")

            if let coordinate {
                Button {
                    openInMaps(coordinate: coordinate)
                } label: {
                    Map(
                        position: $mapPosition,
                        interactionModes: []
                    ) {
                        Marker(address, coordinate: coordinate)
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .bottomTrailing) {
                        Label("Open in Maps", systemImage: "arrow.up.right.square")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                            .padding(8)
                    }
                }
                .buttonStyle(.plain)
            } else if isGeocoding {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 180)
                    .overlay(ProgressView())
            } else {
                HStack {
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        openInMaps(address: address)
                    } label: {
                        Label("Open in Maps", systemImage: "map")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: address) {
            await geocode()
        }
    }

    private func openInMaps(coordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = address
        mapItem.openInMaps()
    }

    private func openInMaps(address: String) {
        guard let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "maps://?q=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }

    private func geocode() async {
        isGeocoding = true
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            if let coord = placemarks.first?.location?.coordinate {
                coordinate = coord
                mapPosition = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))
            } else {
                coordinate = nil
            }
        } catch {
            coordinate = nil
        }
        isGeocoding = false
    }
}
