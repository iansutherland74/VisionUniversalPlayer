#if os(visionOS)
import RealityKit
import UIKit

enum OutlinedModelEntity {
    static let outlineMarkerName = "immersive.screen.outline"

    static func make(
        mesh: MeshResource,
        fillColor: UIColor = .white,
        outlineColor: UIColor = UIColor(red: 0.16, green: 0.84, blue: 0.92, alpha: 0.22),
        outlineScale: SIMD3<Float> = SIMD3<Float>(repeating: 1.018)
    ) -> Entity {
        let root = Entity()

        let fill = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: fillColor)])
        let outline = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: outlineColor)])
        outline.name = outlineMarkerName
        outline.scale = outlineScale
        outline.position.z = -0.002

        root.addChild(outline)
        root.addChild(fill)
        Task {
            await DebugCategory.immersive.traceLog(
                "Created outlined model entity",
                context: ["marker": outlineMarkerName]
            )
        }
        return root
    }
}
#endif
