import SwiftUI

// MARK: 1 · Welcome

struct WelcomeScreen: View {
    let onNext: () -> Void
    let onLogin: () -> Void

    var body: some View {
        HeroScaffold(image: "ill_hero", imageHeight: 470, cta: "Get started", onNext: onNext,
                     secondaryTitle: "I already have an account", onSecondary: onLogin) {
            Text("Artura").font(.figtree(15, .semibold)).foregroundStyle(Palette.blueText).appearUp(0.1)
            Text("One masterpiece a day").font(.figtree(32, .semibold)).foregroundStyle(Palette.ink).appearUp(0.2)
            Text("Five minutes to look, understand, and remember.")
                .font(.aBody).foregroundStyle(Palette.ink).appearUp(0.3)
        }
    }
}

// MARK: 2 · Promise (slow, block by block)

struct PromiseScreen: View {
    let onNext: () -> Void
    @State private var shown = 0

    private let rows: [(String, String, String)] = [
        ("art_impression", "One artwork a day", "Its story in 2 minutes, to read or listen to."),
        ("ill_zoom", "Mini-games", "One minute of play to remember what you just saw."),
        ("ill_musee", "Paths", "The great movements, lesson by lesson, at your own pace.")
    ]
    private let pace = 1.6

    var body: some View {
        SlowScreen(duration: 1.2 + Double(rows.count) * pace + 0.4, onNext: onNext) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Here's what's waiting for you").font(.aTitle).foregroundStyle(Palette.ink)
                    Text("Three little things, every day.").font(.aBody).foregroundStyle(Palette.muted)
                }
                .opacity(shown >= 1 ? 1 : 0)
                .offset(y: shown >= 1 ? 0 : 12)

                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack(spacing: 14) {
                        ArtImage(name: row.0).frame(width: 104, height: 120)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.1).font(.aCardTitle).foregroundStyle(Palette.ink)
                            Text(row.2).font(.aSmall).foregroundStyle(Palette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.trailing, 14)
                    .background(Palette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .opacity(shown >= i + 2 ? 1 : 0)
                    .offset(y: shown >= i + 2 ? 0 : 16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
        }
        .onAppear {
            for i in 1...(rows.count + 1) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i - 1) * pace) {
                    withAnimation(.easeOut(duration: 1.1)) { shown = i }
                    Haptics.soft()
                }
            }
        }
    }
}

// MARK: 3 · You are…

struct GenderScreen: View {
    @EnvironmentObject private var user: UserStore
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        OnbScaffold(number: OnbStep.gender.number, onBack: onBack, title: "You are…",
                    subtitle: "So we can talk to you the right way.",
                    ctaEnabled: user.profile.gender != nil, onNext: onNext) {
            HStack(spacing: 12) {
                portrait("ill_av1", "A woman", "femme")
                portrait("ill_av2", "A man", "homme")
            }
            .appearUp(0.1)
            VStack(spacing: 10) {
                OptionRow(title: "Other", selected: user.profile.gender == "autre") { user.profile.gender = "autre" }
                OptionRow(title: "I'd rather not say", selected: user.profile.gender == "na") { user.profile.gender = "na" }
            }
            .appearUp(0.2)
        }
    }

    private func portrait(_ image: String, _ label: String, _ value: String) -> some View {
        let selected = user.profile.gender == value
        return Button {
            Haptics.selection()
            user.profile.gender = value
        } label: {
            VStack(spacing: 12) {
                ArtImage(name: image).frame(height: 150)
                Text(label).font(.figtree(17, .semibold)).foregroundStyle(Palette.ink)
            }
            .padding(.bottom, 14)
            .background(selected ? Palette.blueSelected : Palette.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? Palette.blue : .clear, lineWidth: 3))
            .overlay(alignment: .topTrailing) {
                if selected { CheckBadge().padding(8).transition(.scale) }
            }
            .scaleEffect(selected ? 1.01 : 1)
        }
        .buttonStyle(.pressable)
        .animation(.bouncy, value: selected)
    }
}

// MARK: 5 · Artura is here to help (the eye)

struct HelpScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        HeroScaffold(image: "ill_oeil", onBack: onBack, onNext: onNext) {
            TagPill(text: "Artura is here to help").appearUp(0.1)
            Text("Looking is a skill").font(.figtree(32, .semibold)).foregroundStyle(Palette.ink).appearUp(0.2)
            Text("Nobody is born knowing how to read a painting. Every day, we show you where to look: a detail, a color, a gesture.")
                .font(.aBody).foregroundStyle(Palette.ink).appearUp(0.3)
            Text("Rushing past a painting isn't a failing. We'll just give you a reason to stop.")
                .font(.aBody).foregroundStyle(Palette.muted).appearUp(0.4)
        }
    }
}

// MARK: Reviews and rating

struct ReviewsScreen: View {
    let onBack: () -> Void
    let onNext: () -> Void
    @State private var stars = 0

    // TODO: replace with real reviews and the real App Store rating before launch.
    private let reviews = [
        "“Five minutes in the morning, and I finally see paintings differently.”",
        "“The little games really help me remember names and dates.”",
        "“I knew nothing about art. Now I look forward to the notification.”"
    ]

    var body: some View {
        OnbScaffold(onBack: onBack, title: "You're not \(alone) getting started", onNext: onNext) {
            HStack(spacing: 16) {
                Text("4.8").font(.figtree(52, .semibold)).foregroundStyle(Palette.ink)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: "star.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Palette.yellow)
                                .scaleEffect(i < stars ? 1 : 0.7)
                                .opacity(i < stars ? 1 : 0)
                        }
                    }
                    Text("out of 5 · App Store").font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 20).fill(Palette.blueSoft))
            .appearUp(0.05)

            Text("What people are saying").font(.aHeading).foregroundStyle(Palette.ink)

            VStack(spacing: 12) {
                ForEach(Array(reviews.enumerated()), id: \.offset) { i, review in
                    Text(review)
                        .font(.figtree(15, .medium))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
                        .appearUp(0.2 + 0.1 * Double(i))
                }
            }
        }
        .onAppear {
            for i in 1...5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 * Double(i)) {
                    withAnimation(.bouncy) { stars = i }
                    Haptics.soft()
                }
            }
        }
    }

    @EnvironmentObject private var user: UserStore
    private var alone: String { user.agree("the only one", "the only one") }
}
