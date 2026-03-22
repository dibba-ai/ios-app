import Dependencies
import os.log
import Servicing
import SwiftUI

private let logger = Logger(subsystem: "ai.dibba.ios", category: "TargetsView")

struct TargetsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Savings")
                .font(.title)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if isLoading {
                cardContainer {
                    ForEach(0 ..< 3, id: \.self) { index in
                        if index > 0 { Divider().padding(.leading, 60) }
                        TargetRow(target: .makeTarget())
                            .redacted(reason: .placeholder)
                            .padding(.vertical, 4)
                    }
                }
            } else if targets.isEmpty {
                cardContainer {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "target")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text("No savings goals yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                }
            } else {
                cardContainer {
                    ForEach(Array(targets.enumerated()), id: \.element.id) { index, target in
                        if index > 0 { Divider().padding(.leading, 60) }
                        Button {
                            selectedIndex = index
                            showingDetail = true
                        } label: {
                            TargetRow(target: target)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            TargetDetailDrawer(
                targets: targets,
                currentIndex: $selectedIndex
            )
            .presentationDetents([.fraction(0.7), .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            await loadTargets()
        }
    }

    // MARK: - Card Container

    @ViewBuilder
    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }

    // MARK: - Private

    @Dependency(\.targetService) private var targetService
    @State private var targets: [Servicing.Target] = []
    @State private var isLoading = true
    @State private var showingDetail = false
    @State private var selectedIndex = 0

    private func loadTargets() async {
        let cached = await targetService.cachedTargets
        if !cached.isEmpty {
            targets = cached.filter(\.isActive)
            isLoading = false
            return
        }

        do {
            let result = try await targetService.getTargets(force: false)
            targets = result.filter(\.isActive)
        } catch {
            logger.error("Failed to load targets: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

// MARK: - Target Row

private struct TargetRow: View {
    let target: Servicing.Target

    var body: some View {
        HStack(spacing: 12) {
            Text(target.emoji)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(target.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(target.formattedAmountSaved) / \(target.formattedAmountTarget)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: target.progress)
                    .tint(target.progress >= 1.0 ? .green : .blue)
            }
        }
    }
}
