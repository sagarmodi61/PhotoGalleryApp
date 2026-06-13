import Foundation

// MARK: - View State
enum ViewState<T> {
    case idle
    case loading
    case success(T)
    case failure(String)
}

// MARK: - Photo List ViewModel
final class PhotoListViewModel {

    // MARK: - Mock Data
    private static let mockPhotos: [PhotoDTO] = [
        PhotoDTO(albumId: 1, id: 1,  title: "accusamus beatae ad facilis cum similique qui sunt",          url: "https://via.placeholder.com/600/92c952", thumbnailUrl: "https://via.placeholder.com/150/92c952"),
        PhotoDTO(albumId: 1, id: 2,  title: "reprehenderit est deserunt velit ipsam",                      url: "https://via.placeholder.com/600/771796", thumbnailUrl: "https://via.placeholder.com/150/771796"),
        PhotoDTO(albumId: 1, id: 3,  title: "officia porro iure quia iusto qui ipsa ut modi",              url: "https://via.placeholder.com/600/24f355", thumbnailUrl: "https://via.placeholder.com/150/24f355"),
        PhotoDTO(albumId: 1, id: 4,  title: "culpa odio esse rerum omnis laboriosam voluptate repudiandae", url: "https://via.placeholder.com/600/d32776", thumbnailUrl: "https://via.placeholder.com/150/d32776"),
        PhotoDTO(albumId: 1, id: 5,  title: "natus nisi omnis corporis facere molestiae rerum in",         url: "https://via.placeholder.com/600/f66b97", thumbnailUrl: "https://via.placeholder.com/150/f66b97"),
        PhotoDTO(albumId: 2, id: 6,  title: "accusamus ea aliquid et amet sequi nemo",                     url: "https://via.placeholder.com/600/56a8c2", thumbnailUrl: "https://via.placeholder.com/150/56a8c2"),
        PhotoDTO(albumId: 2, id: 7,  title: "officia delectus consequatur vero aut veniam explicabo molestias", url: "https://via.placeholder.com/600/b0f7cc", thumbnailUrl: "https://via.placeholder.com/150/b0f7cc"),
        PhotoDTO(albumId: 2, id: 8,  title: "aut porro officiis laborum odit ea vitae aut",                url: "https://via.placeholder.com/600/54176f", thumbnailUrl: "https://via.placeholder.com/150/54176f"),
        PhotoDTO(albumId: 2, id: 9,  title: "qui eius qui autem sed",                                      url: "https://via.placeholder.com/600/51aa97", thumbnailUrl: "https://via.placeholder.com/150/51aa97"),
        PhotoDTO(albumId: 2, id: 10, title: "beatae et provident et ut vel",                               url: "https://via.placeholder.com/600/810b14", thumbnailUrl: "https://via.placeholder.com/150/810b14"),
        PhotoDTO(albumId: 3, id: 11, title: "nihil at amet non hic quia qui",                              url: "https://via.placeholder.com/600/1ee8a4", thumbnailUrl: "https://via.placeholder.com/150/1ee8a4"),
        PhotoDTO(albumId: 3, id: 12, title: "mollitia soluta ut rerum eos aliquam consequatur perspiciatis maiores", url: "https://via.placeholder.com/600/66b7d2", thumbnailUrl: "https://via.placeholder.com/150/66b7d2"),
        PhotoDTO(albumId: 3, id: 13, title: "repudiandae iusto deleniti rerum",                            url: "https://via.placeholder.com/600/197d29", thumbnailUrl: "https://via.placeholder.com/150/197d29"),
        PhotoDTO(albumId: 3, id: 14, title: "est necessitatibus architecto ut laborum",                    url: "https://via.placeholder.com/600/61a65", thumbnailUrl: "https://via.placeholder.com/150/61a65"),
        PhotoDTO(albumId: 3, id: 15, title: "harum dicta similique quis dolore earum ex qui",              url: "https://via.placeholder.com/600/f9cee5", thumbnailUrl: "https://via.placeholder.com/150/f9cee5"),
    ]

    // MARK: - Callbacks
    var onStateChanged: ((ViewState<[PhotoDTO]>) -> Void)?
    var onLoadMoreCompleted: (() -> Void)?

    // MARK: - Pagination
    private(set) var photos: [PhotoDTO] = []
    private var allPhotos: [PhotoDTO] = []
    private let pageSize   = 10
    private var currentPage = 0
    private var isFetchingMore = false

    // MARK: - Search
    private(set) var searchText = ""

    var filteredPhotos: [PhotoDTO] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return photos }
        return photos.filter { $0.title.lowercased().contains(q) }
    }

    var numberOfPhotos: Int { filteredPhotos.count }

    // MARK: - Public

    /// Loads photos from local mock data (no network call).
    func loadPhotos() {
        onStateChanged?(.loading)
        // Simulate a short delay to mimic async loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.allPhotos = Self.mockPhotos
            self.resetPagination()
            self.onStateChanged?(.success(self.photos))
        }
    }

    func loadNextPage() {
        guard !isFetchingMore else { return }
        let start = currentPage * pageSize
        guard start < allPhotos.count else { return }

        isFetchingMore = true
        let slice = Array(allPhotos[start ..< min(start + pageSize, allPhotos.count)])
        photos.append(contentsOf: slice)
        currentPage += 1
        isFetchingMore = false
        onLoadMoreCompleted?()
    }

    func search(query: String) {
        searchText = query
    }

    func photo(at index: Int) -> PhotoDTO? {
        let list = filteredPhotos
        guard index < list.count else { return nil }
        return list[index]
    }

    func updatePhoto(_ updatedPhoto: PhotoDTO) {
        if let idx = photos.firstIndex(where: { $0.id == updatedPhoto.id }) {
            photos[idx] = updatedPhoto
        }
        if let idx = allPhotos.firstIndex(where: { $0.id == updatedPhoto.id }) {
            allPhotos[idx] = updatedPhoto
        }
    }

    // MARK: - Private

    private func resetPagination() {
        currentPage = 0
        photos = []
        loadNextPage()
    }
}
