import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)

        let listVC = PhotoListViewController()
        let nav    = UINavigationController(rootViewController: listVC)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        nav.navigationBar.standardAppearance   = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        nav.navigationBar.prefersLargeTitles   = true

        window?.rootViewController = nav
        window?.makeKeyAndVisible()
        return true
    }
}
