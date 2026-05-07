// Persistent bottom-right radial speed dial. Two interaction modes:
//
//   • Tap     → fans an arc of route-specific action satellites (read from DialStore)
//   • Drag    → reveals a horizontal route track above the FAB; release to navigate
//
// Direct port of app/src/components/range/RadialDial.tsx, but using
// SwiftUI primitives (DragGesture, withAnimation, AnyTransition, etc.).

import SwiftUI

public struct RadialDial: View {
    @Environment(\.themeAccent) private var accent
    @Binding public var route: AppRoute
    @State private var dial = DialStore.shared
    public var disabledRoutes: Set<AppRoute> = []

    @State private var open: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var dragging: Bool = false
    @State private var hoverIndex: Int = -1
    @State private var hoveredActionId: String?

    // Geometry constants
    private let fabSize: CGFloat = 56
    private let itemSize: CGFloat = 48
    private let radius: CGFloat = 160
    private let startDeg: Double = 90
    private let endDeg: Double = 180

    // Joystick layout
    private let routeIconSize: CGFloat = 44
    private let routeGap: CGFloat = 16
    private var routeSlot: CGFloat { routeIconSize + routeGap }
    private let routeTrigger: CGFloat = 18

    public init(route: Binding<AppRoute>, disabledRoutes: Set<AppRoute> = []) {
        self._route = route
        self.disabledRoutes = disabledRoutes
    }

    public var body: some View {
        ZStack {
            // Scrim while open
            if open {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { open = false } }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    hub
                        .padding(.trailing, 16)
                        .padding(.bottom, 64)
                }
            }

            // Joystick route track (rendered over the scrim, around the FAB)
            if dragging {
                routeTrack
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    .padding(.trailing, 16)
                    .padding(.bottom, 64)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: open)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: dragging)
        .ignoresSafeArea(edges: .horizontal)
    }

    // MARK: hub (FAB + satellites)

    private var hub: some View {
        ZStack {
            // Satellites
            if open {
                ForEach(Array(dial.actions.enumerated()), id: \.element.id) { i, action in
                    let n = max(dial.actions.count, 1)
                    let span = endDeg - startDeg
                    let step = n == 1 ? 0 : span / Double(n - 1)
                    let deg = startDeg + step * Double(i)
                    let rad = deg * .pi / 180
                    let dx = cos(rad) * Double(radius)
                    let dy = -sin(rad) * Double(radius)

                    DialItemView(
                        action: action,
                        isHovered: hoveredActionId == action.id
                    ) {
                        Haptics.medium()
                        action.perform()
                        withAnimation { open = false }
                    } onHover: { hovered in
                        if hovered { Haptics.light() }
                        hoveredActionId = hovered ? action.id : (hoveredActionId == action.id ? nil : hoveredActionId)
                    }
                    .frame(width: itemSize, height: itemSize)
                    .offset(x: CGFloat(dx), y: CGFloat(dy))
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.78)
                            .delay(Double(i) * 0.03),
                        value: open
                    )
                }
            }

            // Caption above the FAB while open
            if open, let label = (dial.actions.first(where: { $0.id == hoveredActionId }) ?? dial.actions.first)?.label {
                Text(label)
                    .font(DispersionType.mono(10, weight: .medium))
                    .tracking(1.8)
                    .textCase(.uppercase)
                    .foregroundStyle(DesignTokens.background)
                    .fixedSize()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(DesignTokens.foreground))
                    .offset(y: -fabSize - 8)
                    .transition(.opacity.combined(with: .offset(y: 4)))
            }

            // FAB
            fab
        }
    }

    private var fab: some View {
        ZStack {
            // Halo while idle.
            Circle()
                .strokeBorder(accent.opacity(0.3), lineWidth: 1)
                .padding(-4)
                .opacity(open || dragging ? 0 : 0.7)

            // Body
            Circle()
                .fill(open || dragging ? DesignTokens.foreground : accent)
                .overlay(Circle().strokeBorder(accent.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 8)

            // Glyph
            Image(systemName: open ? "xmark" : "scope")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(open || dragging ? DesignTokens.background : DesignTokens.primaryForeground)
                .rotationEffect(.degrees(open ? 90 : 0))
                .animation(.spring(response: 0.3, dampingFraction: 0.78), value: open)
        }
        .frame(width: fabSize, height: fabSize)
        .scaleEffect(dragging ? 0.96 : 1)
        .offset(x: dragOffset.width, y: dragOffset.height)
        .gesture(joystickGesture)
        .onTapGesture {
            if !dragging {
                Haptics.light()
                if !dial.actions.isEmpty {
                    withAnimation { open.toggle() }
                }
            }
        }
    }

    // MARK: joystick gesture

    private var joystickGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if !dragging {
                    dragging = true
                    open = false
                    hoverIndex = -1
                    Haptics.light()
                }
                let raw = clampOffset(value.translation)
                dragOffset = raw
                let newIndex = closestRouteIndex(forX: raw.width)
                if newIndex != hoverIndex {
                    if newIndex >= 0 { Haptics.light() }
                    hoverIndex = newIndex
                }
            }
            .onEnded { _ in
                let chosen = hoverIndex
                let movedFar = abs(dragOffset.width) >= routeTrigger || abs(dragOffset.height) >= routeTrigger
                if movedFar, chosen >= 0, AppRoute.allCases[chosen] != route, !disabledRoutes.contains(AppRoute.allCases[chosen]) {
                    Haptics.success()
                    route = AppRoute.allCases[chosen]
                } else {
                    Haptics.light()
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    dragOffset = .zero
                    dragging = false
                    hoverIndex = -1
                }
            }
    }

    private func clampOffset(_ t: CGSize) -> CGSize {
        let xMin = -CGFloat(routeSlot) * CGFloat(AppRoute.allCases.count) - 12
        let xMax: CGFloat = 24
        let yMin: CGFloat = -18
        let yMax: CGFloat = 18
        let cx = min(max(t.width, xMin), xMax)
        let cy = min(max(t.height, yMin), yMax)
        return CGSize(width: cx, height: cy)
    }

    /// FAB is dragged left to slot positions. Slot i sits at x = -(i+1)*routeSlot.
    private func closestRouteIndex(forX x: CGFloat) -> Int {
        var best = -1
        var bestDist = CGFloat.infinity
        let snapRadius = routeSlot / 2 + 4
        for (i, r) in AppRoute.allCases.enumerated() {
            if disabledRoutes.contains(r) { continue }
            let slotX: CGFloat = -CGFloat(i + 1) * routeSlot
            let d = abs(slotX - x)
            if d < bestDist {
                bestDist = d
                best = i
            }
        }
        return bestDist <= snapRadius ? best : -1
    }

    // MARK: route track

    private var routeTrack: some View {
        ZStack {
            ForEach(Array(AppRoute.allCases.enumerated()), id: \.element) { i, r in
                let isCurrent = r == route
                let isHover = hoverIndex == i
                let isDisabled = disabledRoutes.contains(r)

                ZStack {
                    Circle()
                        .fill(
                            isDisabled
                                ? DesignTokens.card.opacity(0.4)
                                : (isHover ? accent
                                   : isCurrent ? DesignTokens.card : DesignTokens.card.opacity(0.7))
                        )
                        .overlay(
                            Circle().strokeBorder(
                                isHover
                                    ? accent
                                    : DesignTokens.border,
                                lineWidth: 1
                            )
                        )
                        .shadow(
                            color: isHover ? accent.opacity(0.18) : .clear,
                            radius: 4
                        )

                    Image(systemName: r.systemImage)
                        .font(.system(size: 18, weight: isHover ? .semibold : .regular))
                        .foregroundStyle(
                            isDisabled
                                ? DesignTokens.mutedForeground.opacity(0.5)
                                : (isHover ? DesignTokens.primaryForeground
                                   : isCurrent ? DesignTokens.foreground : DesignTokens.mutedForeground)
                        )

                }
                .frame(width: routeIconSize, height: routeIconSize)
                .overlay(alignment: .top) {
                    if isHover {
                        Text(r.label)
                            .font(DispersionType.mono(10, weight: .medium))
                            .tracking(1.6)
                            .textCase(.uppercase)
                            .fixedSize()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(DesignTokens.foreground))
                            .foregroundStyle(DesignTokens.background)
                            .offset(y: -24)
                            .transition(.opacity)
                    }
                }
                .scaleEffect(isHover ? 1.12 : 1)
                // Position track icons up + to the left of the FAB
                .offset(
                    x: -(CGFloat(i + 1) * routeSlot) + (fabSize - routeIconSize) / 2,
                    y: -(fabSize + 12)
                )
            }
        }
    }
}

