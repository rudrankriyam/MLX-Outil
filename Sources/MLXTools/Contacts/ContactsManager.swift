import Foundation
import Contacts
import os

/// Error types for contacts operations
public enum ContactsError: Error, LocalizedError {
    case accessDenied
    case invalidAction
    case missingQuery
    case missingContactId
    case missingName
    
    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to contacts denied. Please grant permission in Settings."
        case .invalidAction:
            return "Invalid action. Use 'search', 'read', or 'create'."
        case .missingQuery:
            return "Search query is required."
        case .missingContactId:
            return "Contact ID is required."
        case .missingName:
            return "Given name is required to create a contact."
        }
    }
}

/// Input for contacts operations
public struct ContactsInput: Codable, Sendable {
    public let action: String
    public let query: String?
    public let contactId: String?
    public let givenName: String?
    public let familyName: String?
    public let email: String?
    public let phoneNumber: String?
    public let organization: String?
    
    public init(
        action: String,
        query: String? = nil,
        contactId: String? = nil,
        givenName: String? = nil,
        familyName: String? = nil,
        email: String? = nil,
        phoneNumber: String? = nil,
        organization: String? = nil
    ) {
        self.action = action
        self.query = query
        self.contactId = contactId
        self.givenName = givenName
        self.familyName = familyName
        self.email = email
        self.phoneNumber = phoneNumber
        self.organization = organization
    }
}

/// Output for contacts operations
public struct ContactsOutput: Codable, Sendable {
    public let status: String
    public let message: String
    public let contactId: String?
    public let results: String?
    public let count: Int?
    
    public init(status: String, message: String, contactId: String? = nil, results: String? = nil, count: Int? = nil) {
        self.status = status
        self.message = message
        self.contactId = contactId
        self.results = results
        self.count = count
    }
}

/// Manager for contacts operations using Contacts framework
@MainActor
public class ContactsManager {
    public static let shared = ContactsManager()
    
    private let store = CNContactStore()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MLXTools", category: "ContactsManager")
    
    private init() {
        logger.info("ContactsManager initialized")
    }
    
    /// Main entry point for contacts operations
    public func performAction(_ input: ContactsInput) async throws -> ContactsOutput {
        logger.info("Performing contacts action: \(input.action)")
        
        // Request access if needed
        let authorized = await requestAccess()
        guard authorized else {
            throw ContactsError.accessDenied
        }
        
        switch input.action.lowercased() {
        case "search":
            return try searchContacts(query: input.query)
        case "read":
            return try readContact(contactId: input.contactId)
        case "create":
            return try createContact(input: input)
        default:
            throw ContactsError.invalidAction
        }
    }
    
    private nonisolated func requestAccess() async -> Bool {
        let contactStore = CNContactStore()
        do {
            return try await contactStore.requestAccess(for: .contacts)
        } catch {
            return false
        }
    }
    
    private func searchContacts(query: String?) throws -> ContactsOutput {
        guard let searchQuery = query, !searchQuery.isEmpty else {
            throw ContactsError.missingQuery
        }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]
        
        let predicate = CNContact.predicateForContacts(matchingName: searchQuery)
        
        do {
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            
            if contacts.isEmpty {
                // Try searching by email or phone
                let allContacts = try store.unifiedContacts(
                    matching: NSPredicate(value: true),
                    keysToFetch: keysToFetch
                )
                
                let filteredContacts = allContacts.filter { contact in
                    // Check emails
                    for email in contact.emailAddresses {
                        if email.value.contains(searchQuery) {
                            return true
                        }
                    }
                    // Check phone numbers
                    for phone in contact.phoneNumbers {
                        if phone.value.stringValue.contains(searchQuery) {
                            return true
                        }
                    }
                    return false
                }
                
                return formatContactsOutput(contacts: filteredContacts, query: searchQuery)
            }
            
            return formatContactsOutput(contacts: contacts, query: searchQuery)
        } catch {
            logger.error("Failed to search contacts: \(error)")
            throw error
        }
    }
    
    private func readContact(contactId: String?) throws -> ContactsOutput {
        guard let id = contactId else {
            throw ContactsError.missingContactId
        }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor
        ]
        
        do {
            let contact = try store.unifiedContact(withIdentifier: id, keysToFetch: keysToFetch)
            
            var addresses: [String] = []
            for address in contact.postalAddresses {
                let value = address.value
                let formatted = "\(value.street), \(value.city), \(value.state) \(value.postalCode)"
                addresses.append(formatted)
            }
            
            let contactDetails = """
            Name: \(contact.givenName) \(contact.familyName)
            Organization: \(contact.organizationName)
            Emails: \(contact.emailAddresses.map { $0.value as String }.joined(separator: ", "))
            Phone Numbers: \(contact.phoneNumbers.map { $0.value.stringValue }.joined(separator: ", "))
            Addresses: \(addresses.joined(separator: "; "))
            Birthday: \(contact.birthday?.date?.description ?? "Not set")
            Note: \(contact.note)
            """
            
            return ContactsOutput(
                status: "success",
                message: "Contact details retrieved",
                contactId: contact.identifier,
                results: contactDetails.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            logger.error("Failed to read contact: \(error)")
            throw error
        }
    }
    
    private func createContact(input: ContactsInput) throws -> ContactsOutput {
        guard let givenName = input.givenName, !givenName.isEmpty else {
            throw ContactsError.missingName
        }
        
        let newContact = CNMutableContact()
        newContact.givenName = givenName
        
        if let familyName = input.familyName {
            newContact.familyName = familyName
        }
        
        if let email = input.email {
            newContact.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: NSString(string: email))]
        }
        
        if let phone = input.phoneNumber {
            newContact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
        }
        
        if let org = input.organization {
            newContact.organizationName = org
        }
        
        let saveRequest = CNSaveRequest()
        saveRequest.add(newContact, toContainerWithIdentifier: nil)
        
        do {
            try store.execute(saveRequest)
            
            logger.info("Contact created successfully")
            
            return ContactsOutput(
                status: "success",
                message: "Contact created successfully",
                contactId: newContact.identifier
            )
        } catch {
            logger.error("Failed to create contact: \(error)")
            throw error
        }
    }
    
    private func formatContactsOutput(contacts: [CNContact], query: String) -> ContactsOutput {
        var contactsDescription = ""
        
        for (index, contact) in contacts.enumerated() {
            let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let email = contact.emailAddresses.first?.value as String? ?? "No email"
            let phone = contact.phoneNumbers.first?.value.stringValue ?? "No phone"
            let org = contact.organizationName.isEmpty ? "" : " (\(contact.organizationName))"
            
            contactsDescription += "\(index + 1). \(name)\(org) - Email: \(email), Phone: \(phone)\n"
        }
        
        if contactsDescription.isEmpty {
            contactsDescription = "No contacts found matching '\(query)'"
        }
        
        return ContactsOutput(
            status: "success",
            message: "Found \(contacts.count) contact(s) matching '\(query)'",
            results: contactsDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            count: contacts.count
        )
    }
}