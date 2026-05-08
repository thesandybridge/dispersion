// 3D bag tag — SceneKit rendered metal tag with punched hole.
// Drag to spin. Material selector: Silver, Black, Gold, Rose Gold.

import SceneKit
import SwiftData
import SwiftUI

enum TagMaterial: String, CaseIterable, Codable {
    case silver, black, gold, roseGold

    var label: String {
        switch self {
        case .silver: return "Silver"
        case .black: return "Black"
        case .gold: return "Gold"
        case .roseGold: return "Rose Gold"
        }
    }
    var baseColor: UIColor {
        switch self {
        case .silver: return UIColor(red: 0.75, green: 0.76, blue: 0.78, alpha: 1)
        case .black: return UIColor(red: 0.12, green: 0.13, blue: 0.14, alpha: 1)
        case .gold: return UIColor(red: 0.83, green: 0.69, blue: 0.42, alpha: 1)
        case .roseGold: return UIColor(red: 0.72, green: 0.45, blue: 0.45, alpha: 1)
        }
    }
    var edgeColor: UIColor {
        switch self {
        case .silver: return UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1)
        case .black: return UIColor(red: 0.2, green: 0.21, blue: 0.22, alpha: 1)
        case .gold: return UIColor(red: 0.88, green: 0.76, blue: 0.5, alpha: 1)
        case .roseGold: return UIColor(red: 0.78, green: 0.52, blue: 0.52, alpha: 1)
        }
    }
    var texBg: [Color] {
        switch self {
        case .silver: return [hex("#4a4d50"), hex("#3a3d40"), hex("#2e3133")]
        case .black: return [hex("#1e2022"), hex("#161819"), hex("#111314")]
        case .gold: return [hex("#5c4a2a"), hex("#4a3b22"), hex("#3a2e1a")]
        case .roseGold: return [hex("#4a2e2e"), hex("#3a2424"), hex("#2e1c1c")]
        }
    }
    var textOpacity: Double {
        self == .black ? 0.85 : 0.95
    }
    var preview: Color {
        Color(baseColor)
    }
}

