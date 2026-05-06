// Top-level shell. Hosts the TabView, the persistent RadialDial, the
// onboarding gate, and the empty-bag guard.

import SwiftData
import SwiftUI

public struct RootShell: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var clubModels: [ClubModel]

    @State private var settings = SettingsStore.shared
    @State private var route: AppRoute = .calculator

    public init() {}

    public var body: some View {
        ZStack {
            if !settings.onboardingComplete {
                OnboardingScreen(onComplete: { /* settings drives re-render */ })
                    .transition(.opacity)
            } else {
                tabContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: settings.onboardingComplete)
        // EmptyBagGuard: kick the user back to .bag if they're on a protected
        // route with zero clubs.
        .onChange(of: clubModels.count) { _, count in enforceBagGuard(count: count) }
        .onChange(of: route) { _, _ in enforceBagGuard(count: clubModels.count) }
        .onAppear { enforceBagGuard(count: clubModels.count) }
    }

    private var tabContent: some View {
        TabView(selection: $route) {
            CalculatorScreen()
                .tabItem {
                    Label(AppRoute.calculator.label, systemImage: AppRoute.calculator.systemImage)
                }
                .tag(AppRoute.calculator)
            BagScreen()
                .tabItem {
                    Label(AppRoute.bag.label, systemImage: AppRoute.bag.systemImage)
                }
                .tag(AppRoute.bag)
            RangeScreen()
                .tabItem {
                    Label(AppRoute.range.label, systemImage: AppRoute.range.systemImage)
                }
                .tag(AppRoute.range)
            SettingsScreen()
                .tabItem {
                    Label(AppRoute.settings.label, systemImage: AppRoute.settings.systemImage)
                }
                .tag(AppRoute.settings)
        }
        .tint(DesignTokens.primary)
        .overlay(alignment: .bottomTrailing) {
            RadialDial(
                route: $route,
                disabledRoutes: clubModels.isEmpty ? protectedRoutes : []
            )
        }
    }

    private func enforceBagGuard(count: Int) {
        guard settings.onboardingComplete else { return }
        if count == 0 && protectedRoutes.contains(route) {
            route = .bag
        }
    }
}

#Preview {
    RootShell()
        .modelContainer(for: [
            ClubModel.self,
            SessionModel.self,
            ShotModel.self,
            FaceStrikeModel.self,
        ], inMemory: true)
}
