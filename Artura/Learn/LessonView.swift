import SwiftUI

/// Lecture d'un cours bloc par bloc : chaque appui sur « Continuer » révèle le bloc suivant
/// et le fait défiler au centre de l'écran.
struct LessonView: View {
    let artwork: Artwork
    var pill: String = "Cours"
    /// Blocs à lire. Par défaut le cours entier ; l'onboarding en passe un extrait.
    var blocks: [LessonBlock]? = nil
    var finishTitle: String = "Passer au quiz"
    /// Si présent, un bouton « Passer » remplace le compteur en haut à droite.
    var onSkip: (() -> Void)? = nil
    let onBack: () -> Void
    let onFinish: () -> Void

    @Environment(\.lessonLanguage) private var language
    @State private var revealed = 0
    /// Bloc interactif ouvert en plein écran sur le tableau.
    @State private var studio: Int?

    private var lesson: [LessonBlock] { blocks ?? artwork.lesson }
    private var total: Int { lesson.count }
    private var isDone: Bool { revealed >= total }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.pressable)
                .padding(.leading, -12)
                .accessibilityLabel(language.pick("Retour", "Back"))
                ProgressTrack(value: Double(revealed + 1) / Double(total + 1))
                if let onSkip {
                    Button(language.pick("Passer", "Skip")) {
                        Haptics.tap()
                        onSkip()
                    }
                    .font(.figtree(15, .semibold))
                    .foregroundStyle(Palette.muted)
                    .frame(height: 44)
                    .buttonStyle(.pressable)
                } else {
                    Text("\(revealed + 1) / \(total + 1)")
                        .font(.figtree(14, .medium))
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(.horizontal, 24)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            TagPill(text: pill)
                            Text(artwork.title).font(.figtree(28, .semibold)).foregroundStyle(Palette.ink)
                            Text("\(artwork.meta) · \(artwork.museum)").font(.aSmall).foregroundStyle(Palette.muted)
                        }
                        ArtImage(name: artwork.image)
                            .frame(height: 270)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        ForEach(Array(lesson.prefix(revealed).enumerated()), id: \.offset) { index, block in
                            Group {
                                if block.isInteractive {
                                    interactiveCard(block, index: index)
                                } else {
                                    blockView(block)
                                }
                            }
                                .id(index)
                                .transition(.opacity)
                        }
                        // Marge basse : permet au dernier bloc de remonter jusqu'au centre de l'écran.
                        Color.clear.frame(height: 340)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                }
                .scrollIndicators(.hidden)
                .onChange(of: revealed) { _, newValue in
                    guard newValue > 0 else { return }
                    // Le bloc qu'on vient de révéler se place au centre, sans attendre.
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo(newValue - 1, anchor: .center)
                    }
                }
            }

            Button(isDone ? finishTitle : language.pick("Continuer", "Continue")) {
                if isDone {
                    Haptics.success()
                    onFinish()
                } else {
                    Haptics.soft()
                    let index = revealed
                    withAnimation(.easeOut(duration: 0.15)) { revealed += 1 }
                    // Un bloc interactif s'ouvre tout de suite sur le tableau.
                    if lesson.indices.contains(index), lesson[index].isInteractive {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { open(index) }
                    }
                }
            }
            .buttonStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .padding(.top, 8)
        .background(Palette.bg)
        .overlay {
            if let studio, lesson.indices.contains(studio) {
                PaintingStudio(artwork: artwork, block: lesson[studio]) {
                    withAnimation(.easeInOut(duration: 0.3)) { self.studio = nil }
                }
                .id(studio)
                .transition(.opacity)
            }
        }
    }

    private func open(_ index: Int) {
        Haptics.press()
        withAnimation(.easeInOut(duration: 0.3)) { studio = index }
    }

    /// Dans le fil du cours, un bloc interactif laisse une carte qu'on peut rouvrir.
    private func interactiveCard(_ block: LessonBlock, index: Int) -> some View {
        Button {
            open(index)
        } label: {
            HStack(spacing: 14) {
                ArtImage(name: artwork.image, zoom: 1.6, anchor: artwork.focusPoint)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        Image(systemName: block.interactiveIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Palette.blue))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.title(of: block)).font(.aCardTitle).foregroundStyle(.white)
                    Text(language.pick("Touche pour rouvrir le tableau", "Tap to reopen the painting")).font(.aCaption).foregroundStyle(Color.white.opacity(0.75))
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
            }
            .padding(10)
            .padding(.trailing, 6)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x1B1917)))
        }
        .buttonStyle(.pressable)
    }

    @ViewBuilder
    private func blockView(_ block: LessonBlock) -> some View {
        switch block.type {
        case "image":
            VStack(alignment: .leading, spacing: 6) {
                ArtImage(name: artwork.image, zoom: block.zoom ?? 2, anchor: block.unitAnchor)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                if let caption = block.caption {
                    Text(caption).font(.aCaption).foregroundStyle(Palette.muted)
                }
            }
        case "key":
            VStack(alignment: .leading, spacing: 4) {
                Text(language.pick("À retenir", "Key takeaway")).font(.figtree(12, .semibold)).foregroundStyle(Palette.blueText)
                Text(block.text ?? "").font(.bodyStrong).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.sand))
        default:
            Text(block.text ?? "")
                .font(.figtree(17))
                .lineSpacing(5)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
