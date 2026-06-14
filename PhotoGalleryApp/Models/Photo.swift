import CoreData

@objc(Photo)
class Photo: NSManagedObject {
    @NSManaged var id: Int64
    @NSManaged var albumId: Int64
    @NSManaged var title: String?
    @NSManaged var url: String?
    @NSManaged var thumbnailUrl: String?
}
