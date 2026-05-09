// Custom RealityKit mesh for the bag tag. Produces a single solid extruded
// rounded-rectangle mesh in three sub-meshes (front cap, back cap, side wall),
// each addressable by its own material slot. This replaces the previous
// "two paper-thin planes plus a metallic body box" workaround, which always
// had either a sandwich step at the corners or an invisible edge view.
//
// Why hand-rolled rather than `MeshResource.generateBox(cornerRadius:)`:
// `generateBox` rounds *every* edge by the same radius, so the corner
// rounding we want on the outer x/y corners (~30mm) would also round the
// front/back perimeter, collapsing a thin slab into a flat disc.

import RealityKit
import simd

enum BagTagMesh {

    public struct Resources {
        public let front: MeshResource
        public let back: MeshResource
        public let side: MeshResource
    }

    /// Build three separate mesh resources for an extruded rounded rectangle.
    /// We deliberately don't bundle them into a single multi-submesh
    /// `MeshResource` — RealityKit's behavior with multi-descriptor generate
    /// can collapse material slots, so wrapping each piece in its own
    /// `ModelEntity` is the only reliable way to keep front/back/side materials
    /// independent.
    static func make(
        width: Float,
        height: Float,
        depth: Float,
        cornerRadius: Float,
        cornerSegments: Int = 16
    ) -> Resources? {
        let descriptors = makeDescriptors(
            width: width,
            height: height,
            depth: depth,
            cornerRadius: cornerRadius,
            cornerSegments: cornerSegments
        )
        guard
            let front = try? MeshResource.generate(from: [descriptors[0]]),
            let back = try? MeshResource.generate(from: [descriptors[1]]),
            let side = try? MeshResource.generate(from: [descriptors[2]])
        else { return nil }
        return Resources(front: front, back: back, side: side)
    }

    private static func makeDescriptors(
        width: Float,
        height: Float,
        depth: Float,
        cornerRadius: Float,
        cornerSegments: Int
    ) -> [MeshDescriptor] {
        // Clamp cornerRadius so it stays within the rectangle.
        let r = max(0, min(cornerRadius, min(width, height) / 2))
        let halfW = width / 2
        let halfH = height / 2
        let halfD = depth / 2

        let perimeter = generatePerimeter(
            halfW: halfW, halfH: halfH, r: r, cornerSegments: cornerSegments
        )
        let n = perimeter.count

        // Outward normals at each perimeter vertex, computed by rotating the
        // tangent (next - prev) 90° clockwise so the normal points away from
        // the polygon interior. CCW polygons → outward = right-of-tangent.
        var perimeterNormals: [SIMD2<Float>] = []
        perimeterNormals.reserveCapacity(n)
        for i in 0..<n {
            let prev = perimeter[(i - 1 + n) % n]
            let next = perimeter[(i + 1) % n]
            let tangent = next - prev
            let raw = SIMD2<Float>(tangent.y, -tangent.x)
            let len = simd_length(raw)
            perimeterNormals.append(len > 1e-6 ? raw / len : [1, 0])
        }

        return [
            buildCap(
                perimeter: perimeter, n: n,
                z: halfD, faceNormal: [0, 0, 1],
                halfW: halfW, halfH: halfH,
                width: width, height: height,
                reverseWinding: false,
                mirrorU: false
            ),
            buildCap(
                perimeter: perimeter, n: n,
                z: -halfD, faceNormal: [0, 0, -1],
                halfW: halfW, halfH: halfH,
                width: width, height: height,
                reverseWinding: true,
                mirrorU: true   // back texture would be mirror-imaged otherwise
            ),
            buildSideWall(
                perimeter: perimeter,
                normals: perimeterNormals,
                n: n, halfD: halfD
            ),
        ]
    }

    // MARK: - Perimeter

    /// CCW-walked perimeter of the rounded rectangle, sampled at 4·(cornerSegments+1) points.
    /// Each corner gets `cornerSegments+1` samples covering its quarter arc; consecutive
    /// corners' adjacent points sit at opposite ends of a straight edge, so the polygon
    /// implicitly traces the straight edges as well.
    private static func generatePerimeter(
        halfW: Float, halfH: Float, r: Float, cornerSegments: Int
    ) -> [SIMD2<Float>] {
        let corners: [(SIMD2<Float>, Float)] = [
            ([halfW - r, halfH - r], 0),               // top-right, sweep 0  → π/2
            ([-halfW + r, halfH - r], .pi / 2),        // top-left
            ([-halfW + r, -halfH + r], .pi),           // bottom-left
            ([halfW - r, -halfH + r], 3 * .pi / 2),    // bottom-right
        ]

        var points: [SIMD2<Float>] = []
        points.reserveCapacity(4 * (cornerSegments + 1))
        for (center, startAngle) in corners {
            for i in 0...cornerSegments {
                let t = Float(i) / Float(cornerSegments)
                let a = startAngle + t * (.pi / 2)
                points.append([
                    center.x + r * cos(a),
                    center.y + r * sin(a)
                ])
            }
        }
        return points
    }

