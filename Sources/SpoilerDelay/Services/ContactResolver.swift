import Contacts
import Foundation

protocol ContactResolving: Sendable {
    func displayName(for handle: String) -> String?
}

final class ContactResolver: ContactResolving, @unchecked Sendable {
    private let store = CNContactStore()
    private let lock = NSLock()
    private var cache: [String: String] = [:]

    func displayName(for handle: String) -> String? {
        lock.lock()
        if let cached = cache[handle] { lock.unlock(); return cached }
        lock.unlock()

        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else { return nil }
        let keys = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName)]
        let contacts: [CNContact]
        do {
            if handle.contains("@") {
                contacts = try store.unifiedContacts(matching: CNContact.predicateForContacts(matchingEmailAddress: handle), keysToFetch: keys)
            } else {
                contacts = try store.unifiedContacts(matching: CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: handle)), keysToFetch: keys)
            }
        } catch {
            return nil
        }
        guard let name = contacts.first.flatMap({ CNContactFormatter.string(from: $0, style: .fullName) }), !name.isEmpty else {
            return nil
        }
        lock.lock(); cache[handle] = name; lock.unlock()
        return name
    }
}
