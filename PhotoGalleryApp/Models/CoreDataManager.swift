import Foundation
import CoreData

final class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
       
        let model = NSManagedObjectModel()
        
        let photoEntity = NSEntityDescription()
        photoEntity.name = "Photo"
        photoEntity.managedObjectClassName = NSStringFromClass(Photo.self)
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .integer64AttributeType
        idAttr.isOptional = false
        
        let albumIdAttr = NSAttributeDescription()
        albumIdAttr.name = "albumId"
        albumIdAttr.attributeType = .integer64AttributeType
        albumIdAttr.isOptional = false
        
        let titleAttr = NSAttributeDescription()
        titleAttr.name = "title"
        titleAttr.attributeType = .stringAttributeType
        titleAttr.isOptional = true
        
        let urlAttr = NSAttributeDescription()
        urlAttr.name = "url"
        urlAttr.attributeType = .stringAttributeType
        urlAttr.isOptional = true
        
        let thumbnailUrlAttr = NSAttributeDescription()
        thumbnailUrlAttr.name = "thumbnailUrl"
        thumbnailUrlAttr.attributeType = .stringAttributeType
        thumbnailUrlAttr.isOptional = true
        
        photoEntity.properties = [idAttr, albumIdAttr, titleAttr, urlAttr, thumbnailUrlAttr]
        photoEntity.uniquenessConstraints = [["id"]]
        
        model.entities = [photoEntity]
        
        let container = NSPersistentContainer(name: "PhotoGalleryApp", managedObjectModel: model)
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
       
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func countOfPhotos() -> Int {
        let request = NSFetchRequest<Photo>(entityName: "Photo")
        do {
            return try context.count(for: request)
        } catch {
            print("Failed to count photos: \(error)")
            return 0
        }
    }
    
    func fetchPhotos(limit: Int, offset: Int, search: String? = nil) -> [PhotoDTO] {
        let request = NSFetchRequest<Photo>(entityName: "Photo")
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        request.fetchLimit = limit
        request.fetchOffset = offset
        
        if let search = search, !search.trimmingCharacters(in: .whitespaces).isEmpty {
            request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", search.trimmingCharacters(in: .whitespaces))
        }
        
        do {
            let results = try context.fetch(request)
            return results.map { photo in
                PhotoDTO(
                    albumId: Int(photo.albumId),
                    id: Int(photo.id),
                    title: photo.title ?? "",
                    url: photo.url ?? "",
                    thumbnailUrl: photo.thumbnailUrl ?? ""
                )
            }
        } catch {
            print("Failed to fetch photos: \(error)")
            return []
        }
    }

    func fetchAllPhotos() -> [PhotoDTO] {
        let request = NSFetchRequest<Photo>(entityName: "Photo")
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        
        do {
            let results = try context.fetch(request)
            return results.map { photo in
                PhotoDTO(
                    albumId: Int(photo.albumId),
                    id: Int(photo.id),
                    title: photo.title ?? "",
                    url: photo.url ?? "",
                    thumbnailUrl: photo.thumbnailUrl ?? ""
                )
            }
        } catch {
            print("Failed to fetch photos from Core Data: \(error)")
            return []
        }
    }
    
    func savePhotos(_ photos: [PhotoDTO], completion: @escaping (Result<Void, Error>) -> Void) {
        persistentContainer.performBackgroundTask { context in
            context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            
            for dto in photos {
                let photo = Photo(context: context)
                photo.id = Int64(dto.id)
                photo.albumId = Int64(dto.albumId)
                photo.title = dto.title
                photo.url = dto.url
                photo.thumbnailUrl = dto.thumbnailUrl
            }
            
            do {
                if context.hasChanges {
                    try context.save()
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func updatePhotoTitle(id: Int, newTitle: String, completion: @escaping (Result<Void, Error>) -> Void) {
        persistentContainer.performBackgroundTask { context in
            let request = NSFetchRequest<Photo>(entityName: "Photo")
            request.predicate = NSPredicate(format: "id == %d", id)
            request.fetchLimit = 1
            
            do {
                if let photo = try context.fetch(request).first {
                    photo.title = newTitle
                    if context.hasChanges {
                        try context.save()
                    }
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func deletePhoto(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        persistentContainer.performBackgroundTask { context in
            let request = NSFetchRequest<Photo>(entityName: "Photo")
            request.predicate = NSPredicate(format: "id == %d", id)
            request.fetchLimit = 1
            
            do {
                if let photo = try context.fetch(request).first {
                    context.delete(photo)
                    if context.hasChanges {
                        try context.save()
                    }
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func deleteAllPhotos(completion: @escaping (Result<Void, Error>) -> Void) {
        persistentContainer.performBackgroundTask { context in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")
            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDelete.resultType = .resultTypeObjectIDs

            do {
                let result = try context.execute(batchDelete) as? NSBatchDeleteResult
                let objectIDs = result?.result as? [NSManagedObjectID] ?? []
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes,
                                                    into: [self.context])
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

