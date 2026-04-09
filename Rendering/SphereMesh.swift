import Foundation
import Metal
import simd

struct MeshVertex {
    var position: SIMD3<Float>
    var texCoord: SIMD2<Float>
    var normal: SIMD3<Float>
}

final class SphereMesh {
    private(set) var vertexBuffer: MTLBuffer
    private(set) var indexBuffer: MTLBuffer
    private(set) var indexCount: Int

    init?(
        device: MTLDevice,
        segments: Int = 128,
        rings: Int = 64,
        radius: Float = 1.0,
        isHemisphere: Bool = false
    ) {
        guard segments >= 8, rings >= 4 else { return nil }

        let verticalFov: Float = isHemisphere ? (.pi / 2.0) : .pi
        let ringCount = rings

        var vertices: [MeshVertex] = []
        vertices.reserveCapacity((segments + 1) * (ringCount + 1))

        for ring in 0...ringCount {
            let v = Float(ring) / Float(ringCount)
            let theta = v * verticalFov
            let sinTheta = sin(theta)
            let cosTheta = cos(theta)

            for segment in 0...segments {
                let u = Float(segment) / Float(segments)
                let phi = u * 2.0 * .pi
                let sinPhi = sin(phi)
                let cosPhi = cos(phi)

                let pos = SIMD3<Float>(
                    radius * sinTheta * cosPhi,
                    radius * cosTheta,
                    radius * sinTheta * sinPhi
                )

                // Normals are inverted for inside-out sphere viewing.
                let normal = simd_normalize(-pos)
                let tex = SIMD2<Float>(u, v)
                vertices.append(MeshVertex(position: pos, texCoord: tex, normal: normal))
            }
        }

        var indices: [UInt32] = []
        indices.reserveCapacity(rings * segments * 6)

        let rowStride = segments + 1
        for ring in 0..<ringCount {
            for segment in 0..<segments {
                let a = UInt32(ring * rowStride + segment)
                let b = UInt32(ring * rowStride + segment + 1)
                let c = UInt32((ring + 1) * rowStride + segment)
                let d = UInt32((ring + 1) * rowStride + segment + 1)

                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }

        guard
            let vb = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<MeshVertex>.stride),
            let ib = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt32>.stride)
        else {
            return nil
        }

        vb.label = isHemisphere ? "HemisphereVertexBuffer" : "SphereVertexBuffer"
        ib.label = isHemisphere ? "HemisphereIndexBuffer" : "SphereIndexBuffer"

        self.vertexBuffer = vb
        self.indexBuffer = ib
        self.indexCount = indices.count

        Task {
            await DebugCategory.vr.infoLog(
                "Created sphere mesh",
                context: [
                    "segments": String(segments),
                    "rings": String(rings),
                    "radius": String(format: "%.3f", radius),
                    "hemisphere": isHemisphere ? "true" : "false",
                    "indices": String(indices.count)
                ]
            )
        }
    }

    func render(with encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint32,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
    }
}

final class QuadMesh {
    private let vertexBuffer: MTLBuffer
    private let indexBuffer: MTLBuffer

    init?(device: MTLDevice) {
        let vertices: [MeshVertex] = [
            MeshVertex(position: SIMD3<Float>(-1, -1, 0), texCoord: SIMD2<Float>(0, 1), normal: SIMD3<Float>(0, 0, 1)),
            MeshVertex(position: SIMD3<Float>( 1, -1, 0), texCoord: SIMD2<Float>(1, 1), normal: SIMD3<Float>(0, 0, 1)),
            MeshVertex(position: SIMD3<Float>( 1,  1, 0), texCoord: SIMD2<Float>(1, 0), normal: SIMD3<Float>(0, 0, 1)),
            MeshVertex(position: SIMD3<Float>(-1,  1, 0), texCoord: SIMD2<Float>(0, 0), normal: SIMD3<Float>(0, 0, 1))
        ]
        let indices: [UInt16] = [0, 1, 2, 0, 2, 3]

        guard
            let vb = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<MeshVertex>.stride),
            let ib = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride)
        else {
            return nil
        }

        vertexBuffer = vb
        indexBuffer = ib

        Task {
            await DebugCategory.renderer.traceLog("Created quad mesh")
        }
    }

    func render(with encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
    }
}
