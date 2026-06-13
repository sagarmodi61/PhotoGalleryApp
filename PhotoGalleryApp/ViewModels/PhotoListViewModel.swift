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

    /// Loads photos from the API.
    func loadPhotos() {
        onStateChanged?(.loading)
        guard let url = URL(string: "https://jsonplaceholder.typicode.com/photos") else {
            onStateChanged?(.failure("Invalid URL"))
            return
        }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                let message: String
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet:
                        message = "No Internet Connection. Please check your connection and try again."
                    case .timedOut:
                        message = "The request timed out. Please try again later."
                    case .cannotConnectToHost:
                        message = "Cannot connect to server. Please try again later."
                    default:
                        message = urlError.localizedDescription
                    }
                } else {
                    message = error.localizedDescription
                }
                DispatchQueue.main.async {
                    self.onStateChanged?(.failure(message))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.onStateChanged?(.failure("Invalid response from server."))
                }
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    self.onStateChanged?(.failure("Server returned an error (Status: \(httpResponse.statusCode))."))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.onStateChanged?(.failure("No data received from the server."))
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let fetchedPhotos = try decoder.decode([PhotoDTO].self, from: data)
                DispatchQueue.main.async {
                    self.allPhotos = fetchedPhotos
                    self.resetPagination()
                    self.onStateChanged?(.success(self.photos))
                }
            } catch {
                DispatchQueue.main.async {
                    self.onStateChanged?(.failure("Failed to decode data. Please check for app updates."))
                }
            }
        }
        task.resume()
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
