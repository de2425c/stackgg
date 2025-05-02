import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class GroupService: ObservableObject {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    @Published var userGroups: [UserGroup] = []
    @Published var pendingInvites: [GroupInvite] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var availableUsers: [UserListItem] = []
    @Published var groupMembers: [GroupMemberInfo] = []
    @Published var groupMessages: [GroupMessage] = []
    
    // Create a new group
    func createGroup(name: String, description: String?) async throws -> UserGroup {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupServiceError.notAuthenticated
        }
        
        // Create a new group document
        let groupRef = db.collection("groups").document()
        let groupId = groupRef.documentID
        
        let timestamp = Timestamp(date: Date())
        let groupData: [String: Any] = [
            "name": name,
            "description": description ?? "",
            "createdAt": timestamp,
            "ownerId": userId,
            "memberCount": 1
        ]
        
        // Add the group to Firestore
        try await groupRef.setData(groupData)
        
        // Add the user as a member
        let memberRef = groupRef.collection("members").document(userId)
        try await memberRef.setData([
            "userId": userId,
            "role": GroupMember.MemberRole.owner.rawValue,
            "joinedAt": timestamp
        ])
        
        // Add the group to the user's group collection for easy querying
        let userGroupRef = db.collection("users").document(userId).collection("groups").document(groupId)
        try await userGroupRef.setData([
            "groupId": groupId,
            "joinedAt": timestamp,
            "role": GroupMember.MemberRole.owner.rawValue
        ])
        
        // Create and return the group
        let newGroup = UserGroup(
            id: groupId,
            name: name,
            description: description,
            createdAt: timestamp.dateValue(),
            ownerId: userId,
            memberCount: 1
        )
        
        // Update the published groups list
        await MainActor.run {
            self.userGroups.append(newGroup)
            self.userGroups.sort { $0.createdAt > $1.createdAt }
        }
        
        return newGroup
    }
    
    // Fetch groups the user is a member of
    func fetchUserGroups() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupServiceError.notAuthenticated
        }
        
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            // Get the user's groups
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("groups")
                .getDocuments()
            
            var groups: [UserGroup] = []
            
            // Fetch each group's details
            for doc in snapshot.documents {
                guard let groupId = doc.data()["groupId"] as? String else { continue }
                
                do {
                    let groupDoc = try await db.collection("groups").document(groupId).getDocument()
                    
                    if let groupData = groupDoc.data(), groupDoc.exists {
                        var data = groupData
                        data["id"] = groupId
                        
                        let group = try UserGroup(dictionary: data, id: groupId)
                        groups.append(group)
                    }
                } catch {
                    print("Error fetching group \(groupId): \(error)")
                    // Continue with next group
                }
            }
            
            // Sort groups by creation date (newest first)
            groups.sort { $0.createdAt > $1.createdAt }
            
            await MainActor.run {
                self.userGroups = groups
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            throw error
        }
    }
    
    // Send an invite to a user to join a group
    func inviteUserToGroup(username: String, groupId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw GroupServiceError.notAuthenticated
        }
        
        // First, get the group to confirm existence and get name
        let groupDoc = try await db.collection("groups").document(groupId).getDocument()
        
        guard let groupData = groupDoc.data(), groupDoc.exists else {
            throw GroupServiceError.groupNotFound
        }
        
        let groupName = groupData["name"] as? String ?? "Unknown Group"
        
        // Find the user by username
        let userQuery = try await db.collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments()
        
        guard let userDoc = userQuery.documents.first, let inviteeId = userDoc.data()["id"] as? String else {
            throw GroupServiceError.userNotFound
        }
        
        // Check if the user is already a member
        let memberDoc = try await db.collection("groups")
            .document(groupId)
            .collection("members")
            .document(inviteeId)
            .getDocument()
        
        if memberDoc.exists {
            throw GroupServiceError.userAlreadyMember
        }
        
        // Check if an invite is already pending
        let inviteQuery = try await db.collection("users")
            .document(inviteeId)
            .collection("groupInvites")
            .whereField("groupId", isEqualTo: groupId)
            .whereField("status", isEqualTo: GroupInvite.InviteStatus.pending.rawValue)
            .getDocuments()
        
        if !inviteQuery.documents.isEmpty {
            throw GroupServiceError.inviteAlreadyExists
        }
        
        // Get the current user's name
        let currentUserDoc = try await db.collection("users")
            .document(currentUserId)
            .getDocument()
        
        let currentUserData = currentUserDoc.data()
        let inviterName = currentUserData?["displayName"] as? String ?? currentUserData?["username"] as? String ?? "Unknown User"
        
        // Create the invite
        let inviteRef = db.collection("users")
            .document(inviteeId)
            .collection("groupInvites")
            .document()
        
        let inviteId = inviteRef.documentID
        let timestamp = Timestamp(date: Date())
        
        let inviteData: [String: Any] = [
            "id": inviteId,
            "groupId": groupId,
            "groupName": groupName,
            "inviterId": currentUserId,
            "inviterName": inviterName,
            "inviteeId": inviteeId,
            "createdAt": timestamp,
            "status": GroupInvite.InviteStatus.pending.rawValue
        ]
        
        // Save the invite
        try await inviteRef.setData(inviteData)
    }
    
    // Fetch pending group invites for the current user
    func fetchPendingInvites() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupServiceError.notAuthenticated
        }
        
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("groupInvites")
                .whereField("status", isEqualTo: GroupInvite.InviteStatus.pending.rawValue)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            var invites: [GroupInvite] = []
            
            for doc in snapshot.documents {
                if let data = doc.data() as? [String: Any] {
                    do {
                        let invite = try GroupInvite(dictionary: data, id: doc.documentID)
                        invites.append(invite)
                    } catch {
                        print("Error parsing invite: \(error)")
                    }
                }
            }
            
            await MainActor.run {
                self.pendingInvites = invites
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            throw error
        }
    }
    
    // Accept a group invite
    func acceptInvite(inviteId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupServiceError.notAuthenticated
        }
        
        // Get the invite
        let inviteRef = db.collection("users")
            .document(userId)
            .collection("groupInvites")
            .document(inviteId)
        
        let inviteDoc = try await inviteRef.getDocument()
        
        guard let inviteData = inviteDoc.data(), inviteDoc.exists else {
            throw GroupServiceError.inviteNotFound
        }
        
        guard let groupId = inviteData["groupId"] as? String else {
            throw GroupServiceError.invalidData
        }
        
        // Update the invite status
        try await inviteRef.updateData([
            "status": GroupInvite.InviteStatus.accepted.rawValue
        ])
        
        // Add the user as a member of the group
        let timestamp = Timestamp(date: Date())
        let memberRef = db.collection("groups")
            .document(groupId)
            .collection("members")
            .document(userId)
        
        try await memberRef.setData([
            "userId": userId,
            "role": GroupMember.MemberRole.member.rawValue,
            "joinedAt": timestamp
        ])
        
        // Add the group to the user's groups collection
        let userGroupRef = db.collection("users")
            .document(userId)
            .collection("groups")
            .document(groupId)
        
        try await userGroupRef.setData([
            "groupId": groupId,
            "joinedAt": timestamp,
            "role": GroupMember.MemberRole.member.rawValue
        ])
        
        // Increment the group's member count
        let groupRef = db.collection("groups").document(groupId)
        try await groupRef.updateData([
            "memberCount": FieldValue.increment(Int64(1))
        ])
        
        // Update the local pending invites list
        await MainActor.run {
            self.pendingInvites.removeAll { $0.id == inviteId }
        }
        
        // Refresh the user's groups
        try await fetchUserGroups()
    }
    
    // Decline a group invite
    func declineInvite(inviteId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupServiceError.notAuthenticated
        }
        
        // Update the invite status
        let inviteRef = db.collection("users")
            .document(userId)
            .collection("groupInvites")
            .document(inviteId)
        
        try await inviteRef.updateData([
            "status": GroupInvite.InviteStatus.declined.rawValue
        ])
        
        // Update the local pending invites list
        await MainActor.run {
            self.pendingInvites.removeAll { $0.id == inviteId }
        }
    }
    
    // Leave a group
    func leaveGroup(groupId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupServiceError.notAuthenticated
        }
        
        // Get the group to check if the user is the owner
        let groupDoc = try await db.collection("groups").document(groupId).getDocument()
        
        guard let groupData = groupDoc.data(), groupDoc.exists else {
            throw GroupServiceError.groupNotFound
        }
        
        let ownerId = groupData["ownerId"] as? String
        
        // Owner cannot leave the group (they must delete it or transfer ownership)
        if ownerId == userId {
            throw GroupServiceError.ownerCannotLeave
        }
        
        // Remove the user from the group's members
        let memberRef = db.collection("groups")
            .document(groupId)
            .collection("members")
            .document(userId)
        
        try await memberRef.delete()
        
        // Remove the group from the user's groups
        let userGroupRef = db.collection("users")
            .document(userId)
            .collection("groups")
            .document(groupId)
        
        try await userGroupRef.delete()
        
        // Decrement the group's member count
        let groupRef = db.collection("groups").document(groupId)
        try await groupRef.updateData([
            "memberCount": FieldValue.increment(Int64(-1))
        ])
        
        // Update the local groups list
        await MainActor.run {
            self.userGroups.removeAll { $0.id == groupId }
        }
    }
    
    // Fetch users for the invite dropdown
    func fetchAvailableUsers() async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw GroupServiceError.notAuthenticated
        }
        
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let snapshot = try await db.collection("users")
                .getDocuments()
            
            var users: [UserListItem] = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                let userId = doc.documentID
                
                // Don't include the current user
                if userId == currentUserId {
                    continue
                }
                
                if let username = data["username"] as? String {
                    let displayName = data["displayName"] as? String
                    let avatarURL = data["avatarURL"] as? String
                    
                    let user = UserListItem(
                        id: userId,
                        username: username,
                        displayName: displayName,
                        avatarURL: avatarURL
                    )
                    
                    users.append(user)
                }
            }
            
            // Sort by username
            users.sort { $0.username < $1.username }
            
            await MainActor.run {
                self.availableUsers = users
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            throw error
        }
    }
    
    // Fetch all members of a group
    func fetchGroupMembers(groupId: String) async throws {
        guard Auth.auth().currentUser != nil else {
            throw GroupServiceError.notAuthenticated
        }
        
        await MainActor.run {
            self.isLoading = true
            self.groupMembers = []
        }
        
        do {
            // Get all members from the group's members collection
            let snapshot = try await db.collection("groups")
                .document(groupId)
                .collection("members")
                .getDocuments()
            
            var members: [GroupMemberInfo] = []
            
            // For each member, get their user profile
            for doc in snapshot.documents {
                let data = doc.data()
                let userId = doc.documentID
                
                if let role = data["role"] as? String,
                   let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue() {
                    
                    // Get the user's profile
                    let userDoc = try await db.collection("users")
                        .document(userId)
                        .getDocument()
                    
                    if let userData = userDoc.data() {
                        let username = userData["username"] as? String ?? "Unknown"
                        let displayName = userData["displayName"] as? String
                        let avatarURL = userData["avatarURL"] as? String
                        
                        let member = GroupMemberInfo(
                            id: userId,
                            username: username,
                            displayName: displayName,
                            avatarURL: avatarURL,
                            role: role,
                            joinedAt: joinedAt
                        )
                        
                        members.append(member)
                    }
                }
            }
            
            // Sort by role (owner first) then by join date
            members.sort { member1, member2 in
                if member1.role == GroupMember.MemberRole.owner.rawValue && 
                   member2.role != GroupMember.MemberRole.owner.rawValue {
                    return true
                } else if member1.role != GroupMember.MemberRole.owner.rawValue && 
                          member2.role == GroupMember.MemberRole.owner.rawValue {
                    return false
                } else {
                    return member1.joinedAt < member2.joinedAt
                }
            }
            
            await MainActor.run {
                self.groupMembers = members
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            throw error
        }
    }
    
    // Upload a group profile image
    func uploadGroupImage(_ image: UIImage, groupId: String) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupServiceError.notAuthenticated
        }
        
        // Check if the user is the group owner
        let groupDoc = try await db.collection("groups")
            .document(groupId)
            .getDocument()
        
        guard let groupData = groupDoc.data(),
              let ownerId = groupData["ownerId"] as? String,
              ownerId == userId else {
            throw GroupServiceError.permissionDenied
        }
        
        // Upload the image to Firebase Storage
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw GroupServiceError.invalidData
        }
        
        let storageRef = storage.reference().child("group_images/\(groupId).jpg")
        
        // Upload the image
        _ = try await storageRef.putData(imageData, metadata: nil)
        
        // Get the download URL
        let downloadURL = try await storageRef.downloadURL()
        let httpsUrlString = downloadURL.absoluteString
        
        // Update the group's avatarURL field
        try await db.collection("groups")
            .document(groupId)
            .updateData(["avatarURL": httpsUrlString])
        
        // Update the group in the local list
        await MainActor.run {
            if let index = self.userGroups.firstIndex(where: { $0.id == groupId }) {
                self.userGroups[index].avatarURL = httpsUrlString
            }
        }
        
        return httpsUrlString
    }
    
    // MARK: - Chat Methods
    
    // Fetch messages for a group with pagination
    func fetchGroupMessages(groupId: String, limit: Int = 30, beforeTimestamp: Date? = nil) async throws {
        guard Auth.auth().currentUser != nil else {
            throw GroupServiceError.notAuthenticated
        }
        
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            // Create a query for the messages collection
            var query = db.collection("groups")
                .document(groupId)
                .collection("messages")
                .order(by: "timestamp", descending: true)
                .limit(to: limit)
            
            // Add pagination if provided
            if let beforeTimestamp = beforeTimestamp {
                query = query.whereField("timestamp", isLessThan: Timestamp(date: beforeTimestamp))
            }
            
            // Execute the query
            let snapshot = try await query.getDocuments()
            
            var messages: [GroupMessage] = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                do {
                    let message = try GroupMessage(dictionary: data, id: doc.documentID)
                    messages.append(message)
                } catch {
                    print("Error parsing message: \(error)")
                }
            }
            
            // Sort by timestamp (newest last)
            messages.sort { $0.timestamp < $1.timestamp }
            
            await MainActor.run {
                if beforeTimestamp == nil {
                    // First load, replace all messages
                    self.groupMessages = messages
                } else {
                    // Pagination load, add to existing messages
                    self.groupMessages.insert(contentsOf: messages, at: 0)
                }
                self.isLoading = false
            }
            
            // Set up a listener for new messages
            if beforeTimestamp == nil {
                // Only set up listener on initial load
                setupMessageListener(groupId: groupId)
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            throw error
        }
    }
    
    // Listen for new messages
    private func setupMessageListener(groupId: String) {
        db.collection("groups")
            .document(groupId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .whereField("timestamp", isGreaterThan: Timestamp(date: Date()))
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot else {
                    print("Error listening for messages: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                for change in snapshot.documentChanges {
                    if change.type == .added {
                        do {
                            let message = try GroupMessage(dictionary: change.document.data(), id: change.document.documentID)
                            DispatchQueue.main.async {
                                self.groupMessages.append(message)
                            }
                        } catch {
                            print("Error parsing new message: \(error)")
                        }
                    }
                }
            }
    }
    
    // Send a text message
    func sendTextMessage(groupId: String, text: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupServiceError.notAuthenticated
        }
        
        // Get the user's info
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let userData = userDoc.data() else {
            throw GroupServiceError.invalidData
        }
        
        let username = userData["username"] as? String ?? "Unknown"
        let displayName = userData["displayName"] as? String
        let senderName = displayName ?? username
        let avatarURL = userData["avatarURL"] as? String
        
        // Create a message document
        let messageRef = db.collection("groups")
            .document(groupId)
            .collection("messages")
            .document()
        
        let timestamp = Timestamp(date: Date())
        
        let messageData: [String: Any] = [
            "groupId": groupId,
            "senderId": userId,
            "senderName": senderName,
            "senderAvatarURL": avatarURL as Any,
            "timestamp": timestamp,
            "messageType": GroupMessage.MessageType.text.rawValue,
            "text": text
        ]
        
        // Save the message
        try await messageRef.setData(messageData)
    }
    
    // Send an image message
    func sendImageMessage(groupId: String, image: UIImage) async throws {
        print("GROUP SERVICE: Starting image upload for group \(groupId)")
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("GROUP SERVICE: Not authenticated")
            throw GroupServiceError.notAuthenticated
        }
        
        // Get the user's info
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let userData = userDoc.data() else {
            print("GROUP SERVICE: Invalid user data")
            throw GroupServiceError.invalidData
        }
        
        let username = userData["username"] as? String ?? "Unknown"
        let displayName = userData["displayName"] as? String
        let senderName = displayName ?? username
        let avatarURL = userData["avatarURL"] as? String
        
        print("GROUP SERVICE: Processing image for upload")
        
        // Resize large images before uploading to reduce storage and bandwidth
        let maxSize: CGFloat = 1200
        let resizedImage: UIImage
        
        if image.size.width > maxSize || image.size.height > maxSize {
            let scale = maxSize / max(image.size.width, image.size.height)
            let newWidth = image.size.width * scale
            let newHeight = image.size.height * scale
            let newSize = CGSize(width: newWidth, height: newHeight)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                resizedImage = resized
            } else {
                resizedImage = image
            }
            UIGraphicsEndImageContext()
            
            print("GROUP SERVICE: Resized image from \(image.size) to \(resizedImage.size)")
        } else {
            resizedImage = image
        }
        
        // Try multiple compression levels if needed
        var compressionQuality: CGFloat = 0.7
        var imageData = resizedImage.jpegData(compressionQuality: compressionQuality)
        
        // If we still don't have image data, try PNG as a fallback
        if imageData == nil {
            print("GROUP SERVICE: JPEG compression failed, trying PNG")
            imageData = resizedImage.pngData()
        }
        
        guard let finalImageData = imageData else {
            print("GROUP SERVICE: Failed to create image data with any format")
            throw GroupServiceError.invalidData
        }
        
        print("GROUP SERVICE: Image data created: \(finalImageData.count) bytes")
        
        let uuid = UUID().uuidString
        let storageFileName = "\(uuid).jpg"
        let storageRef = storage.reference().child("group_messages/\(groupId)/\(storageFileName)")
        
        print("GROUP SERVICE: Starting Firebase Storage upload")
        
        // Upload the image to Firebase Storage
        do {
            // 1. Upload the image data first
            _ = try await storageRef.putData(finalImageData, metadata: nil)
            print("GROUP SERVICE: Image uploaded successfully")
            
            // 2. Create the message document first with a placeholder URL
            let messageRef = db.collection("groups")
                .document(groupId)
                .collection("messages")
                .document()
            
            let timestamp = Timestamp(date: Date())
            
            var messageData: [String: Any] = [
                "groupId": groupId,
                "senderId": userId,
                "senderName": senderName,
                "senderAvatarURL": avatarURL as Any,
                "timestamp": timestamp,
                "messageType": GroupMessage.MessageType.image.rawValue,
                "imageStatus": "uploading" // Indicate that the image is being uploaded
            ]
            
            // Save the initial message to indicate upload is in progress
            try await messageRef.setData(messageData)
            
            // 3. Attempt to get the download URL with retry logic
            var downloadURL: URL?
            var retryCount = 0
            let maxRetries = 3
            var lastError: Error?
            
            while downloadURL == nil && retryCount < maxRetries {
                do {
                    if retryCount > 0 {
                        // Add exponential backoff delay
                        let delaySeconds = pow(2.0, Double(retryCount))
                        print("GROUP SERVICE: Retry \(retryCount) after \(delaySeconds) seconds")
                        try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                    }
                    
                    // Try to get the download URL
                    downloadURL = try await storageRef.downloadURL()
                    print("GROUP SERVICE: Got download URL: \(downloadURL?.absoluteString ?? "nil")")
                } catch {
                    lastError = error
                    print("GROUP SERVICE: Error getting download URL (attempt \(retryCount + 1)): \(error.localizedDescription)")
                    retryCount += 1
                }
            }
            
            if let downloadURL = downloadURL {
                // 4. Update the message with the actual image URL
                messageData["imageURL"] = downloadURL.absoluteString
                messageData["imageStatus"] = "complete" // Update status to complete
                
                // Update the message document with the image URL
                try await messageRef.updateData(messageData)
                print("GROUP SERVICE: Message document updated with URL")
            } else {
                // If we still couldn't get the URL after retries, update the message with an error
                try await messageRef.updateData([
                    "imageStatus": "error",
                    "errorMessage": lastError?.localizedDescription ?? "Failed to get image URL"
                ])
                
                throw lastError ?? NSError(domain: "GroupService", code: 1001, 
                    userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve image URL after multiple attempts"])
            }
            
            return
        } catch {
            print("GROUP SERVICE ERROR: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Send a hand history message
    func sendHandMessage(groupId: String, handHistoryId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GroupServiceError.notAuthenticated
        }
        
        // Get the user's info
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let userData = userDoc.data() else {
            throw GroupServiceError.invalidData
        }
        
        let username = userData["username"] as? String ?? "Unknown"
        let displayName = userData["displayName"] as? String
        let senderName = displayName ?? username
        let avatarURL = userData["avatarURL"] as? String
        
        // Create the message document
        let messageRef = db.collection("groups")
            .document(groupId)
            .collection("messages")
            .document()
        
        let timestamp = Timestamp(date: Date())
        
        let messageData: [String: Any] = [
            "groupId": groupId,
            "senderId": userId,
            "senderName": senderName,
            "senderAvatarURL": avatarURL as Any,
            "timestamp": timestamp,
            "messageType": GroupMessage.MessageType.hand.rawValue,
            "handHistoryId": handHistoryId,
            "handOwnerUserId": userId
        ]
        
        // Save the message
        try await messageRef.setData(messageData)
    }
}

enum GroupServiceError: Error, CustomStringConvertible {
    case notAuthenticated
    case groupNotFound
    case userNotFound
    case invalidData
    case userAlreadyMember
    case inviteAlreadyExists
    case inviteNotFound
    case ownerCannotLeave
    case permissionDenied
    
    var description: String {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .groupNotFound:
            return "Group not found"
        case .userNotFound:
            return "User not found"
        case .invalidData:
            return "Invalid data"
        case .userAlreadyMember:
            return "User is already a member of this group"
        case .inviteAlreadyExists:
            return "This user has already been invited to this group"
        case .inviteNotFound:
            return "Invite not found"
        case .ownerCannotLeave:
            return "The owner cannot leave the group"
        case .permissionDenied:
            return "You don't have permission to perform this action"
        }
    }
    
    var message: String {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to perform this action"
        case .groupNotFound:
            return "The group could not be found"
        case .userNotFound:
            return "The user could not be found. Please check the username."
        case .invalidData:
            return "Invalid data provided"
        case .userAlreadyMember:
            return "This user is already a member of this group"
        case .inviteAlreadyExists:
            return "This user has already been invited to this group"
        case .inviteNotFound:
            return "The invite could not be found"
        case .ownerCannotLeave:
            return "You are the owner of this group. You must transfer ownership or delete the group instead."
        case .permissionDenied:
            return "You don't have permission to perform this action"
        }
    }
} 