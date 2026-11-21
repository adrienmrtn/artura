import SwiftUI

@main
struct ArturaApp: App {
    @StateObject private var content = ContentStore()
    @StateObject private var user = UserStore()
    @StateObject private var pro = ProStore()

    init() {
        FontRegistrar.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(content)
                .environmentObject(user)
                .environmentObject(pro)
                .preferredColorScheme(.light)
                .tint(Palette.blue)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var user: UserStore

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if user.profile.onboarded {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.gentle, value: user.profile.onboarded)
    }
}
