import SwiftUI

struct LaunchSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 22) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    .shadow(color: Color.accentColor.opacity(0.16), radius: 24, y: 8)
                    .scaleEffect(reduceMotion || revealed ? 1 : 0.88)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("FinanceTracker")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("Your money. Your privacy.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(reduceMotion || revealed ? 1 : 0)
                .offset(y: reduceMotion || revealed ? 0 : 8)

                Label("On your device", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.65)) {
                revealed = true
            }
        }
    }
}

#Preview { LaunchSplashView() }
