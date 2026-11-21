import SwiftUI
import UIKit

/// Le tableau en plein écran, sur fond noir : visite guidée, « trouve-le », lignes de composition,
/// palette et zoom libre. La caméra se déplace dans la toile ; les repères sont dessinés
/// dans le repère du tableau (0…1), donc ils suivent le zoom.
struct PaintingStudio: View {
    let artwork: Artwork
    let block: LessonBlock
    let onDone: () -> Void

    // Caméra : point du tableau placé au centre, et grossissement.
    @State private var center = CGPoint(x: 0.5, y: 0.5)
    @State private var zoom: CGFloat = 1
    // Avancement dans le bloc (0 = vue d'ensemble).
    @State private var step = 0
    @State private var locked = true
    @State private var closing = false
    // « Trouve-le »
    @State private var guess: CGPoint?
    @State private var found: Bool?
    // Palette et zoom libre
    @State private var selected: Int?
    @State private var swatchesShown = 0
    @State private var baseZoom: CGFloat = 1
    @State private var baseCenter = CGPoint(x: 0.5, y: 0.5)
    @State private var pulse = false

    private var spots: [Spot] { block.spots ?? [] }
    private var lines: [GuideLine] { block.lines ?? [] }
    private var swatches: [Swatch] { block.swatches ?? [] }
    private var usesButton: Bool { block.type == "palette" || block.type == "explore" }

    private var imageAspect: CGFloat {
        guard let size = UIImage(named: artwork.canvasImage)?.size, size.height > 0 else { return 0.8 }
        return size.width / size.height
    }

    private var stepCount: Int {
        switch block.type {
        case "tour": return spots.count
        case "lines": return lines.count
        default: return 0
        }
    }

