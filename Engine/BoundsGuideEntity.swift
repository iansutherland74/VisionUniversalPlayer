#if os(visionOS)
import RealityKit
import UIKit

struct BoundsGuideEntity {
    static let markerName = "immersive.bounds.marker"

    static func make(
        size: SIMD3<Float>,
        markerThickness: Float = 0.012,
        markerLength: Float = 0.12,
        color: UIColor = UIColor(red: 0.22, green: 0.96, blue: 0.76, alpha: 0.95)
    ) -> Entity {
        let root = Entity()
        let material = UnlitMaterial(color: color)
        let half = size / 2
        let xLength = min(markerLength, max(size.x * 0.35, markerThickness))
        let yLength = min(markerLength, max(size.y * 0.35, markerThickness))
        let zLength = min(markerLength, max(size.z * 0.8, markerThickness))

        let corners: [SIMD3<Float>] = [
            [-half.x, -half.y, -half.z],
            [ half.x, -half.y, -half.z],
            [-half.x,  half.y, -half.z],
            [ half.x,  half.y, -half.z],
            [-half.x, -half.y,  half.z],
            [ half.x, -half.y,  half.z],
            [-half.x,  half.y,  half.z],
            [ half.x,  half.y,  half.z]
        ]

        for corner in corners {
            root.addChild(marker(length: xLength, thickness: markerThickness, axis: .x, origin: corner, material: material))
            root.addChild(marker(length: yLength, thickness: markerThickness, axis: .y, origin: corner, material: material))
            root.addChild(marker(length: zLength, thickness: markerThickness, axis: .z, origin: corner, material: material))
        }

        Task {
            await DebugCategory.immersive.traceLog(
                "Created bounds guide entity",
                context: [
                    "sizeX": String(format: "%.3f", size.x),
                    "sizeY": String(format: "%.3f", size.y),
                    "sizeZ": String(format: "%.3f", size.z)
                ]
            )
        }

        return root
    }

    private enum Axis {
        case x
        case y
        case z
    }

    private static func marker(
        length: Float,
        thickness: Float,
        axis: Axis,
        origin: SIMD3<Float>,
        material: UnlitMaterial
    ) -> Entity {
        let mesh: MeshResource
        let offset: SIMD3<Float>

        switch axis {
        case .x:
            mesh = .generateBox(size: [length, thickness, thickness])
            offset = [origin.x < 0 ? length / 2 : -length / 2, 0, 0]
        case .y:
            mesh = .generateBox(size: [thickness, length, thickness])
            offset = [0, origin.y < 0 ? length / 2 : -length / 2, 0]
        case .z:
            mesh = .generateBox(size: [thickness, thickness, length])
            offset = [0, 0, origin.z < 0 ? length / 2 : -length / 2]
        }

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = markerName
        entity.position = origin + offset
        return entity
    }
}
#endif
