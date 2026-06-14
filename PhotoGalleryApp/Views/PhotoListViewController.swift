import UIKit

final class PhotoListViewController: UIViewController {

    private let viewModel = PhotoListViewModel()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
        cv.dataSource       = self
        cv.delegate         = self
        cv.backgroundColor  = .systemBackground
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.showsVerticalScrollIndicator = false
        return cv
    }()

    private lazy var searchController: UISearchController = {
        let sc = UISearchController(searchResultsController: nil)
        sc.searchResultsUpdater                 = self
        sc.obscuresBackgroundDuringPresentation = false
        sc.searchBar.placeholder                = "Search photos…"
        return sc
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    private lazy var syncBarButton: UIBarButtonItem = {
        UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"),
                        style: .plain,
                        target: self,
                        action: #selector(syncTapped))
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Photo Gallery"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.searchController              = searchController
        navigationItem.hidesSearchBarWhenScrolling   = false
        navigationItem.rightBarButtonItem             = syncBarButton
        view.backgroundColor = .systemBackground

        view.addSubview(collectionView)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async { self?.handleState(state) }
        }
        viewModel.onLoadMoreCompleted = { [weak self] in
            DispatchQueue.main.async { self?.collectionView.reloadData() }
        }
        viewModel.onSyncStateChanged = { [weak self] isSyncing in
            DispatchQueue.main.async { self?.handleSyncState(isSyncing) }
        }
        viewModel.loadPhotos()
    }

    private func handleState(_ state: ViewState<[PhotoDTO]>) {
        switch state {
        case .loading:
            activityIndicator.startAnimating()
        case .success:
            activityIndicator.stopAnimating()
            collectionView.reloadData()
        case .failure(let msg):
            activityIndicator.stopAnimating()
            let alert = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        default: break
        }
    }

    private func handleSyncState(_ isSyncing: Bool) {
        syncBarButton.isEnabled = !isSyncing
        if isSyncing {
            // Spin the icon
            let rotation = CABasicAnimation(keyPath: "transform.rotation")
            rotation.toValue = Double.pi * 2
            rotation.duration = 0.8
            rotation.isCumulative = true
            rotation.repeatCount = .infinity
            syncBarButton.customView = nil   // ensure image button is used
            // Swap to a spinner in the nav bar while loading
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            syncBarButton.customView = spinner
        } else {
            syncBarButton.customView = nil
            syncBarButton.image = UIImage(systemName: "arrow.clockwise")
        }
    }

    // MARK: - Sync action
    @objc private func syncTapped() {
        viewModel.syncFromAPI()
    }

    // MARK: - Delete with confirmation

    private func confirmDelete(at indexPath: IndexPath) {
        guard let photo = viewModel.photo(at: indexPath.item) else { return }

        let alert = UIAlertController(
            title: "Delete Photo",
            message: "Are you sure you want to delete \"\(photo.title.isEmpty ? "Photo #\(photo.id)" : photo.title)\"? ",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDelete(at: indexPath)
        })
        present(alert, animated: true)
    }

    private func performDelete(at indexPath: IndexPath) {
        viewModel.deletePhoto(at: indexPath.item) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                // Animate single cell removal if still valid, otherwise full reload
                if indexPath.item < self.viewModel.numberOfPhotos {
                    self.collectionView.deleteItems(at: [indexPath])
                } else {
                    self.collectionView.reloadData()
                }
            case .failure(let error):
                let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(0.5),
                              heightDimension: .fractionalWidth(0.5))
        )
        item.contentInsets = .init(top: 4, leading: 4, bottom: 4, trailing: 4)
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1),
                              heightDimension: .fractionalWidth(0.5)),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 8, leading: 8, bottom: 8, trailing: 8)
        return UICollectionViewCompositionalLayout(section: section)
    }
}

extension PhotoListViewController: UICollectionViewDataSource {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.numberOfPhotos
    }
    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = cv.dequeueReusableCell(withReuseIdentifier: PhotoCell.reuseIdentifier, for: indexPath) as? PhotoCell,
              let photo = viewModel.photo(at: indexPath.item) else { return UICollectionViewCell() }
        cell.configure(with: photo)
        return cell
    }
}

extension PhotoListViewController: UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let photo = viewModel.photo(at: indexPath.item) else { return }
        let detailVC = PhotoDetailViewController(photo: photo, index: indexPath.item)

        detailVC.onTitleSaved = { [weak self] updatedPhoto in
            self?.viewModel.updatePhoto(updatedPhoto)
            self?.collectionView.reloadItems(at: [indexPath])
        }

        detailVC.onPhotoDeleted = { [weak self] deletedIndex in
            guard let self else { return }
            self.viewModel.deletePhoto(at: deletedIndex) { result in
                switch result {
                case .success:
                    if deletedIndex < self.viewModel.numberOfPhotos {
                        self.collectionView.deleteItems(at: [IndexPath(item: deletedIndex, section: 0)])
                    } else {
                        self.collectionView.reloadData()
                    }
                case .failure: break
                }
            }
        }

        navigationController?.pushViewController(detailVC, animated: true)
    }

    // MARK: - Swipe-to-delete via context menu
    func collectionView(
        _ cv: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let photo = viewModel.photo(at: indexPath.item) else { return nil }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let deleteAction = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.confirmDelete(at: indexPath)
            }
            return UIMenu(title: photo.title, children: [deleteAction])
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY       = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight   = scrollView.frame.size.height
        if offsetY > contentHeight - frameHeight - 200 {
            viewModel.loadNextPage()
        }
    }
}

extension PhotoListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.search(query: searchController.searchBar.text ?? "")
        collectionView.reloadData()
    }
}
