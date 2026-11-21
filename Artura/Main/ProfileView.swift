import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var user: UserStore
    @EnvironmentObject private var content: ContentStore
    @EnvironmentObject private var pro: ProStore
    @State private var course: Artwork?
    @State private var showPaywall = false
    @State private var confirmReset = false

    private var levelLabel: String {
        let done = user.profile.completedLessons.count
        return "\(user.profile.level ?? "Amateur") · niveau \(1 + done / 2)"
    }

    private var tastes: [(movement: Movement, count: Int)] {
        let ids = user.profile.opened + user.profile.liked
        return content.movements
            .map { m in (movement: m, count: ids.filter { content.artwork($0)?.movementId == m.id }.count) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SkyHeader(height: 190) {
                    HStack(spacing: 14) {
                        ArtImage(name: avatarImages[min(user.profile.avatar, avatarImages.count - 1)])
                            .frame(width: 76, height: 76)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .id(user.profile.avatar)
                            .transition(.scale.combined(with: .opacity))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.profile.firstName ?? "Ton profil").font(.figtree(24, .semibold))
                            Text(levelLabel).font(.figtree(14))
                        }
                        .foregroundStyle(.white)
                    }
                    .padding(.leading, 24)
                    .padding(.top, 60)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Choisis ton avatar").font(.aHeading).foregroundStyle(Palette.ink)
                    AvatarPicker(selection: $user.profile.avatar, size: 54)

                    HStack(spacing: 10) {
                        stat("\(user.streak)", user.streak > 1 ? "jours de série" : "jour de série", Palette.yellow)
                        stat("\(user.profile.opened.count)", "œuvres ouvertes", Palette.pink)
                        stat("\(user.profile.gamesWon)", "jeux réussis", Palette.sand)
                    }

                    Text("Ma collection").font(.aHeading).foregroundStyle(Palette.ink).padding(.top, 4)
                    collection

                    if !tastes.isEmpty {
                        Text("Tes goûts").font(.aHeading).foregroundStyle(Palette.ink).padding(.top, 4)
                        VStack(spacing: 12) {
                            let maxCount = tastes.map(\.count).max() ?? 1
                            ForEach(tastes, id: \.movement.id) { item in
                                VStack(spacing: 6) {
                                    HStack {
                                        Text(item.movement.name).font(.figtree(14, .semibold)).foregroundStyle(Palette.ink)
                                        Spacer()
                                        Text("\(item.count) œuvre\(item.count > 1 ? "s" : "")").font(.aSmall).foregroundStyle(Palette.muted)
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(.white)
                                            Capsule().fill(Palette.navy)
                                                .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(maxCount))
                                        }
                                    }
                                    .frame(height: 8)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
                    }

                    settings
                }
                .padding(.horizontal, 24)
                .padding(.top, -30)
                .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .animation(.bouncy, value: user.profile.avatar)
        .fullScreenCover(item: $course) { CourseFlow(artwork: $0) }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallScreen(onClose: { showPaywall = false })
        }
        .confirmationDialog("Recommencer depuis le début ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Tout effacer", role: .destructive) {
                Haptics.warning()
                Reminder.cancelDaily()
                user.resetAll()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Ta série, ta collection et tes réponses seront effacées de cet appareil.")
        }
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.figtree(26, .semibold)).contentTransition(.numericText())
            Text(label).font(.figtree(13, .medium))
        }
        .foregroundStyle(Palette.ink)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(color))
    }

    @ViewBuilder
    private var collection: some View {
        let items = user.profile.favorites.compactMap { content.artwork($0) }
        if items.isEmpty {
            Text("Touche le cœur sur une œuvre pour l'ajouter à ta collection.")
                .font(.aSmall).foregroundStyle(Palette.muted)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(items) { art in
                        Button {
                            course = art
                        } label: {
                            ArtImage(name: art.image)
                                .frame(width: 104, height: 104)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(art.title)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var settings: some View {
        VStack(spacing: 0) {
            Toggle(isOn: Binding(
                get: { user.profile.reminderOn },
                set: { newValue in
                    Haptics.selection()
                    if newValue {
                        Task {
                            let granted = await Reminder.requestPermission()
                            await MainActor.run {
                                user.profile.reminderOn = granted
                                if granted { Reminder.scheduleDaily(atMinutes: user.profile.reminderMinutes) }
                            }
                        }
                    } else {
                        user.profile.reminderOn = false
                        Reminder.cancelDaily()
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rappel quotidien").font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                    Text(formatMinutes(user.profile.reminderMinutes)).font(.aCaption).foregroundStyle(Palette.muted)
                }
            }
            .tint(Palette.navy)
            .frame(minHeight: 56)
            Divider()
            Button {
                if !pro.isPro { showPaywall = true }
            } label: {
                HStack {
                    Text("Artura Pro").font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(pro.isPro ? "Actif" : "Essayer 3 jours").font(.aSmall)
                        .foregroundStyle(pro.isPro ? Palette.green : Palette.navy)
                }
                .frame(minHeight: 56)
            }
            .buttonStyle(.pressable)
            Divider()
            Button {
                confirmReset = true
            } label: {
                HStack {
                    Text("Refaire l'introduction").font(.figtree(15, .semibold)).foregroundStyle(Palette.ink)
                    Spacer()
                    Image(systemName: "arrow.counterclockwise").foregroundStyle(Palette.muted)
                }
                .frame(minHeight: 56)
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
        .padding(.top, 4)
    }
}