// MARK: dial item

private struct DialItemView: View {
    @Environment(\.themeAccent) private var accent
    let action: DialAction
    let isHovered: Bool
    let onTap: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(background)
                    .overlay(Circle().strokeBorder(borderColor, lineWidth: 1))
                    .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 4)

                Image(systemName: action.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(foreground)
            }
        }
        .buttonStyle(.plain)
        .disabled(action.isDisabled)
        .opacity(action.isDisabled ? 0.4 : 1)
        .onHover { onHover($0) }
        .scaleEffect(isHovered ? 1.05 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.85), value: isHovered)
    }

    private var background: Color {
        switch action.tone {
        case .primary:  return accent
        case .danger:   return DesignTokens.destructive
        case .default:  return DesignTokens.card
        }
    }
    private var foreground: Color {
        switch action.tone {
        case .primary:  return DesignTokens.primaryForeground
        case .danger:   return DesignTokens.foreground
        case .default:  return DesignTokens.foreground
        }
    }
    private var borderColor: Color {
        switch action.tone {
        case .primary:  return accent.opacity(0.4)
        case .danger:   return DesignTokens.destructive.opacity(0.4)
        case .default:  return DesignTokens.border
        }
    }
}

// MARK: haptics

enum Haptics {
    static func light() {
        #if canImport(UIKit)
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
        #endif
    }
    static func medium() {
        #if canImport(UIKit)
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.impactOccurred()
        #endif
    }
    static func success() {
        #if canImport(UIKit)
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
        #endif
    }
    static func error() {
        #if canImport(UIKit)
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.error)
        #endif
    }
}
