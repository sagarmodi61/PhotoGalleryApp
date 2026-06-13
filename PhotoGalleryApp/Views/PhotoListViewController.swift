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

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Photo Gallery"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.searchController              = searchController
        navigationItem.hidesSearchBarWhenScrolling   = false
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
        let detailVC = PhotoDetailViewController(photo: photo)
        detailVC.onTitleSaved = { [weak self] updatedPhoto in
            self?.viewModel.updatePhoto(updatedPhoto)
            self?.collectionView.reloadData()
        }
        navigationController?.pushViewController(detailVC, animated: true)
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
