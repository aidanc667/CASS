import Foundation
import CoreData

class UserInfo: NSManagedObject {
    @NSManaged public var category: String
    @NSManaged public var content: String
    @NSManaged public var timestamp: Date
    @NSManaged public var subcategory: String
}

extension UserInfo {
    static func fetchRequest() -> NSFetchRequest<UserInfo> {
        return NSFetchRequest<UserInfo>(entityName: "UserInfo")
    }
} 