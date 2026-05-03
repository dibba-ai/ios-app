import Analytics
import Dependencies
import os.log
import Servicing
import SwiftUI

private let logger = Logger(subsystem: "ai.dibba.ios", category: "TransactionDetailDrawer")

// MARK: - Transaction Detail Drawer

public struct TransactionDetailDrawer: View {
    public let transactions: [Servicing.Transaction]
    @Binding var currentIndex: Int
    public let onDeleted: ((String) -> Void)?

    public init(
        transactions: [Servicing.Transaction],
        currentIndex: Binding<Int>,
        onDeleted: ((String) -> Void)? = nil
    ) {
        self.transactions = transactions
        self._currentIndex = currentIndex
        self.onDeleted = onDeleted
    }

    @Environment(\.dismiss) private var dismiss
    @Dependency(\.transactionService) private var transactionService
    @Dependency(\.analytics) private var analytics
    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingHorizontally = false
    @State private var directionDecided = false
    @State private var showBoundaryBanner = false
    @State private var boundaryMessage = ""
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    public var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let pageWidth = geo.size.width

                ZStack(alignment: .top) {
                    HStack(spacing: 0) {
                        if currentIndex > 0 {
                            TransactionDetailView(
                                transaction: transactions[currentIndex - 1],
                                isScrollDisabled: isDraggingHorizontally
                            )
                            .frame(width: pageWidth)
                        }

                        TransactionDetailView(
                            transaction: transactions[currentIndex],
                            isScrollDisabled: isDraggingHorizontally
                        )
                        .frame(width: pageWidth)

                        if currentIndex < transactions.count - 1 {
                            TransactionDetailView(
                                transaction: transactions[currentIndex + 1],
                                isScrollDisabled: isDraggingHorizontally
                            )
                            .frame(width: pageWidth)
                        }
                    }
                    .offset(x: hstackOffset(pageWidth: pageWidth))

                    boundaryBannerView
                }
                .contentShape(Rectangle())
                .simultaneousGesture(swipeGesture(pageWidth: pageWidth))
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("\(currentIndex + 1) of \(transactions.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                    .disabled(isDeleting || transactions.isEmpty)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Delete Transaction?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await performDelete() }
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .onAppear {
                let id = currentIndex < transactions.count ? transactions[currentIndex].id : ""
                analytics.capture(.transactionOpened, properties: ["transaction_id": .string(id)])
            }
            .onDisappear {
                analytics.capture(.transactionClosed)
            }
        }
    }

    // MARK: - Delete

    private func performDelete() async {
        guard currentIndex < transactions.count else { return }
        let id = transactions[currentIndex].id
        isDeleting = true
        defer { isDeleting = false }
        do {
            _ = try await transactionService.deleteTransaction(id: id)
            analytics.capture(.transactionDeleted, properties: ["transaction_id": .string(id)])
            onDeleted?(id)
            dismiss()
        } catch {
            logger.error("deleteTransaction failed: \(error.localizedDescription)")
            analytics.capture(.transactionDeleteFailed, properties: [
                "transaction_id": .string(id),
                "error": .string(error.localizedDescription)
            ])
        }
    }

    // MARK: - Layout

    private func hstackOffset(pageWidth: CGFloat) -> CGFloat {
        let prevPageOffset: CGFloat = currentIndex > 0 ? -pageWidth : 0
        return prevPageOffset + dragOffset
    }

    // MARK: - Boundary Banner

    @ViewBuilder
    private var boundaryBannerView: some View {
        if showBoundaryBanner {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.secondary)
                Text(boundaryMessage)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Swipe Gesture

    private func swipeGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                // Decide direction once per gesture
                if !directionDecided {
                    directionDecided = true
                    isDraggingHorizontally = abs(value.translation.width) > abs(value.translation.height)
                }

                if isDraggingHorizontally {
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                defer {
                    directionDecided = false
                    isDraggingHorizontally = false
                }

                guard isDraggingHorizontally else { return }

                let threshold: CGFloat = 50
                let translation = value.translation.width

                guard abs(translation) > threshold else {
                    withAnimation(.easeOut(duration: 0.25)) {
                        dragOffset = 0
                    }
                    return
                }

                if translation < 0 {
                    // Swipe left → next transaction
                    if currentIndex < transactions.count - 1 {
                        withAnimation(.easeOut(duration: 0.25)) {
                            dragOffset = -pageWidth
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            var t = SwiftUI.Transaction()
                            t.disablesAnimations = true
                            withTransaction(t) {
                                currentIndex += 1
                                dragOffset = 0
                            }
                        }
                    } else {
                        showBoundary("No more transactions")
                    }
                } else {
                    // Swipe right → previous transaction
                    if currentIndex > 0 {
                        withAnimation(.easeOut(duration: 0.25)) {
                            dragOffset = pageWidth
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            var t = SwiftUI.Transaction()
                            t.disablesAnimations = true
                            withTransaction(t) {
                                currentIndex -= 1
                                dragOffset = 0
                            }
                        }
                    } else {
                        showBoundary("No more transactions")
                    }
                }
            }
    }

    // MARK: - Boundary Handling

    private func showBoundary(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = 0
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        boundaryMessage = message
        withAnimation(.spring(duration: 0.3)) {
            showBoundaryBanner = true
        }

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.3)) {
                showBoundaryBanner = false
            }
        }
    }
}
