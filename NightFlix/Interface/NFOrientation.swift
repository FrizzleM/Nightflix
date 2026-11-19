import UIKit

/// App delegate used only to answer the system's "which orientations are allowed right
/// now?" question, so the player can rotate to landscape while browsing stays portrait.
final class NightflixAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        NFOrientation.allowedOrientations
    }
}

/// Orientation policy: on iPhone the browsing UI is portrait-only and the player is
/// landscape-only, like a dedicated streaming app. iPad keeps every orientation.
enum NFOrientation {
    private(set) static var allowedOrientations: UIInterfaceOrientationMask = defaultMask

    private static var defaultMask: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
    }

    static func enterPlayback() {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        apply(.landscape, rotateTo: .landscapeRight)
    }

    static func exitPlayback() {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        apply(.portrait, rotateTo: .portrait)
    }

    private static func apply(_ mask: UIInterfaceOrientationMask, rotateTo target: UIInterfaceOrientationMask) {
        allowedOrientations = mask

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }

            for window in windowScene.windows {
                var controller = window.rootViewController
                while let current = controller {
                    current.setNeedsUpdateOfSupportedInterfaceOrientations()
                    controller = current.presentedViewController
                }
            }

            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: target)) { _ in }
        }
    }
}

/// Keeps the edge-swipe "back" gesture working on navigation stacks whose bar is hidden
/// (the title pages draw their own back button).
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == interactivePopGestureRecognizer else { return true }
        return viewControllers.count > 1
    }
}
