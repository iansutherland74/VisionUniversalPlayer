#if os(visionOS)
import RealityKit
import simd

extension MeshResource {
    static func generateCurvedPanel(
        width: Float,
        height: Float,
        radius: Float,
        radialSegments: Int = 32,
        verticalSegments: Int = 8
    ) throws -> MeshResource {
        let clampedRadialSegments = max(radialSegments, 2)
        let clampedVerticalSegments = max(verticalSegments, 1)
        let arcAngle = min(width / max(radius, 0.001), .pi * 0.9)

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var textureCoordinates: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        positions.reserveCapacity((clampedRadialSegments + 1) * (clampedVerticalSegments + 1))
        normals.reserveCapacity((clampedRadialSegments + 1) * (clampedVerticalSegments + 1))
        textureCoordinates.reserveCapacity((clampedRadialSegments + 1) * (clampedVerticalSegments + 1))
        indices.reserveCapacity(clampedRadialSegments * clampedVerticalSegments * 6)

        for verticalIndex in 0...clampedVerticalSegments {
            let v = Float(verticalIndex) / Float(clampedVerticalSegments)
            let y = (0.5 - v) * height

            for radialIndex in 0...clampedRadialSegments {
                let u = Float(radialIndex) / Float(clampedRadialSegments)
                let angle = (u - 0.5) * arcAngle
                let x = sin(angle) * radius
                let z = cos(angle) * radius - radius
                let normal = simd_normalize(SIMD3<Float>(sin(angle), 0, cos(angle)))

                positions.append(SIMD3<Float>(x, y, z))
                normals.append(normal)
                textureCoordinates.append(SIMD2<Float>(u, v))
            }
        }

        let stride = clampedRadialSegments + 1
        for verticalIndex in 0..<clampedVerticalSegments {
            for radialIndex in 0..<clampedRadialSegments {
                let topLeft = UInt32(verticalIndex * stride + radialIndex)
                let topRight = topLeft + 1
                let bottomLeft = UInt32((verticalIndex + 1) * stride + radialIndex)
                let bottomRight = bottomLeft + 1

                indices.append(contentsOf: [topLeft, bottomLeft, topRight])
                indices.append(contentsOf: [topRight, bottomLeft, bottomRight])
            }
        }

        var descriptor = MeshDescriptor(name: "CurvedPanel")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(textureCoordinates)
        descriptor.primitives = .triangles(indices)
        let mesh = try MeshResource.generate(from: [descriptor])
        Task {
            await DebugCategory.immersive.infoLog(
                "Generated curved panel mesh",
                context: [
                    "width": String(format: "%.3f", width),
                    "height": String(format: "%.3f", height),
                    "radius": String(format: "%.3f", radius),
                    "radialSegments": String(clampedRadialSegments),
                    "verticalSegments": String(clampedVerticalSegments)
                ]
            )
        }
        return mesh
    }
}
#endif
