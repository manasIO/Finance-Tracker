import SwiftUI
import UIKit
import SwiftData

enum AppTheme: String, CaseIterable {
    case system, light, dark

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

struct WindowAppearance: UIViewRepresentable {
    let theme: AppTheme

    func makeUIView(context: Context) -> WindowAppearanceView {
        let view = WindowAppearanceView()
        view.theme = theme
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: WindowAppearanceView, context: Context) {
        view.theme = theme
    }
}

final class WindowAppearanceView: UIView {
    var theme: AppTheme = .system {
        didSet { applyAppearance() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyAppearance()
    }

    private func applyAppearance() {
        // Apply to this scene's window, including sheets. Unspecified restores
        // live system appearance instead of retaining a previous forced style.
        window?.overrideUserInterfaceStyle = theme.interfaceStyle
    }
}

struct AppRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingSplash = ProcessInfo.processInfo.environment["FINANCE_TRACKER_TESTING"] != "1"
    @AppStorage("hasCompletedOnboarding") private var completedOnboarding = false
    @Query private var profiles: [UserProfile]
    @Query private var receipts: [Receipt]
    @Query private var budgets: [MonthlyBudget]
    @Query private var recurring: [RecurringExpense]

    private var existingUser: Bool {
        !profiles.isEmpty || !receipts.isEmpty || !budgets.isEmpty || !recurring.isEmpty
    }

    @AppStorage("appTheme") private var theme: AppTheme = .system

    var body: some View {
        ZStack {
            if showingSplash {
                LaunchSplashView()
                    .transition(.opacity)
            } else {
                Group {
                    if completedOnboarding || existingUser || ProcessInfo.processInfo.environment["FINANCE_TRACKER_TESTING"] == "1" {
                        mainTabs
                    } else {
                        OnboardingView { completedOnboarding = true }
                    }
                }
                .transition(.opacity)
            }
        }
        .task {
            guard showingSplash else { return }
            // Show once per launch, without delaying navigation on foregrounding.
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 500 : 1200)) }
            catch { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                showingSplash = false
            }
        }
        .onAppear { if existingUser { completedOnboarding = true } }
        .tint(Color.accentColor)
        .background(WindowAppearance(theme: theme).frame(width: 0, height: 0))
    }

    private var mainTabs: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar") }
            ReceiptListView()
                .tabItem { Label("Receipts", systemImage: "receipt") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}
