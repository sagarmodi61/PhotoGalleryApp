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
    private let pageSize   = 40
    private var currentPage = 0
    private var isFetchingMore = false
    private var hasMorePhotos = true

    // MARK: - Search
    private(set) var searchText = ""

    var filteredPhotos: [PhotoDTO] { photos }

    var numberOfPhotos: Int { photos.count }

    // MARK: - Public

    /// Loads photos from Core Data first. If empty, fetches from the API.
    func loadPhotos() {
        onStateChanged?(.loading)
        
        let localCount = CoreDataManager.shared.countOfPhotos()
        if localCount > 0 {
            self.resetPagination()
            self.onStateChanged?(.success(self.photos))
            return
        }
        
        fetchPhotosFromAPI()
    }
    
    private func fetchPhotosFromAPI() {
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
                
                CoreDataManager.shared.savePhotos(fetchedPhotos) { [weak self] result in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            self.resetPagination()
                            self.onStateChanged?(.success(self.photos))
                        case .failure(let error):
                            print("Core Data save failed: \(error)")
                            // Fallback to presenting from memory
                            self.photos = Array(fetchedPhotos.prefix(self.pageSize))
                            self.currentPage = 1
                            self.hasMorePhotos = fetchedPhotos.count > self.pageSize
                            self.onStateChanged?(.success(self.photos))
                        }
                    }
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
        guard !isFetchingMore && hasMorePhotos else { return }
        isFetchingMore = true
        
        // Fetch next batch from Core Data
        let offset = currentPage * pageSize
        let nextBatch = CoreDataManager.shared.fetchPhotos(limit: pageSize, offset: offset, search: searchText)
        
        if nextBatch.isEmpty {
            hasMorePhotos = false
            isFetchingMore = false
            return
        }
        
        photos.append(contentsOf: nextBatch)
        currentPage += 1
        isFetchingMore = false
        onLoadMoreCompleted?()
    }

    func search(query: String) {
        searchText = query
        resetPagination()
    }

    func photo(at index: Int) -> PhotoDTO? {
        guard index < photos.count else { return nil }
        return photos[index]
    }

    func updatePhoto(_ updatedPhoto: PhotoDTO) {
        if let idx = photos.firstIndex(where: { $0.id == updatedPhoto.id }) {
            photos[idx] = updatedPhoto
        }
        
        CoreDataManager.shared.updatePhotoTitle(id: updatedPhoto.id, newTitle: updatedPhoto.title) { result in
            switch result {
            case .success:
                print("Core Data title updated successfully for photo \(updatedPhoto.id)")
            case .failure(let error):
                print("Failed to update title in Core Data: \(error)")
            }
        }
    }

    // MARK: - Private

    private func resetPagination() {
        currentPage = 0
        photos = []
        hasMorePhotos = true
        
        // Load first page
        let firstBatch = CoreDataManager.shared.fetchPhotos(limit: pageSize, offset: 0, search: searchText)
        photos = firstBatch
        currentPage = 1
        if firstBatch.count < pageSize {
            hasMorePhotos = false
        }
    }
}