    var body: some View {
        ZStack {
            Color(hex: 0x0E0D0C).ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                GeometryReader { geo in
                    canvas(container: geo.size)
                }
                panel
            }
        }
        .onAppear(perform: start)
    }

    // MARK: Barre du haut

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap()
                finish()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.14)))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Fermer et reprendre le cours")
            HStack(spacing: 6) {
                Image(systemName: block.interactiveIcon).font(.system(size: 13, weight: .semibold))
                Text(block.interactiveTitle).font(.figtree(14, .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(Color.white.opacity(0.14)))
            Spacer()
            if stepCount > 0 {
                HStack(spacing: 5) {
                    ForEach(0..<stepCount, id: \.self) { i in
                        Capsule()
                            .fill(i < step ? Color.white : Color.white.opacity(0.28))
                            .frame(width: i == step - 1 ? 16 : 6, height: 6)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: step)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: Tableau

    private func fitted(in container: CGSize) -> CGSize {
        guard container.width > 0, container.height > 0 else { return .zero }
        if container.width / container.height > imageAspect {
            return CGSize(width: container.height * imageAspect, height: container.height)
        }
        return CGSize(width: container.width, height: container.width / imageAspect)
    }

    /// Empêche la caméra de sortir du tableau.
    private func clamped(_ point: CGPoint, zoom: CGFloat, container: CGSize) -> CGPoint {
        let size = fitted(in: container)
        guard size.width > 0, size.height > 0 else { return point }
        let halfX = container.width / (2 * size.width * zoom)
        let halfY = container.height / (2 * size.height * zoom)
        let x = halfX >= 0.5 ? 0.5 : min(max(point.x, halfX), 1 - halfX)
        let y = halfY >= 0.5 ? 0.5 : min(max(point.y, halfY), 1 - halfY)
        return CGPoint(x: x, y: y)
    }

    private func canvas(container: CGSize) -> some View {
        let size = fitted(in: container)
        let cam = clamped(center, zoom: zoom, container: container)

        let drag = DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard block.type == "explore", size.width > 0 else { return }
                let moved = CGPoint(
                    x: baseCenter.x - value.translation.width / (size.width * zoom),
                    y: baseCenter.y - value.translation.height / (size.height * zoom)
                )
                center = clamped(moved, zoom: zoom, container: container)
            }
            .onEnded { _ in baseCenter = center }
        let pinch = MagnificationGesture()
            .onChanged { value in
                guard block.type == "explore" else { return }
                zoom = min(6, max(1, baseZoom * value))
                center = clamped(center, zoom: zoom, container: container)
            }
            .onEnded { _ in
                baseZoom = zoom
                baseCenter = center
                Haptics.soft()
            }

        return ZStack {
            Image(artwork.canvasImage)
                .resizable()
                .frame(width: size.width, height: size.height)
            overlay(size: size)
                .frame(width: size.width, height: size.height)
        }
        .frame(width: size.width, height: size.height)
        .scaleEffect(zoom)
        .offset(x: (0.5 - cam.x) * size.width * zoom, y: (0.5 - cam.y) * size.height * zoom)
        .frame(width: container.width, height: container.height)
        .clipped()
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { value in
            tapCanvas(at: value.location, container: container)
        })
        .simultaneousGesture(drag.simultaneously(with: pinch))
    }

    /// Repères dessinés dans le repère du tableau.
    @ViewBuilder
    private func overlay(size: CGSize) -> some View {
        switch block.type {
        case "tour":
            if step >= 1, spots.indices.contains(step - 1) {
                SpotMark(spot: spots[step - 1], size: size, zoom: zoom, delay: 0.75)
                    .id(step)
                    .transition(.opacity)
            }
        case "find":
            if let guess {
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 2))
                    .scaleEffect(1 / zoom)
                    .position(x: guess.x * size.width, y: guess.y * size.height)
            }
            if found != nil, let target = spots.first {
                SpotMark(spot: target, size: size, zoom: zoom, delay: 0.75,
                         color: found == true ? Palette.green : Palette.yellow)
                    .transition(.opacity)
            }
        case "lines":
            Color.black.opacity(step >= 1 ? 0.35 : 0)
            ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                if i < step {
                    DrawnLine(line: line, size: size, emphasised: i == step - 1)
                }
            }
        case "palette":
            ForEach(Array(swatches.enumerated()), id: \.offset) { i, swatch in
                Image(swatch.image)
                    .resizable()
                    .frame(width: size.width, height: size.height)
                    .opacity(selected == i ? 1 : 0)
            }
        default:
            ForEach(Array(spots.enumerated()), id: \.offset) { i, spot in
                Button {
                    focus(on: i)
                } label: {
                    ZStack {
                        Circle().fill(Color.white.opacity(selected == i ? 0.0 : 0.25))
                            .frame(width: 44, height: 44)
                            .scaleEffect(pulse ? 1 : 0.7)
                        Circle().fill(selected == i ? Palette.yellow : Color.white)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(Color.black.opacity(0.45), lineWidth: 2))
                    }
                    .frame(width: 48, height: 48)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(spot.title ?? "Détail")
                .scaleEffect(1 / zoom)
                .position(x: spot.x * size.width, y: spot.y * size.height)
            }
        }
    }

    // MARK: Panneau du bas

    private var caption: (title: String?, text: String) {
        switch block.type {
        case "tour":
            if step >= 1, spots.indices.contains(step - 1) {
                return (spots[step - 1].title, spots[step - 1].text ?? "")
            }
            return (nil, block.text ?? "Regarde d'abord le tableau en entier.")
        case "find":
            if let found, let target = spots.first {
                return (found ? "Trouvé !" : "Presque : c'était ici.", target.text ?? "")
            }
            return ("À toi", block.text ?? "")
        case "lines":
            if step >= 1, lines.indices.contains(step - 1) {
                return (lines[step - 1].label, lines[step - 1].text)
            }
            return (nil, block.text ?? "Comment ce tableau est-il construit ?")
        case "palette":
            if let selected, swatches.indices.contains(selected) {
                return (swatches[selected].name, swatches[selected].text)
            }
            return (nil, block.text ?? "Touche une couleur pour voir où elle se cache.")
        default:
            if let selected, spots.indices.contains(selected) {
                return (spots[selected].title, spots[selected].text ?? "")
            }
            return (nil, block.text ?? "Pince pour zoomer, glisse pour te déplacer. Touche une pastille pour un détail.")
        }
    }

    private var hint: String {
        if block.type == "find", found == nil { return "Touche le tableau" }
        let last = (block.type == "find" && found != nil) || (stepCount > 0 && step >= stepCount)
        return last ? "Touche pour reprendre le cours" : "Touche pour continuer"
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if block.type == "palette" {
                HStack(spacing: 10) {
                    ForEach(Array(swatches.enumerated()), id: \.offset) { i, swatch in
                        Button {
                            Haptics.selection()
                            withAnimation(.easeInOut(duration: 0.45)) {
                                selected = selected == i ? nil : i
                            }
                        } label: {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hexString: swatch.hex))
                                .frame(height: 48)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white, lineWidth: selected == i ? 3 : 1)
                                        .opacity(selected == i ? 1 : 0.35)
                                )
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(swatch.name)
                        .opacity(i < swatchesShown ? 1 : 0)
                        .offset(y: i < swatchesShown ? 0 : -40)
                        .scaleEffect(i < swatchesShown ? 1 : 0.5)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                if let title = caption.title {
                    Text(title).font(.figtree(18, .semibold)).foregroundStyle(.white)
                }
                Text(caption.text)
                    .font(.figtree(15))
                    .lineSpacing(3)
                    .foregroundStyle(Color.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .id("\(step)-\(selected ?? -1)-\(found == nil ? 0 : 1)")
            .transition(.opacity)
            Spacer(minLength: 0)
            if usesButton {
                Button("Reprendre le cours") { finish() }
                    .buttonStyle(.primary)
            } else {
                Text(hint)
                    .font(.figtree(13, .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .opacity(locked ? 0 : (pulse ? 1 : 0.45))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: block.type == "palette" ? 236 : 196)
        .background(Color(hex: 0x1B1917))
        .contentShape(Rectangle())
        .onTapGesture {
            if !usesButton, !(block.type == "find" && found == nil) { advance() }
        }
    }

    // MARK: Déroulé

    private func start() {
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }
        unlock(after: 0.7)
        if block.type == "palette" {
            for i in 1...max(1, swatches.count) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + 0.14 * Double(i)) {
                    withAnimation(.easeOut(duration: 0.4)) { swatchesShown = i }
                    Haptics.soft()
                }
            }
        }
    }

    private func unlock(after delay: Double) {
        locked = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 0.3)) { locked = false }
        }
    }

    private func move(to point: CGPoint, zoom target: CGFloat, duration: Double = 0.9) {
        withAnimation(.easeInOut(duration: duration)) {
            center = point
            zoom = target
        }
        baseCenter = point
        baseZoom = target
    }

    private func tapCanvas(at location: CGPoint, container: CGSize) {
        switch block.type {
        case "find":
            if found == nil {
                evaluate(location, container: container)
            } else {
                advance()
            }
        case "explore":
            if selected != nil {
                withAnimation(.easeOut(duration: 0.2)) { selected = nil }
            }
        case "palette":
            break
        default:
            advance()
        }
    }

    /// « Trouve-le » : on compare le toucher à la cible, puis la caméra y va dans tous les cas.
    private func evaluate(_ location: CGPoint, container: CGSize) {
        guard !locked, let target = spots.first else { return }
        let size = fitted(in: container)
        guard size.width > 0 else { return }
        let point = CGPoint(
            x: 0.5 + (location.x - container.width / 2) / size.width,
            y: 0.5 + (location.y - container.height / 2) / size.height
        )
        guard (0...1).contains(point.x), (0...1).contains(point.y) else { return }
        let dx = point.x - target.x
        let dy = (point.y - target.y) * size.height / size.width
        let hit = (dx * dx + dy * dy).squareRoot() <= max((target.r ?? 0.06) * 1.8, 0.08)
        guess = point
        if hit { Haptics.success() } else { Haptics.rigid() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.3)) { found = hit }
            move(to: CGPoint(x: target.x, y: target.y), zoom: CGFloat(target.zoom ?? 2.5))
            unlock(after: 1.5)
        }
    }

    private func advance() {
        guard !locked, !closing else {
            Haptics.whisper()
            return
        }
        switch block.type {
        case "tour":
            if step < spots.count {
                Haptics.press()
                let spot = spots[step]
                withAnimation(.easeOut(duration: 0.25)) { step += 1 }
                move(to: CGPoint(x: spot.x, y: spot.y), zoom: CGFloat(spot.zoom ?? 2.5))
                unlock(after: 1.5)
            } else {
                finish()
            }
        case "lines":
            if step < lines.count {
                Haptics.press()
                withAnimation(.easeOut(duration: 0.3)) { step += 1 }
                unlock(after: 1.2)
            } else {
                finish()
            }
        default:
            finish()
        }
    }

    private func focus(on index: Int) {
        guard spots.indices.contains(index) else { return }
        Haptics.press()
        let spot = spots[index]
        withAnimation(.easeOut(duration: 0.25)) { selected = index }
        move(to: CGPoint(x: spot.x, y: spot.y), zoom: CGFloat(spot.zoom ?? 2.5), duration: 0.7)
    }

    /// On dézoome, puis on rend la main au cours.
    private func finish() {
        guard !closing else { return }
        closing = true
        Haptics.soft()
        withAnimation(.easeOut(duration: 0.25)) {
            step = 0
            selected = nil
            found = nil
            guess = nil
        }
        let wasZoomed = zoom > 1.05
        move(to: CGPoint(x: 0.5, y: 0.5), zoom: 1, duration: 0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + (wasZoomed ? 0.65 : 0.15)) { onDone() }
    }
}

