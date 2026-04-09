#if os(visionOS)
import SwiftUI
import CoreMedia
import RealityKit

@available(visionOS 1.0, *)
struct ImmersivePlayerScene: View {
    let playerViewModel: PlayerViewModel
    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    @AppStorage("immersive.controls.distance") private var controlsDistance = 0.9
    @AppStorage("immersive.controls.height") private var controlsHeight = -0.28
    @AppStorage("immersive.controls.tilt") private var controlsTilt = -18.0
    @AppStorage("immersive.debug.bounds") private var showBoundsGuides = false
    @AppStorage("immersive.debug.bounds.scale") private var boundsGuideScale = 1.0
    @AppStorage("immersive.effects.shaderPulse") private var shaderPulseEnabled = true
    @AppStorage("immersive.effects.shaderPulseSpeed") private var shaderPulseSpeed = 1.2
    @AppStorage("immersive.display.autoRotate") private var displayAutoRotateEnabled = false
    @AppStorage("immersive.display.autoRotateSpeed") private var displayAutoRotateSpeed = 18.0
    @State private var rootEntity = Entity()
    @State private var contentAnchor = Entity()
    @State private var controlsAnchor = Entity()
    @State private var modeEntity = Entity()
    @State private var controlsBoundsGuide = Entity()
    @State private var lastSnapshotTime: TimeInterval = 0
    @State private var lastAutoRotateTime: TimeInterval = 0
    @State private var autoRotateYaw: Float = 0
    @State private var headTracker = HeadTracker()
    @State private var apmpInjector = APMPFrameInjector()
    @StateObject private var visionUIRenderer: VisionUIRenderer

    init(playerViewModel: PlayerViewModel) {
        self.playerViewModel = playerViewModel
        _visionUIRenderer = StateObject(wrappedValue: VisionUIRenderer(playerViewModel: playerViewModel))
    }

    var body: some View {
        RealityView { content, attachments in
            content.add(rootEntity)
            rootEntity.addChild(contentAnchor)
            rootEntity.addChild(controlsAnchor)
            contentAnchor.addChild(modeEntity)
            controlsAnchor.addChild(controlsBoundsGuide)

            if let controls = attachments.entity(for: "ImmersiveControls") {
                controlsAnchor.addChild(controls)
            }

            headTracker.start(content: content) { _ in
                guard let headTransform = headTracker.transform else { return }
                let headPosition = simd_make_float3(headTransform.columns.3)
                rootEntity.position = headPosition
            }

            configureModeEntity()
            applyModeTransform()
            updateDisplayRotation(now: CACurrentMediaTime())
            applyControlPanelTransform()
            configureBoundsGuides()
            animateShaderPulseMaterials(at: CACurrentMediaTime())
        } update: { _, _ in
            let now = CACurrentMediaTime()
            visionUIRenderer.pixelBuffer = playerViewModel.currentPixelBuffer
            visionUIRenderer.refreshFromPlayerState()
            enqueueNativeStereoFrameIfNeeded()
            configureModeEntity()
            applyModeTransform()
            updateDisplayRotation(now: now)
            applyControlPanelTransform()
            configureBoundsGuides()
            animateShaderPulseMaterials(at: now)
            publishSnapshotIfNeeded(now: now)
        } attachments: {
            Attachment(id: "ImmersiveControls") {
                VRControlsView(playerModel: playerViewModel)
                    .frame(width: 420)
            }
        }
        .onDisappear {
            sceneCoordinator.immersiveSceneDidDisappear()
            playerViewModel.clearImmersiveSnapshot()
            headTracker.stop()
            apmpInjector.flush()
        }
        .onAppear {
            sceneCoordinator.immersiveSceneDidAppear()
        }
    }

    private func configureModeEntity() {
        let mode = playerViewModel.selectedMode
        modeEntity.removeFromParent()

        let nextEntity: Entity

        let media = playerViewModel.currentMedia
        let framePacking = media?.resolvedFramePacking ?? .none
        let projection = media?.resolvedProjection ?? .rectangular
        // VideoPlayerComponent(videoRenderer:) requires visionOS 2.0
        let useNativeStereoComponent: Bool
        if #available(visionOS 2.0, *) {
            useNativeStereoComponent = framePacking != .none
        } else {
            useNativeStereoComponent = false
        }

