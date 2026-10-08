import UIKit
import UniformTypeIdentifiers

final class ArchiveHomeViewController: UIViewController, UIDocumentBrowserViewControllerDelegate, UITableViewDataSource {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let statusLabel = UILabel()
    private var extractionFolders: [URL] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureLayout()
        refreshFolders()
    }

    private func configureView() {
        view.backgroundColor = UIColor.systemGroupedBackground

        let eyebrow = UILabel()
        eyebrow.text = "7ZIP FILES"
        eyebrow.font = .systemFont(ofSize: 12, weight: .bold)
        eyebrow.textColor = .systemGreen

        let title = UILabel()
        title.text = "Archives"
        title.font = .systemFont(ofSize: 34, weight: .bold)
        title.textColor = .label

        let subtitle = UILabel()
        subtitle.text = "Extract archives straight to Documents."
        subtitle.font = .systemFont(ofSize: 16)
        subtitle.textColor = .secondaryLabel

        let extractButton = makeButton(title: "Choose archive", symbol: "archivebox", primary: true)
        extractButton.addTarget(self, action: #selector(chooseArchive), for: .touchUpInside)

        let browseButton = makeButton(title: "Browse documents", symbol: "folder", primary: false)
        browseButton.addTarget(self, action: #selector(browseDocuments), for: .touchUpInside)

        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.text = "Ready"

        let sectionTitle = UILabel()
        sectionTitle.text = "RECENT EXTRACTIONS"
        sectionTitle.font = .systemFont(ofSize: 12, weight: .bold)
        sectionTitle.textColor = .secondaryLabel

        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 52, bottom: 0, right: 0)
        tableView.rowHeight = 56
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ExtractionFolder")

        let emptyLabel = UILabel()
        emptyLabel.text = "Your extracted folders will appear here."
        emptyLabel.font = .systemFont(ofSize: 15)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        tableView.backgroundView = emptyLabel

        let stack = UIStackView(arrangedSubviews: [
            eyebrow,
            title,
            subtitle,
            extractButton,
            browseButton,
            statusLabel,
            sectionTitle,
            tableView
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(4, after: eyebrow)
        stack.setCustomSpacing(4, after: title)
        stack.setCustomSpacing(18, after: subtitle)
        stack.setCustomSpacing(18, after: browseButton)
        stack.setCustomSpacing(24, after: sectionTitle)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            extractButton.heightAnchor.constraint(equalToConstant: 54),
            browseButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func configureLayout() {
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    private func makeButton(title: String, symbol: String, primary: Bool) -> UIButton {
        var configuration = primary ? UIButton.Configuration.filled() : UIButton.Configuration.gray()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = 10
        configuration.cornerStyle = .medium
        configuration.baseBackgroundColor = primary ? .systemGreen : .tertiarySystemGroupedBackground
        configuration.baseForegroundColor = primary ? .white : .label
        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        return button
    }

    @objc private func chooseArchive() {
        presentDocumentBrowser()
    }

    @objc private func browseDocuments() {
        presentDocumentBrowser()
    }

    private func presentDocumentBrowser() {
        let browser = UIDocumentBrowserViewController(forOpening: [.item])
        browser.delegate = self
        browser.allowsDocumentCreation = false
        browser.allowsPickingMultipleItems = false
        browser.modalPresentationStyle = .fullScreen
        present(browser, animated: true)
    }

    func documentBrowser(
        _ controller: UIDocumentBrowserViewController,
        didPickDocumentsAt documentURLs: [URL]
    ) {
        guard let url = documentURLs.first else { return }
        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        controller.dismiss(animated: true) {
            self.extractArchive(at: url, hasScopedAccess: hasScopedAccess)
        }
    }

    private func extractArchive(at url: URL, hasScopedAccess: Bool) {
        statusLabel.text = "Extracting \(url.lastPathComponent)..."
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
                switch result {
                case .success(let folder):
                    self.statusLabel.text = "Extracted to Documents/\(folder.lastPathComponent)"
                    self.refreshFolders()
                case .failure(let error):
                    self.statusLabel.text = error.localizedDescription
                }
            }
        }
    }

    private func refreshFolders() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        extractionFolders = ((try? FileManager.default.contentsOfDirectory(
            at: documents,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted {
                let firstDate = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let secondDate = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return firstDate > secondDate
            }
        tableView.backgroundView?.isHidden = !extractionFolders.isEmpty
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        extractionFolders.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExtractionFolder", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = extractionFolders[indexPath.row].lastPathComponent
        content.image = UIImage(systemName: "folder.fill")
        content.imageProperties.tintColor = .systemGreen
        cell.contentConfiguration = content
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        return cell
    }
}