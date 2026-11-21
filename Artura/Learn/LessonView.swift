import SwiftUI

/// Lecture d'un cours bloc par bloc : chaque appui sur « Continuer » révèle le bloc suivant
/// et le fait défiler au centre de l'écran.
struct LessonView: View {
    let artwork: Artwork
    var pill: String = "Cours"
    let onBack: () -> Void
    let onFinish: () -> Void

    @State private var revealed = 0

    private var total: Int { artwork.lesson.count }
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
                .accessibilityLabel("Retour")
                ProgressTrack(value: Double(revealed + 1) / Double(total + 1))
                Text("\(revealed + 1) / \(total + 1)")
                    .font(.figtree(14, .medium))
                    .foregroundStyle(Palette.muted)
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

                        ForEach(Array(artwork.lesson.prefix(revealed).enumerated()), id: \.offset) { index, block in
                            blockView(block)
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

            Button(isDone ? "Passer au quiz" : "Continuer") {
                if isDone {
                    Haptics.success()
                    onFinish()
                } else {
                    Haptics.soft()
                    withAnimation(.easeOut(duration: 0.15)) { revealed += 1 }
                }
            }
            .buttonStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .padding(.top, 8)
        .background(Color.white)
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
                Text("À retenir").font(.figtree(12, .semibold)).foregroundStyle(Palette.blueText)
                Text(block.text ?? "").font(.bodyStrong).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.blueSoft))
        default:
            Text(block.text ?? "")
                .font(.figtree(17))
                .lineSpacing(5)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
