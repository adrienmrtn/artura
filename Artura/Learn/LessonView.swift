import SwiftUI

/// Lecture d'un cours bloc par bloc : chaque appui sur « Continuer » révèle le bloc suivant
/// et le fait défiler au centre de l'écran.
struct LessonView: View {
    let artwork: Artwork
    var pill: String = "Cours"
    let onBack: () -> Void
    let onFinish: () -> Void

    @State private var revealed = 0
    @State private var scrolled = false

    private var total: Int { artwork.lesson.count }
    private var isDone: Bool { revealed >= total }

    var body: some View {
        NavigationStack {
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
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(y: 16)),
                                    removal: .opacity
                                ))
                        }
                        // Marge basse : permet au dernier bloc de remonter jusqu'au centre de l'écran.
                        Color.clear.frame(height: 340)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .scrollProbe()
                }
                .scrollIndicators(.hidden)
                .onChange(of: revealed) { _, newValue in
                    guard newValue > 0 else { return }
                    // Le bloc qu'on vient de révéler se place au centre.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(newValue - 1, anchor: .center)
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        Haptics.rigid()
                    }
                }
            }
            .background(Color.white)
            .safeAreaInset(edge: .top, spacing: 0) {
                ProgressTrack(value: Double(revealed + 1) / Double(total + 1))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(isDone ? "Passer au quiz" : "Continuer") {
                    if isDone {
                        Haptics.success()
                        onFinish()
                    } else {
                        Haptics.soft()
                        withAnimation(.gentle) { revealed += 1 }
                    }
                }
                .buttonStyle(.primary)
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .background(.bar)
            }
            .nativeHeader(artwork.title, scrolled: $scrolled, threshold: 70)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.tap()
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                    }
                    .accessibilityLabel("Retour")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(revealed + 1) / \(total + 1)")
                        .font(.figtree(14, .medium))
                        .foregroundStyle(Palette.muted)
                        .contentTransition(.numericText())
                }
            }
        }
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
