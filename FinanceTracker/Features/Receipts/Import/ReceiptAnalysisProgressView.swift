import SwiftUI

struct ReceiptAnalysisProgressView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stage: String

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color("SummaryBackground"))
                    .frame(width: 120, height: 120)
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                if !reduceMotion {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(width: 82, height: 3)
                        .phaseAnimator([false, true]) { line, phase in
                            line.offset(y: phase ? 36 : -36)
                        } animation: { _ in .easeInOut(duration: 1.8) }
                }
            }
            Text("Reading your receipt")
                .font(.title3.weight(.semibold))
            ProgressView(stage)
                .font(.subheadline)
            Label("Processed privately on your iPhone", systemImage: "lock.shield")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .accessibilityElement(children: .combine)
    }
}
