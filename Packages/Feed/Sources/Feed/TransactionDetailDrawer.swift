import Servicing
import SwiftUI

// MARK: - Transaction Detail Drawer

public struct TransactionDetailDrawer: View {
    public let transactions: [Servicing.Transaction]
    @Binding var currentIndex: Int

    public init(transactions: [Servicing.Transaction], currentIndex: Binding<Int>) {
        self.transactions = transactions
        self._currentIndex = currentIndex
    }

    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingHorizontally = false
    @State private var directionDecided = false
    @State private var showBoundaryBanner = false
    @State private var boundaryMessage = ""

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
            }
            .navigationBarTitleDisplayMode(.inline)
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
