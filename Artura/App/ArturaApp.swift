import SwiftUI

@main
struct ArturaApp: App {
    @StateObject private var content = ContentStore()
    @StateObject private var user = UserStore()
    @StateObject private var pro = ProStore()
    /// Language of the interface: changing it (onboarding) redraws the app in the new language.
    @State private var language = AppLanguage.code

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
                .environment(\.locale, Locale(identifier: language))
                .environment(\.layoutDirection, AppLanguage.isRightToLeft ? .rightToLeft : .leftToRight)
                .environment(\.appLanguage, language)
                .onReceive(NotificationCenter.default.publisher(for: .appLanguageChanged)) { _ in
                    // Language.swift is shared with the widget, which has no analytics: recorded here.
                    Analytics.track("language_changed", ["from": language, "to": AppLanguage.code])
                    language = AppLanguage.code
                    content.languageChanged()
                }
        }
    }
}

/// The current interface language, for views that must be rebuilt when it changes.
private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue = AppLanguage.code
}

extension EnvironmentValues {
    var appLanguage: String {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

struct RootView: View {
    @EnvironmentObject private var user: UserStore
    @Environment(\.appLanguage) private var language
    @Environment(\.scenePhase) private var scenePhase
    @State private var splash = !OnboardingDebug.flag("noSplash")

    var body: some View {
        ZStack {
            app
            if splash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            Analytics.track("app_opened", [
                "onboarded": user.profile.onboarded,
                "streak": user.streak,
                "lessons_completed": user.profile.completedLessons.count
            ])
        }
        .onChange(of: scenePhase) { _, phase in
            // Whatever is waiting leaves before the app is suspended.
            if phase == .background { Analytics.flush() }
            if phase == .active { Analytics.flush() }
        }
        .task {
            // Wait for the logo animation to play, then the app fades in.
            if OnboardingDebug.flag("holdSplash") { return }
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            withAnimation(.easeInOut(duration: 0.45)) { splash = false }
        }
    }

    private var app: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            if user.profile.onboarded {
                MainTabView()
                    .id(language)
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        // On iPad, the interface keeps a phone width, centered.
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(Palette.bg.ignoresSafeArea())
        .animation(.gentle, value: user.profile.onboarded)
    }
}

// MARK: - Animated launch screen

struct SplashView: View {
    @State private var logoIn = false
    @State private var halo = false
    @State private var letters = 0
    @State private var mottoIn = false

    private let name = Array("Artura")

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack {
                    // Halo that expands once behind the logo.
                    RoundedRectangle(cornerRadius: 34)
                        .stroke(Palette.yellow.opacity(0.7), lineWidth: 3)
                        .frame(width: 128, height: 128)
                        .scaleEffect(halo ? 1.45 : 1)
                        .opacity(halo ? 0 : (logoIn ? 1 : 0))
                    Image("logo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 128, height: 128)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
                        .scaleEffect(logoIn ? 1 : 0.72)
                        .opacity(logoIn ? 1 : 0)
                }

                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        ForEach(Array(name.enumerated()), id: \.offset) { i, letter in
                            Text(String(letter))
                                .font(.figtree(46, .bold))
                                .foregroundStyle(Palette.ink)
                                .opacity(i < letters ? 1 : 0)
                                .offset(y: i < letters ? 0 : 12)
                        }
                    }
                    Text(L("Your daily dose of art, in your pocket"))
                        .font(.figtree(16, .medium))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                        .opacity(mottoIn ? 1 : 0)
                        .offset(y: mottoIn ? 0 : 8)
                }
            }
            .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Artura. Your daily dose of art, in your pocket."))
        .onAppear(perform: play)
    }

    private func play() {
        withAnimation(.easeOut(duration: 0.55)) { logoIn = true }
        withAnimation(.easeOut(duration: 0.9).delay(0.5)) { halo = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { Haptics.soft() }
        for i in 1...name.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 + Double(i) * 0.07) {
                withAnimation(.easeOut(duration: 0.3)) { letters = i }
            }
        }
        withAnimation(.easeOut(duration: 0.5).delay(1.25)) { mottoIn = true }
    }
}
