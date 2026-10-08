import UIKit
import UniformTypeIdentifiers
import SwiftArchive

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UIDocumentBrowserViewControllerDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let browser = UIDocumentBrowserViewController(forOpening: [.item])
        browser.delegate = self
        browser.allowsDocumentCreation = false
        browser.allowsPickingMultipleItems = false

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = browser
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    func documentBrowser(
        _ controller: UIDocumentBrowserViewController,
        didPickDocumentsAt documentURLs: [URL]
    ) {
        guard let url = documentURLs.first else { return }

        let progress = UIAlertController(
            title: "Extracting",
            message: url.lastPathComponent,
            preferredStyle: .alert
        )
        controller.present(progress, animated: true)

        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                if hasScopedAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let result: Result<URL, Error>
            do {
                result = .success(try ArchiveExtractor.extract(url: url))
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async {
                progress.dismiss(animated: true) {
                    let message: String
                    switch result {
                    case .success(let folder):
                        message = "Files saved to Documents/\(folder.lastPathComponent)"
                    case .failure(let error):
                        message = error.localizedDescription
                    }

                    let alert = UIAlertController(
                        title: result.isSuccess ? "Extraction complete" : "Could not extract archive",
                        message: message,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    controller.present(alert, animated: true)
                }
            }
        }
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}