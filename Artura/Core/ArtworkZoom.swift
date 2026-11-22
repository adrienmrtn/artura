import SwiftUI
import UIKit

// Full-screen viewer for a painting: pinch to zoom, double tap to zoom in and out, drag to move.

/// What the viewer shows: the picture, and a lighter version to display while the large one loads.
struct ZoomTarget: Identifiable {
    let image: String
    var placeholder: String? = nil
    var title: String? = nil
    var id: String { image }
}

extension ZoomTarget {
    init(_ artwork: Artwork) {
        self.init(image: artwork.canvasImage, placeholder: artwork.image, title: artwork.title)
    }
}

extension View {
    /// A tap opens the painting full screen, where it can be zoomed.
    func zoomable(_ artwork: Artwork) -> some View {
        modifier(ZoomableModifier(target: ZoomTarget(artwork)))
    }

    /// Presents the full-screen viewer when `target` is set.
    func zoomViewer(_ target: Binding<ZoomTarget?>) -> some View {
        fullScreenCover(item: target) { ZoomViewer(target: $0) }
    }
}

private struct ZoomableModifier: ViewModifier {
    let target: ZoomTarget
    @State private var shown: ZoomTarget?

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.tap()
                shown = target
            }
            .zoomViewer($shown)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(L("Opens the painting full screen"))
    }
}

struct ZoomViewer: View {
    let target: ZoomTarget
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let image {
                ZoomScrollView(image: image)
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.18)))
            }
            .buttonStyle(.pressable)
            .padding(.trailing, 16)
            .padding(.top, 8)
            .accessibilityLabel(L("Close"))
        }
        .task { await load() }
        .accessibilityLabel(target.title ?? L("Painting"))
    }

    /// Shows what is already at hand at once, then the large picture when it arrives.
    private func load() async {
        guard target.image.hasPrefix("http") else {
            image = UIImage(named: target.image) ?? target.placeholder.flatMap { UIImage(named: $0) }
            return
        }
        if let ready = ImageStore.shared.cached(target.image) {
            image = ready
            return
        }
        if let placeholder = target.placeholder {
            image = ImageStore.shared.cached(placeholder)
        }
        if let large = await ImageStore.shared.load(target.image) {
            withAnimation(.easeInOut(duration: 0.2)) { image = large }
        } else if image == nil, let placeholder = target.placeholder {
            image = await ImageStore.shared.load(placeholder)
        }
    }
}

/// The classic zoom: a scroll view around the picture.
private struct ZoomScrollView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 6
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.backgroundColor = .black
        scroll.bouncesZoom = true

        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = true
        scroll.addSubview(view)
        context.coordinator.imageView = view
        context.coordinator.scroll = scroll

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        guard let view = context.coordinator.imageView else { return }
        if view.image !== image {
            // The large picture replaces the light one: same place, same zoom.
            view.image = image
        }
        DispatchQueue.main.async { context.coordinator.layout() }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scroll: UIScrollView?
        private var laidOut: CGSize = .zero

        /// The picture fills the screen at zoom 1 (the image view letterboxes it).
        func layout() {
            guard let scroll, let imageView, scroll.bounds.size != laidOut, scroll.bounds.width > 0 else { return }
            laidOut = scroll.bounds.size
            scroll.zoomScale = 1
            imageView.frame = CGRect(origin: .zero, size: scroll.bounds.size)
            scroll.contentSize = scroll.bounds.size
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        @objc func doubleTapped(_ gesture: UITapGestureRecognizer) {
            guard let scroll, let imageView else { return }
            if scroll.zoomScale > 1.01 {
                scroll.setZoomScale(1, animated: true)
            } else {
                // Zoom in on the point that was tapped.
                let point = gesture.location(in: imageView)
                let scale: CGFloat = 3
                let size = CGSize(width: scroll.bounds.width / scale, height: scroll.bounds.height / scale)
                scroll.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                       width: size.width, height: size.height), animated: true)
            }
            Haptics.soft()
        }
    }
}
