import SwiftUI

/// Lightweight emoji confetti burst. Spawns a fresh batch each time
/// `trigger` changes — caller bumps the integer to fire a new wave.
struct ConfettiView: View {
    let trigger: Int

    @State private var pieces: [Piece] = []

    struct Piece: Identifiable {
        let id = UUID()
        let emoji: String
        let xRatio: CGFloat
        let delay: Double
        let rotation: Double
        let duration: Double
        let size: CGFloat
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    ConfettiPiece(piece: piece, screen: geo.size)
                }
            }
        }
        .onChange(of: trigger) { _, _ in spawn() }
        .onAppear { spawn() }
    }

    private func spawn() {
        let emojis = ["⭐️", "✨", "🎉", "🎊", "💫", "🌟", "💎"]
        pieces = (0..<60).map { _ in
            Piece(
                emoji: emojis.randomElement()!,
                xRatio: CGFloat.random(in: 0...1),
                delay: Double.random(in: 0...0.6),
                rotation: Double.random(in: -540...540),
                duration: Double.random(in: 2.2...4.0),
                size: CGFloat.random(in: 18...30)
            )
        }
    }
}

private struct ConfettiPiece: View {
    let piece: ConfettiView.Piece
    let screen: CGSize

    @State private var falling = false

    var body: some View {
        Text(piece.emoji)
            .font(.system(size: piece.size))
            .position(
                x: piece.xRatio * screen.width,
                y: falling ? screen.height + 60 : -60
            )
            .rotationEffect(.degrees(falling ? piece.rotation : 0))
            .opacity(falling ? 0 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: piece.duration).delay(piece.delay)) {
                    falling = true
                }
            }
    }
}