// MARK: - Repère autour d'un détail

/// Assombrit le tableau autour du détail, puis trace le cercle, le cadre ou la flèche.
private struct SpotMark: View {
    let spot: Spot
    let size: CGSize
    let zoom: CGFloat
    var delay: Double = 0
    var color: Color = .white

    @State private var progress: CGFloat = 0
    @State private var dim = false

    private var radius: CGFloat { CGFloat(spot.r ?? 0.07) * size.width }
    private var point: CGPoint { CGPoint(x: spot.x * size.width, y: spot.y * size.height) }
    private var isRect: Bool { spot.shape == "rect" }

    private var frame: CGRect {
        CGRect(x: point.x - radius, y: point.y - radius * (isRect ? 1.35 : 1),
               width: radius * 2, height: radius * 2 * (isRect ? 1.35 : 1))
    }

    var body: some View {
        ZStack {
            if spot.shape == "arrow" {
                Image(systemName: "arrow.down.left")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(Palette.yellow)
                    .shadow(color: .black.opacity(0.6), radius: 3)
                    .scaleEffect(1 / zoom)
                    .position(x: point.x + 30 / zoom, y: point.y - 30 / zoom)
                    .opacity(Double(progress))
            } else {
                HoleShape(hole: frame, rounded: !isRect)
                    .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                    .opacity(dim ? 1 : 0)
                Group {
                    if isRect {
                        RoundedRectangle(cornerRadius: radius * 0.18)
                            .trim(from: 0, to: progress)
                            .stroke(color, style: StrokeStyle(lineWidth: 3 / zoom, lineCap: .round))
                    } else {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(color, style: StrokeStyle(lineWidth: 3 / zoom, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                }
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.5)) { dim = true }
                withAnimation(.easeInOut(duration: 0.7)) { progress = 1 }
                Haptics.rigid()
            }
        }
    }
}

/// Un grand rectangle percé d'un trou : sert à assombrir tout sauf le détail.
private struct HoleShape: Shape {
    let hole: CGRect
    let rounded: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect.insetBy(dx: -rect.width, dy: -rect.height))
        if rounded {
            path.addEllipse(in: hole)
        } else {
            path.addRoundedRect(in: hole, cornerSize: CGSize(width: hole.width * 0.09, height: hole.width * 0.09))
        }
        return path
    }
}

// MARK: - Tracé de composition

private struct DrawnLine: View {
    let line: GuideLine
    let size: CGSize
    let emphasised: Bool

    @State private var progress: CGFloat = 0

    var body: some View {
        PolylineShape(points: line.points, closed: line.closed ?? false)
            .trim(from: 0, to: progress)
            .stroke(emphasised ? Palette.yellow : Color.white.opacity(0.75),
                    style: StrokeStyle(lineWidth: emphasised ? 4 : 2.5, lineCap: .round, lineJoin: .round))
            .shadow(color: .black.opacity(0.5), radius: 2)
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.3), value: emphasised)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0)) { progress = 1 }
                Haptics.rigid()
            }
    }
}

private struct PolylineShape: Shape {
    let points: [[Double]]
    let closed: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let converted = points.filter { $0.count == 2 }.map {
            CGPoint(x: rect.minX + $0[0] * rect.width, y: rect.minY + $0[1] * rect.height)
        }
        guard let first = converted.first else { return path }
        path.move(to: first)
        for point in converted.dropFirst() { path.addLine(to: point) }
        if closed { path.closeSubpath() }
        return path
    }
}