        switch mode {
        case .flat, .sbs, .tab, .convert2DTo3D:
            if useNativeStereoComponent {
                let entity = Entity()
                var component = VideoPlayerComponent(videoRenderer: apmpInjector.renderer)
                component.desiredViewingMode = .stereo
                component.desiredImmersiveViewingMode = .full
                entity.components[VideoPlayerComponent.self] = component
                nextEntity = entity
            } else {
                let curvedPanelMesh = (try? MeshResource.generateCurvedPanel(
                    width: 2.2,
                    height: 1.25,
                    radius: 3.6,
                    radialSegments: 36,
                    verticalSegments: 10
                )) ?? .generatePlane(width: 2.2, depth: 1.25)
                nextEntity = OutlinedModelEntity.make(mesh: curvedPanelMesh)
            }

        case .vr180:
            if useNativeStereoComponent, case .equirectangular = projection {
                let entity = Entity()
                var component = VideoPlayerComponent(videoRenderer: apmpInjector.renderer)
                component.desiredViewingMode = .stereo
                component.desiredImmersiveViewingMode = .full
                entity.components[VideoPlayerComponent.self] = component
                nextEntity = entity
            } else {
                let dome = ModelEntity(mesh: .generateSphere(radius: 2.5), materials: [UnlitMaterial(color: .white)])
                dome.scale = [1, 1, -1]
                nextEntity = dome
            }

        case .vr360:
            if useNativeStereoComponent, case .equirectangular = projection {
                let entity = Entity()
                var component = VideoPlayerComponent(videoRenderer: apmpInjector.renderer)
                component.desiredViewingMode = .stereo
                component.desiredImmersiveViewingMode = .full
                entity.components[VideoPlayerComponent.self] = component
                nextEntity = entity
            } else {
                let sphere = ModelEntity(mesh: .generateSphere(radius: 3.5), materials: [UnlitMaterial(color: .white)])
                sphere.scale = [1, 1, -1]
                nextEntity = sphere
            }
        }

