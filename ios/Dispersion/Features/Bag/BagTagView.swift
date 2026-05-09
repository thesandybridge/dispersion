// 3D bag tag — RealityKit (iOS 18+) rebuild of the formerly SceneKit-based
// view. The tag is a thin metallic slab with textured front + back faces
// rendered via SwiftUI's ImageRenderer. Drag to spin around the Y axis;
// material picker switches the metal finish.

import RealityKit
import SwiftData
import SwiftUI

struct BagTagView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]

    /// Optional close handler. When set (i.e., BagTagView is presented as a
    /// full-screen modal), a small "Done" pill appears in the top-leading
    /// corner so the user can dismiss without resorting to a swipe gesture.
    var onClose: (() -> Void)?

    @State private var profile = ProfileStore.shared
    @State private var editing = false
    @State private var shareItem: ShareItem?

    // Rotation state — value types are safe in @State; SwiftUI re-runs
    // RealityView's update: closure when these change.
    @State private var baseRotationY: Float = 0
    @State private var dragRotationY: Float = 0
    // Bumped each time materials/textures need rebuilding (avoids needing
    // @State references to entity instances, which RealityView dislikes).
    @State private var textureRevision: Int = 0

    // Named entities — we look these up in the update: closure rather than
    // holding @State references, which weren't reliable across view rebuilds.
    private static let rootName = "tagRoot"
    private static let frontEntityName = "tagFront"
    private static let backEntityName = "tagBack"
    private static let sideEntityName = "tagSide"

    private var accent: Color { profile.accent.color }
    private var clubs: [Club] { clubModels.map { $0.toValue() } }

    // Tag geometry. With camera at z=1.2 and FOV 30°, visible height is
    // ~2 * 1.2 * tan(15°) ≈ 0.643m, so a tag of 0.50m height fills ~78%
    // of the vertical viewport. We deliberately leave margin so the tag
    // doesn't kiss the safe-area edges when the user spins it.
    private static let tagWidth: Float = 0.32
    private static let tagHeight: Float = 0.50
    /// True extruded thickness of the tag — visible as a metallic edge when
    /// the user spins it. ~5mm reads as a real bag tag.
    private static let tagThickness: Float = 0.005
    /// Outer rounded-corner radius applied to the rounded-rectangle profile.
    /// Bumped from 0.02 so the curves read clearly at the new tag size.
    private static let cornerRadius: Float = 0.04

    var body: some View {
        VStack(spacing: 0) {
            tag3D
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    if let onClose {
                        Button { onClose(); Haptics.light() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Done")
                                    .font(DispersionType.mono(11, weight: .medium))
                            }
                            .floatingPillStyle()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .environment(\.colorScheme, .dark)
                        .accessibilityLabel("Close bag tag")
                    }
                }

            bottomToolbar
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
        }
        .background(DesignTokens.background.ignoresSafeArea())
        .onChange(of: profile.name) { _, _ in refreshTextures() }
        .onChange(of: profile.accent) { _, _ in refreshTextures() }
        .onChange(of: profile.homeCourse) { _, _ in refreshTextures() }
        .onChange(of: profile.motto) { _, _ in refreshTextures() }
        .onChange(of: profile.font) { _, _ in refreshTextures() }
        .onChange(of: profile.contact) { _, _ in refreshTextures() }
        .onChange(of: profile.material) { _, _ in
            applyMaterials()
            refreshTextures()
        }
        .dispersionSheet(isPresented: $editing, detents: [.large]) {
            tagEditContent
        }
        .shareSheet(item: $shareItem)
    }

    // MARK: - Bottom toolbar (floating capsule, course-view aesthetic)

    private var bottomToolbar: some View {
        HStack(spacing: 10) {
            materialClusterPill

            Spacer(minLength: 0)

            // Edit + Share — paired action pills
            Button { editing = true; Haptics.light() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "pencil").font(.system(size: 11, weight: .medium))
                    Text("Edit").font(DispersionType.mono(11, weight: .medium))
                }
                .floatingPillStyle()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit tag")

            Button { shareTag() } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 16, height: 16)
                    .floatingPillStyle()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share tag")
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Material picker (drag-to-select)

    /// Visual constants for the material chip cluster. Kept as private static
    /// so both the layout and the drag-to-index math reference the same numbers.
    private static let chipDiameter: CGFloat = 22
    private static let chipSpacing: CGFloat = 8
    private static let chipClusterHPad: CGFloat = 10

    private var materialClusterPill: some View {
        HStack(spacing: Self.chipSpacing) {
            ForEach(ProfileMaterial.allCases, id: \.self) { mat in
                materialChip(mat)
            }
        }
        .padding(.horizontal, Self.chipClusterHPad)
        .padding(.vertical, 8)
        .background(Capsule().fill(DesignTokens.popover.opacity(0.92)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        // Drag gesture covers the whole pill: a tap fires .onChanged once
        // with zero translation; a drag continuously updates which chip is
        // under the finger, with a haptic on each crossing.
        .contentShape(Capsule())
        .gesture(materialDragGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tag finish")
        .accessibilityValue("\(profile.material)")
        .accessibilityAdjustableAction { direction in
            let cases = ProfileMaterial.allCases
            guard let i = cases.firstIndex(of: profile.material) else { return }
            switch direction {
            case .increment:
                if i + 1 < cases.count {
                    profile.setProfile(material: cases[i + 1])
                    Haptics.light()
                }
            case .decrement:
                if i > 0 {
                    profile.setProfile(material: cases[i - 1])
                    Haptics.light()
                }
            @unknown default: break
            }
        }
    }

    private var materialDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let cases = ProfileMaterial.allCases
                let stepWidth = Self.chipDiameter + Self.chipSpacing
                let firstCenter = Self.chipClusterHPad + Self.chipDiameter / 2
                let rawIndex = Int(
                    ((value.location.x - firstCenter) / stepWidth).rounded()
                )
                let clamped = max(0, min(cases.count - 1, rawIndex))
                let candidate = cases[clamped]
                if profile.material != candidate {
                    profile.setProfile(material: candidate)
                    Haptics.light()
                }
            }
    }

    private func materialChip(_ mat: ProfileMaterial) -> some View {
        let isActive = profile.material == mat
        return Circle()
            .fill(mat.preview)
            .frame(width: Self.chipDiameter, height: Self.chipDiameter)
            .overlay {
                if isActive {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                        .frame(width: Self.chipDiameter - 3, height: Self.chipDiameter - 3)
                } else {
                    Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1)
                }
            }
            .scaleEffect(isActive ? 1.1 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isActive)
    }

    // MARK: - 3D scene

    private var tag3D: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, 0])
            content.add(anchor)

            // Spinning geometry lives on `root`; lights + camera live on
            // `anchor` so rotating root actually changes what's visible.
            let root = Entity()
            root.name = Self.rootName
            anchor.addChild(root)

            // Three separate ModelEntities: front cap, back cap, side wall.
            // Each owns its own MeshResource + single material so RealityKit
            // can't merge or reorder slots — fronts and backs render with
            // their own textures, the side stays brushed metal.
            if let r = BagTagMesh.make(
                width: Self.tagWidth,
                height: Self.tagHeight,
                depth: Self.tagThickness,
                cornerRadius: Self.cornerRadius
            ) {
                let front = ModelEntity(mesh: r.front, materials: [textureMaterial(image: nil)])
                front.name = Self.frontEntityName
                root.addChild(front)

                let back = ModelEntity(mesh: r.back, materials: [textureMaterial(image: nil)])
                back.name = Self.backEntityName
                root.addChild(back)

                let side = ModelEntity(mesh: r.side, materials: [sideMaterial()])
                side.name = Self.sideEntityName
                root.addChild(side)
            }

            // Lighting — sibling to root so spinning the tag doesn't move them.
            let key = DirectionalLight()
            key.light.intensity = 2_500
            key.light.color = .white
            key.shadow = nil
            key.orientation = simd_quatf(angle: -0.3, axis: [1, 0, 0])
                * simd_quatf(angle: 0.4, axis: [0, 1, 0])
            anchor.addChild(key)

            let fill = DirectionalLight()
            fill.light.intensity = 1_200
            fill.light.color = .white
            fill.orientation = simd_quatf(angle: 0.2, axis: [1, 0, 0])
                * simd_quatf(angle: -0.5, axis: [0, 1, 0])
            anchor.addChild(fill)

            // Camera — placed so the tag fills ~78% of the visible height.
            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 30
            camera.position = [0, 0, 1.2]
            anchor.addChild(camera)

            applyTexturesNow(content: content)
        } update: { content in
            // Drive rotation from SwiftUI state.
            if let root = content.findRootEntity(named: Self.rootName) {
                root.orientation = simd_quatf(
                    angle: baseRotationY + dragRotationY,
                    axis: [0, 1, 0]
                )
            }
            // Refresh textures when revision changes (profile edit, material switch).
            _ = textureRevision
            applyTexturesNow(content: content)
        }
        .simultaneousGesture(dragGesture)
    }

    @MainActor
    private func applyTexturesNow(content: RealityViewCameraContent) {
        if let img = renderFrontTexture(),
           let entity = content.findRootEntity(named: Self.frontEntityName) as? ModelEntity {
            entity.model?.materials = [textureMaterial(image: img)]
        }
        if let img = renderBackTexture(),
           let entity = content.findRootEntity(named: Self.backEntityName) as? ModelEntity {
            entity.model?.materials = [textureMaterial(image: img)]
        }
        if let entity = content.findRootEntity(named: Self.sideEntityName) as? ModelEntity {
            entity.model?.materials = [sideMaterial()]
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Convert horizontal drag (in points) to radians. ~360° per
                // 600pt feels natural on phone.
                dragRotationY = Float(value.translation.width) / 600 * 2 * .pi
            }
            .onEnded { _ in
                baseRotationY += dragRotationY
                dragRotationY = 0
            }
    }

    // MARK: - Materials

    private func textureMaterial(image: UIImage?) -> PhysicallyBasedMaterial {
        var mat = PhysicallyBasedMaterial()
        if let cg = image?.cgImage,
           let resource = try? TextureResource(image: cg, options: .init(semantic: .color)) {
            mat.baseColor = .init(texture: .init(resource))
        } else {
            mat.baseColor = .init(tint: profile.material.uiKitEdge)
        }
        // Brushed-metal feel: still metallic but with high roughness to kill
        // mirror-like specular. Reads as classy machined metal, not chrome.
        mat.metallic = 0.85
        mat.roughness = 0.62
        return mat
    }

    /// Material for the rounded side wall — pure brushed metal, no texture.
    /// A touch tighter roughness than the front so the edge catches a hint of
    /// light during a spin without going chrome.
    private func sideMaterial() -> PhysicallyBasedMaterial {
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: profile.material.uiKitEdge)
        mat.metallic = 0.92
        mat.roughness = 0.5
        return mat
    }


    /// Triggers RealityView's update: closure to re-render textures.
    private func refreshTextures() {
        textureRevision &+= 1
    }

    private func applyMaterials() { refreshTextures() }

    // MARK: - Texture generation (SwiftUI ImageRenderer, unchanged from before)

    @MainActor
    private func renderFrontTexture() -> UIImage? {
        let renderer = ImageRenderer(content:
            frontFaceContent
                .frame(width: 300, height: 480)
                .background(LinearGradient(colors: profile.material.texBg, startPoint: .topLeading, endPoint: .bottomTrailing))
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 2
        return renderer.uiImage
    }

    @MainActor
    private func renderBackTexture() -> UIImage? {
        let renderer = ImageRenderer(content:
            backFaceContent
                .frame(width: 300, height: 480)
                .background(LinearGradient(colors: profile.material.texBg, startPoint: .topLeading, endPoint: .bottomTrailing))
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 2
        return renderer.uiImage
    }

    // MARK: - Texture content

    /// Faked grommet hole — drawn into the face textures since RealityKit
    /// can't easily punch a real hole through the mesh. Inner dark fill
    /// reads as a hole; thin metallic ring reads as the eyelet.
    private var grommetOverlay: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.92))
                    .frame(width: 26, height: 26)
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 26, height: 26)
            }
            .padding(.top, 14)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // Front face content (unchanged from SceneKit version — still rendered via SwiftUI)
    private var frontFaceContent: some View {
        let initials = computeInitials(profile.name)

        return ZStack {
            grommetOverlay

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("DISPERSION")
                        .font(.system(size: 7, weight: .semibold, design: .monospaced))
                        .tracking(5)
                        .foregroundStyle(accent.opacity(0.5))
                    Spacer()
                    Text(initials)
                        .font(profile.font.font(size: 15, weight: .bold))
                        .foregroundStyle(accent)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(accent.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(accent.opacity(0.3), lineWidth: 0.5))
                        )
                }

                Spacer().frame(height: 36)

                Text(profile.name.isEmpty ? "YOUR NAME" : profile.name.uppercased())
                    .font(profile.font.font(size: 24, weight: .thin))
                    .tracking(4)
                    .foregroundStyle(Color.white.opacity(profile.material.textOpacity))
                    .lineLimit(2)

                if !profile.homeCourse.isEmpty {
                    Text(profile.homeCourse.uppercased())
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(Color.white.opacity(0.35))
                        .padding(.top, 6)
                }

                Spacer()

                if !profile.motto.isEmpty {
                    Text(profile.motto)
                        .font(profile.font.font(size: 11))
                        .italic()
                        .foregroundStyle(accent.opacity(0.5))
                }

                Rectangle()
                    .fill(LinearGradient(colors: [accent.opacity(0.4), .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 0.5)
                    .padding(.top, 10)

                if !profile.contact.isEmpty {
                    Text(profile.contact)
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.25))
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 54)
            .padding(.bottom, 14)
        }
    }

    private var backFaceContent: some View {
        ZStack {
            grommetOverlay

            VStack(spacing: 0) {
                Spacer().frame(height: 60)
                Spacer()

                Image(systemName: "scope")
                    .font(.system(size: 44, weight: .ultraLight))
                    .foregroundStyle(accent.opacity(0.5))

                Spacer().frame(height: 16)

                Text("DISPERSION")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .tracking(10)
                    .foregroundStyle(Color.white.opacity(0.6))

                Rectangle().fill(accent.opacity(0.3)).frame(width: 40, height: 0.5)
                    .padding(.top, 10)

                Text("YOUR DATA · YOUR GAME")
                    .font(.system(size: 6, weight: .medium, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Color.white.opacity(0.2))
                    .padding(.top, 8)

                Spacer()

                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "qrcode")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.white.opacity(0.1))
                    )

                Text("SCAN TO CONNECT")
                    .font(.system(size: 5, weight: .medium, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Color.white.opacity(0.12))
                    .padding(.top, 6)

                Spacer().frame(height: 24)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func computeInitials(_ name: String) -> String {
        (name.isEmpty ? "—" : name)
            .split(separator: " ").prefix(2)
            .compactMap { $0.first.map { String($0).uppercased() } }
            .joined()
    }

    // MARK: - Share

    @MainActor
    private func shareTag() {
        guard let image = renderFrontTexture() else {
            Haptics.error()
            return
        }
        shareItem = ShareItem(items: [image])
    }

    // MARK: - Edit sheet

    @ViewBuilder
    private var tagEditContent: some View {
        DSheetHeader(eyebrow: "Bag tag", title: "Customize")
        editField("Name", placeholder: "Player name", text: Binding(
            get: { profile.name }, set: { profile.setProfile(name: $0) }
        ))
        editField("Home course", placeholder: "e.g. Augusta National", text: Binding(
            get: { profile.homeCourse }, set: { profile.setProfile(homeCourse: $0) }
        ))
        editField("Motto", placeholder: "Keep it in the short grass", text: Binding(
            get: { profile.motto }, set: { profile.setProfile(motto: $0) }
        ))
        editField("Contact", placeholder: "Phone or email", text: Binding(
            get: { profile.contact }, set: { profile.setProfile(contact: $0) }
        ))

        VStack(alignment: .leading, spacing: 8) {
            Text("Accent").eyebrow()
            HStack(spacing: 10) {
                ForEach(ProfileAccent.allCases, id: \.self) { a in
                    Button { profile.setProfile(accent: a) } label: {
                        Circle().fill(a.color).frame(width: 28, height: 28)
                            .overlay {
                                if profile.accent == a {
                                    Circle().strokeBorder(.white, lineWidth: 2).frame(width: 24, height: 24)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Font").eyebrow()
            HStack(spacing: 8) {
                ForEach(ProfileFont.allCases, id: \.self) { f in
                    Button { profile.setProfile(font: f) } label: {
                        VStack(spacing: 3) {
                            Text("Aa").font(f.font(size: 16, weight: .medium))
                                .frame(width: 48, height: 36)
                                .background(RoundedRectangle(cornerRadius: 8)
                                    .fill(profile.font == f ? DesignTokens.foreground : DesignTokens.surface))
                                .foregroundStyle(profile.font == f ? DesignTokens.background : DesignTokens.foreground)
                            Text(f.label).font(DispersionType.mono(9)).foregroundStyle(DesignTokens.mutedForeground)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        Button { editing = false } label: { Text("Done") }
            .buttonStyle(.dispersion(.solid))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func editField(_ label: String, placeholder: String = "", text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).eyebrow()
            TextField(placeholder, text: text)
                .font(DispersionType.ui(15))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DesignTokens.surface)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(DesignTokens.border, lineWidth: 1))
                )
        }
    }
}

// MARK: - ProfileMaterial → UIColor

private extension ProfileMaterial {
    /// Alias — `edgeColor` already returns a UIColor; this property keeps
    /// callsites readable.
    var uiKitEdge: UIColor { edgeColor }
}

// MARK: - RealityViewCameraContent helper

private extension RealityViewCameraContent {
    /// Walk every top-level entity's subtree until we find one with the
    /// given name. Replaces the @State entity-reference pattern that didn't
    /// survive RealityView rebuilds.
    func findRootEntity(named name: String) -> Entity? {
        for entity in entities {
            if entity.name == name { return entity }
            if let found = entity.findEntity(named: name) { return found }
        }
        return nil
    }
}
