// Ported from drewolbrich/03460fc1bb71b9a821fff722f17ec977 (MIT License)
// A visionOS SwiftUI view modifier that hides resize handles or constrains
// a window's aspect ratio via UIWindowScene.requestGeometryUpdate, guaranteed
// to target the correct window (unlike the Happy Beam approach).

#if os(visionOS)

import SwiftUI

extension View {

    /// Sets geometry preferences for this view's window scene.
    ///
    /// Use `.windowGeometryPreferences(resizingRestrictions: .none)` to fully
    /// hide resize handles (matches visionOS Settings app behaviour).
    /// Use `.windowGeometryPreferences(minimumSize:resizingRestrictions: .uniform)`
    /// to lock the aspect ratio while still allowing resize.
    func windowGeometryPreferences(
        size: CGSize? = nil,
        minimumSize: CGSize? = nil,
        maximumSize: CGSize? = nil,
        resizingRestrictions: UIWindowScene.ResizingRestrictions
    ) -> some View {
        let prefs = UIWindowScene.GeometryPreferences.Vision(
            size: size,
            minimumSize: minimumSize,
            maximumSize: maximumSize,
            resizingRestrictions: resizingRestrictions
        )
        return modifier(WindowGeometryPreferencesViewModifier(geometryPreferences: prefs))
    }

    /// Sets geometry preferences without a resizing restriction.
    func windowGeometryPreferences(
        size: CGSize? = nil,
        minimumSize: CGSize? = nil,
        maximumSize: CGSize? = nil
    ) -> some View {
        let prefs = UIWindowScene.GeometryPreferences.Vision(
            size: size,
            minimumSize: minimumSize,
            maximumSize: maximumSize,
            resizingRestrictions: nil
        )
        return modifier(WindowGeometryPreferencesViewModifier(geometryPreferences: prefs))
    }
}

// MARK: - Private implementation

private struct WindowGeometryPreferencesViewModifier: ViewModifier {
    let geometryPreferences: UIWindowScene.GeometryPreferences.Vision

    func body(content: Content) -> some View {
        WindowGeometryPreferencesView(geometryPreferences: geometryPreferences) {
            content
        }
    }
}

private struct WindowGeometryPreferencesView<Content: View>: UIViewControllerRepresentable {
    let geometryPreferences: UIWindowScene.GeometryPreferences.Vision
    let content: () -> Content

    func makeUIViewController(context: Context) -> WindowGeometryPreferencesUIViewController<Content> {
        WindowGeometryPreferencesUIViewController(geometryPreferences: geometryPreferences, content: content)
    }

    func updateUIViewController(
        _ vc: WindowGeometryPreferencesUIViewController<Content>,
        context: Context
    ) {
        vc.geometryPreferences = geometryPreferences
    }
}

private class WindowGeometryPreferencesUIViewController<Content: View>: UIViewController {
    var geometryPreferences: UIWindowScene.GeometryPreferences.Vision {
        didSet { geometryPreferencesView?.geometryPreferences = geometryPreferences }
    }

    private let hostingController: UIHostingController<Content>

    private var geometryPreferencesView: WindowGeometryPreferencesUIView? {
        viewIfLoaded as? WindowGeometryPreferencesUIView
    }

    init(geometryPreferences: UIWindowScene.GeometryPreferences.Vision, content: @escaping () -> Content) {
        self.geometryPreferences = geometryPreferences
        self.hostingController = UIHostingController(rootView: content())
        super.init(nibName: nil, bundle: nil)
        addChild(hostingController)
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func loadView() {
        view = WindowGeometryPreferencesUIView(geometryPreferences: geometryPreferences)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        hostingController.view.frame = view.bounds
        view.addSubview(hostingController.view)
    }
}

private class WindowGeometryPreferencesUIView: UIView {
    var geometryPreferences: UIWindowScene.GeometryPreferences.Vision {
        didSet { requestGeometryUpdate(with: geometryPreferences) }
    }

    init(geometryPreferences: UIWindowScene.GeometryPreferences.Vision) {
        self.geometryPreferences = geometryPreferences
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func didMoveToWindow() {
        // Wait one run-loop spin: during the visionOS 1.0 scene-connection window
        // geometry requests may not yet be honoured.
        RunLoop.main.perform {
            self.requestGeometryUpdate(with: self.geometryPreferences)
        }
    }

    private func requestGeometryUpdate(with preferences: UIWindowScene.GeometryPreferences) {
        window?.windowScene?.requestGeometryUpdate(preferences) { error in
            // If this fires in a future visionOS, check for a native SwiftUI
            // equivalent (e.g. .windowResizability) and migrate.
            Task {
                await DebugCategory.navigation.warningLog(
                    "Window geometry update failed",
                    context: ["error": error.localizedDescription]
                )
            }
        }
    }
}

#endif // os(visionOS)