    // MARK: - Caps

    private static func buildCap(
        perimeter: [SIMD2<Float>], n: Int,
        z: Float, faceNormal: SIMD3<Float>,
        halfW: Float, halfH: Float,
        width: Float, height: Float,
        reverseWinding: Bool,
        mirrorU: Bool
    ) -> MeshDescriptor {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []

        // Center vertex (index 0).
        positions.append([0, 0, z])
        normals.append(faceNormal)
        uvs.append([0.5, 0.5])

        for p in perimeter {
            positions.append([p.x, p.y, z])
            normals.append(faceNormal)
            // u: 0 at -X (left), 1 at +X (right).
            // v: RealityKit's TextureResource samples a CGImage with v=0 at
            // the BOTTOM row of pixels (GL convention). ImageRenderer outputs
            // a CGImage with row 0 at the top of the rendered SwiftUI view.
            // So to put the rendered "top" of the texture at the top of the
            // tag (p.y = +halfH), we need v = 1 there:
            //   v = (p.y + halfH) / height
            let baseU = (p.x + halfW) / width
            let v = (p.y + halfH) / height
            uvs.append([mirrorU ? 1 - baseU : baseU, v])
        }

        // Fan triangles from center to each consecutive perimeter pair.
        var indices: [UInt32] = []
        indices.reserveCapacity(n * 3)
        for i in 1...n {
            let next = (i % n) + 1   // wraps last → 1
            if reverseWinding {
                indices.append(0)
                indices.append(UInt32(next))
                indices.append(UInt32(i))
            } else {
                indices.append(0)
                indices.append(UInt32(i))
                indices.append(UInt32(next))
            }
        }

        var d = MeshDescriptor(name: reverseWinding ? "back" : "front")
        d.positions = MeshBuffers.Positions(positions)
        d.normals = MeshBuffers.Normals(normals)
        d.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        d.primitives = .triangles(indices)
        return d
    }

    // MARK: - Side wall

    private static func buildSideWall(
        perimeter: [SIMD2<Float>],
        normals perimeterNormals: [SIMD2<Float>],
        n: Int,
        halfD: Float
    ) -> MeshDescriptor {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []

        // For each perimeter vertex we add a pair: front edge (z=+halfD) and
        // back edge (z=-halfD). Outward normal is the same for both.
        positions.reserveCapacity(2 * n)
        for i in 0..<n {
            let p = perimeter[i]
            let nrm2 = perimeterNormals[i]
            let nrm = SIMD3<Float>(nrm2.x, nrm2.y, 0)
            positions.append([p.x, p.y, halfD])
            normals.append(nrm)
            uvs.append([Float(i) / Float(n), 0])
            positions.append([p.x, p.y, -halfD])
            normals.append(nrm)
            uvs.append([Float(i) / Float(n), 1])
        }

        // Two triangles per perimeter edge, wound CCW when viewed from outside.
        var indices: [UInt32] = []
        indices.reserveCapacity(n * 6)
        for i in 0..<n {
            let i0 = UInt32(2 * i)            // front i
            let i1 = UInt32(2 * i + 1)        // back i
            let next = (i + 1) % n
            let i2 = UInt32(2 * next)         // front i+1
            let i3 = UInt32(2 * next + 1)     // back i+1

            // Looking from outside, walking CCW: i0 (top-left) → i1 (bottom-left)
            // → i3 (bottom-right) → i2 (top-right) → back to i0.
            indices.append(i0)
            indices.append(i1)
            indices.append(i3)
            indices.append(i0)
            indices.append(i3)
            indices.append(i2)
        }

        var d = MeshDescriptor(name: "side")
        d.positions = MeshBuffers.Positions(positions)
        d.normals = MeshBuffers.Normals(normals)
        d.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        d.primitives = .triangles(indices)
        return d
    }
}