struct BagTagView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]

    @State private var profile = ProfileStore.shared
    @State private var editing = false
    @State private var scene: SCNScene?
    @State private var material: TagMaterial = .silver

    private var accent: Color { profile.accent.color }
    private var clubs: [Club] { clubModels.map { $0.toValue() } }

    var body: some View {
        VStack(spacing: 0) {
            if let scene {
                SceneView(
                    scene: scene,
                    options: [.allowsCameraControl, .autoenablesDefaultLighting]
                )
                .background(Color.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Material picker
            HStack(spacing: 10) {
                ForEach(TagMaterial.allCases, id: \.self) { mat in
                    Button {
                        material = mat
                        buildScene()
                        Haptics.light()
                    } label: {
                        Circle().fill(mat.preview)
                            .frame(width: 26, height: 26)
                            .overlay {
                                if material == mat {
                                    Circle().strokeBorder(.white, lineWidth: 2).frame(width: 22, height: 22)
                                }
                            }
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)

            HStack(spacing: 12) {
                Button { shareTag() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 12))
                        Text("Share")
                    }
                }
                .buttonStyle(.dispersion(.outline))

                Button { editing = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil").font(.system(size: 12))
                        Text("Edit")
                    }
                }
                .buttonStyle(.dispersion(.primary))
            }
            .padding(.bottom, 12)
        }
        .background(DesignTokens.background.ignoresSafeArea())
        .onAppear { buildScene() }
        .onChange(of: profile.name) { _, _ in buildScene() }
        .onChange(of: profile.accent) { _, _ in buildScene() }
        .onChange(of: profile.homeCourse) { _, _ in buildScene() }
        .onChange(of: profile.motto) { _, _ in buildScene() }
        .onChange(of: profile.font) { _, _ in buildScene() }
        .onChange(of: profile.contact) { _, _ in buildScene() }
        .dispersionSheet(isPresented: $editing, detents: [.large]) {
            tagEditContent
        }
    }

    // MARK: - Build 3D scene

    @MainActor
    private func buildScene() {
        let scn = SCNScene()
        scn.background.contents = UIColor(DesignTokens.background)

        let tagW: CGFloat = 3.0
        let tagH: CGFloat = 4.8
        let tagD: CGFloat = 0.08
        let cornerR: CGFloat = 0.18
        let holeR: CGFloat = 0.18
        let holeY: CGFloat = tagH / 2 - 0.35

        let path = UIBezierPath(roundedRect: CGRect(x: -tagW/2, y: -tagH/2, width: tagW, height: tagH), cornerRadius: cornerR)
        let holePath = UIBezierPath(ovalIn: CGRect(x: -holeR, y: holeY - holeR, width: holeR * 2, height: holeR * 2))
        path.append(holePath.reversing())
        path.flatness = 0.01

        let shape = SCNShape(path: path, extrusionDepth: tagD)

        // Front material
        let frontMat = SCNMaterial()
        frontMat.lightingModel = .physicallyBased
        frontMat.metalness.contents = 0.8
        frontMat.roughness.contents = 0.35
        frontMat.diffuse.contents = renderFrontTexture()

        // Edge material
        let edgeMat = SCNMaterial()
        edgeMat.lightingModel = .physicallyBased
        edgeMat.metalness.contents = 0.95
        edgeMat.roughness.contents = 0.1
        edgeMat.diffuse.contents = material.edgeColor

        // Back material
        let backMat = SCNMaterial()
        backMat.lightingModel = .physicallyBased
        backMat.metalness.contents = 0.8
        backMat.roughness.contents = 0.35
        backMat.diffuse.contents = renderBackTexture()

        // SCNShape materials: [front cap, back cap, extruded side]
        shape.materials = [frontMat, backMat, edgeMat]

        let tagNode = SCNNode(geometry: shape)
        scn.rootNode.addChildNode(tagNode)

        // Camera
        let cam = SCNCamera()
        cam.fieldOfView = 32
        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(0, 0, 10)
        scn.rootNode.addChildNode(camNode)

        // Bright, well-balanced lighting
        let key = SCNLight()
        key.type = .directional
        key.intensity = 1400
        key.color = UIColor(white: 1.0, alpha: 1)
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-0.3, 0.5, 0)
        scn.rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .directional
        fill.intensity = 800
        fill.color = UIColor(white: 0.95, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.eulerAngles = SCNVector3(0.2, -0.6, 0)
        scn.rootNode.addChildNode(fillNode)

        let back = SCNLight()
        back.type = .directional
        back.intensity = 500
        let backNode = SCNNode()
        backNode.light = back
        backNode.eulerAngles = SCNVector3(0.4, Float.pi, 0)
        scn.rootNode.addChildNode(backNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 500
        ambient.color = UIColor(white: 0.8, alpha: 1)
        let ambNode = SCNNode()
        ambNode.light = ambient
        scn.rootNode.addChildNode(ambNode)

        scene = scn
    }

    // MARK: - Textures

    @MainActor
    private func renderFrontTexture() -> UIImage? {
        let renderer = ImageRenderer(content:
            frontFaceContent
                .frame(width: 300, height: 480)
                .background(LinearGradient(colors: material.texBg, startPoint: .topLeading, endPoint: .bottomTrailing))
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
                .background(LinearGradient(colors: material.texBg, startPoint: .topLeading, endPoint: .bottomTrailing))
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 2
        return renderer.uiImage
    }

    // MARK: - Front face

    private var frontFaceContent: some View {
        let initials = computeInitials(profile.name)

        return ZStack {
            // Topo contour lines — flows across lower-right
            topoLines
                .opacity(0.07)

            VStack(alignment: .leading, spacing: 0) {
                // Header
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

                // Name
                Text(profile.name.isEmpty ? "YOUR NAME" : profile.name.uppercased())
                    .font(profile.font.font(size: 24, weight: .thin))
                    .tracking(4)
                    .foregroundStyle(Color.white.opacity(material.textOpacity))
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

    // MARK: - Back face

    private var backFaceContent: some View {
        ZStack {
            topoLines.opacity(0.06)

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

                // QR
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

    // MARK: - Abstract topo lines

    /// Etched topo — flag in the bottom-right corner with smooth contour
    /// lines radiating outward. Lines run right to the tag edge and are
    /// masked with a radial gradient so they fade naturally from the flag.
    private var topoLines: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height

            // Flag position — bottom-right area
            let flagX = w * 0.78
            let flagY = h * 0.88

            // Flag pin
            let poleH = h * 0.08
            var pole = Path()
            pole.move(to: CGPoint(x: flagX, y: flagY))
            pole.addLine(to: CGPoint(x: flagX, y: flagY - poleH))
            ctx.stroke(pole, with: .color(.white), lineWidth: 0.6)

            // Flag pennant
            let ft = CGPoint(x: flagX, y: flagY - poleH)
            var flag = Path()
            flag.move(to: ft)
            flag.addLine(to: CGPoint(x: ft.x + w * 0.035, y: ft.y + h * 0.015))
            flag.addLine(to: CGPoint(x: ft.x, y: ft.y + h * 0.028))
            flag.closeSubpath()
            ctx.fill(flag, with: .color(.white))

            // Green ovals around the flag
            for ring in 0..<3 {
                let r = w * 0.07 + Double(ring) * w * 0.018
                let circle = Path(ellipseIn: CGRect(
                    x: flagX - r, y: flagY - r * 0.8,
                    width: r * 2, height: r * 1.6
                ))
                ctx.stroke(circle, with: .color(.white.opacity(0.9 - Double(ring) * 0.25)), lineWidth: 0.4)
            }

            // Smooth contour arcs — single path per line, clipped by the canvas
            for i in 0..<12 {
                let t = Double(i)
                let spread = (t + 3) * w * 0.035
                var path = Path()
                let steps = 120
                for s in 0...steps {
                    let frac = Double(s) / Double(steps)
                    let angle = Double.pi * (0.15 + frac * 1.7)
                    let baseR = spread + sin(frac * .pi) * spread * 0.12
                    let wobble = sin(frac * .pi * 4.5 + t * 1.3) * w * 0.005

                    let x = flagX + cos(angle) * (baseR + wobble)
                    let y = flagY + sin(angle) * (baseR + wobble) * 0.75

                    if s == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }

                ctx.stroke(path, with: .color(.white), lineWidth: 0.5)
            }
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
        guard let image = renderFrontTexture() else { return }
        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
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

private extension UIColor {
    convenience init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(red: CGFloat((int >> 16) & 0xFF) / 255,
                  green: CGFloat((int >> 8) & 0xFF) / 255,
                  blue: CGFloat(int & 0xFF) / 255, alpha: 1)
    }
}