        modeEntity = nextEntity
        contentAnchor.addChild(nextEntity)
    }

    private func configureBoundsGuides() {
        controlsBoundsGuide.removeFromParent()
        controlsBoundsGuide = Entity()

        guard showBoundsGuides else { return }

        let controlsGuide = BoundsGuideEntity.make(
            size: [0.58 * Float(boundsGuideScale), 0.34 * Float(boundsGuideScale), 0.04 * Float(boundsGuideScale)],
            markerThickness: 0.008,
            markerLength: 0.08,
            color: UIColor(red: 0.33, green: 0.93, blue: 0.82, alpha: 0.95)
        )
        controlsBoundsGuide = controlsGuide
        controlsAnchor.addChild(controlsGuide)

        if playerViewModel.selectedMode == .flat || playerViewModel.selectedMode == .sbs || playerViewModel.selectedMode == .tab || playerViewModel.selectedMode == .convert2DTo3D {
            let contentGuide = BoundsGuideEntity.make(
                size: [2.2 * Float(boundsGuideScale), 1.25 * Float(boundsGuideScale), 0.08 * Float(boundsGuideScale)],
                markerThickness: 0.012,
                markerLength: 0.16,
                color: UIColor(red: 0.98, green: 0.64, blue: 0.28, alpha: 0.92)
            )
            modeEntity.addChild(contentGuide)
        }
    }

    private func animateShaderPulseMaterials(at time: TimeInterval) {
        guard shaderPulseEnabled else { return }

        let phase = sin(time * shaderPulseSpeed * 2 * .pi)
        let normalized = CGFloat((phase + 1) / 2)

        let outlineAlpha = 0.12 + (0.28 * normalized)
        let outlineColor = UIColor(red: 0.16, green: 0.84, blue: 0.92, alpha: outlineAlpha)

        let guideAlpha = 0.25 + (0.45 * normalized)
        let guideColor = UIColor(red: 0.33, green: 0.93, blue: 0.82, alpha: guideAlpha)

        updateTaggedMaterials(in: modeEntity, tag: OutlinedModelEntity.outlineMarkerName, color: outlineColor)
        updateTaggedMaterials(in: controlsAnchor, tag: BoundsGuideEntity.markerName, color: guideColor)
        updateTaggedMaterials(in: modeEntity, tag: BoundsGuideEntity.markerName, color: guideColor)
    }

    private func updateTaggedMaterials(in root: Entity, tag: String, color: UIColor) {
        if root.name == tag, let modelEntity = root as? ModelEntity {
            modelEntity.model?.materials = [UnlitMaterial(color: color)]
        }

        for child in root.children {
            updateTaggedMaterials(in: child, tag: tag, color: color)
        }
    }

    private func applyModeTransform() {
        let mode = playerViewModel.selectedMode

        switch mode {
        case .flat, .sbs, .tab, .convert2DTo3D:
            modeEntity.transform.translation = [0, 0, -2.0]
        case .vr180:
            modeEntity.transform.translation = [0, 0, -0.8]
        case .vr360:
            modeEntity.transform.translation = [0, 0, 0.0]
        }
    }

    private func updateDisplayRotation(now: TimeInterval) {
        let mode = playerViewModel.selectedMode
        let supportsDisplaySpin = mode == .flat || mode == .sbs || mode == .tab || mode == .convert2DTo3D

        guard displayAutoRotateEnabled, supportsDisplaySpin else {
            autoRotateYaw = 0
            lastAutoRotateTime = now
            modeEntity.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
            return
        }

        if lastAutoRotateTime == 0 {
            lastAutoRotateTime = now
        }

        let dt = max(0, now - lastAutoRotateTime)
        lastAutoRotateTime = now

        let radiansPerSecond = Float(displayAutoRotateSpeed) * (.pi / 180)
        autoRotateYaw += radiansPerSecond * Float(dt)
        if autoRotateYaw > (2 * .pi) {
            autoRotateYaw.formTruncatingRemainder(dividingBy: (2 * .pi))
        }

        modeEntity.orientation = simd_quatf(angle: autoRotateYaw, axis: [0, 1, 0])
    }

    private func applyControlPanelTransform() {
        let effectiveDistance = Float(playerViewModel.selectedMode == .vr360 ? max(controlsDistance, 1.0) : controlsDistance)
        let effectiveHeight = Float(playerViewModel.selectedMode == .vr360 ? min(controlsHeight, -0.32) : controlsHeight)

        controlsAnchor.position = [0, effectiveHeight, -effectiveDistance]
        controlsAnchor.orientation = simd_quatf(angle: Float(controlsTilt) * .pi / 180, axis: [1, 0, 0])
    }

    private func enqueueNativeStereoFrameIfNeeded() {
        guard let media = playerViewModel.currentMedia,
              media.resolvedFramePacking != .none,
              let pixelBuffer = playerViewModel.currentPixelBuffer
        else {
            return
        }

        let time = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 1_000)

        do {
            try apmpInjector.enqueue(
                pixelBuffer: pixelBuffer,
                projection: media.resolvedProjection,
                framePacking: media.resolvedFramePacking,
                presentationTime: time
            )
        } catch {
            Task {
                await DebugCategory.immersive.errorLog(
                    "APMP enqueue failed",
                    context: ["error": error.localizedDescription]
                )
            }
        }
    }

    private func publishSnapshotIfNeeded(now: TimeInterval) {
        guard now - lastSnapshotTime >= 0.2 else { return }
        lastSnapshotTime = now

        let contentPosition = modeEntity.transform.translation
        let controlsPosition = controlsAnchor.transform.translation

        let headPosition: SIMD3<Float>?
        if let headTransform = headTracker.transform {
            headPosition = simd_make_float3(headTransform.columns.3)
        } else {
            headPosition = nil
        }

        let snapshot = ImmersiveSceneSnapshot(
            timestamp: Date(),
            mode: playerViewModel.selectedMode.rawValue,
            renderSurface: playerViewModel.renderSurface.rawValue,
            modeEntityChildren: modeEntity.children.count,
            controlsEntityChildren: controlsAnchor.children.count,
            boundsGuidesEnabled: showBoundsGuides,
            contentX: Double(contentPosition.x),
            contentY: Double(contentPosition.y),
            contentZ: Double(contentPosition.z),
            controlsX: Double(controlsPosition.x),
            controlsY: Double(controlsPosition.y),
            controlsZ: Double(controlsPosition.z),
            headX: headPosition.map { Double($0.x) },
            headY: headPosition.map { Double($0.y) },
            headZ: headPosition.map { Double($0.z) }
        )

        playerViewModel.updateImmersiveSnapshot(snapshot)
    }
}
#endif
