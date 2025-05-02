import SwiftUI
import FirebaseAuth
import PhotosUI

struct GroupsView: View {
    @StateObject private var groupService = GroupService()
    @EnvironmentObject private var userService: UserService
    @EnvironmentObject private var handStore: HandStore
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var postService: PostService
    @State private var showingCreateGroup = false
    @State private var showingInvites = false
    @State private var selectedGroup: UserGroup?
    @State private var showingGroupDetails = false
    @State private var groupActionSheet: UserGroup?
    @State private var error: String?
    @State private var showError = false
    @State private var showingGroupChat = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AppBackgroundView()
                
                VStack(spacing: 0) {
                    // Header with logo and actions
                    HStack {
                        Text("GROUPS")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Notification bell icon (shows if there are pending invites)
                        if !groupService.pendingInvites.isEmpty {
                            Button(action: {
                                showingInvites = true
                            }) {
                                ZStack {
                                    Image(systemName: "bell.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 20))
                                    
                                    // Notification badge
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 12, height: 12)
                                        .offset(x: 8, y: -8)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 0.7)))
                                )
                            }
                        } else {
                            // Show invites button even without notifications
                            Button(action: {
                                showingInvites = true
                            }) {
                                Image(systemName: "bell")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20))
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 0.7)))
                                    )
                            }
                        }
                        
                        // Create group button
                        Button(action: {
                            showingCreateGroup = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 0.7)))
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 16)
                    
                    if groupService.isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Spacer()
                    } else if groupService.userGroups.isEmpty {
                        // Empty state
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "person.3")
                                .font(.system(size: 70))
                                .foregroundColor(.gray)
                            
                            Text("No Groups")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Create a group or wait for invites to join existing groups")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            Button(action: {
                                showingCreateGroup = true
                            }) {
                                Text("Create Group")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 32)
                                    .background(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                                    .cornerRadius(20)
                                    .shadow(color: Color.green.opacity(0.3), radius: 5, y: 2)
                            }
                            .padding(.top, 8)
                        }
                        Spacer()
                    } else {
                        // Groups list
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(groupService.userGroups) { group in
                                    Button {
                                        selectedGroup = group
                                        showingGroupChat = true
                                    } label: {
                                        GroupCard(group: group)
                                            .contextMenu {
                                                Button {
                                                    selectedGroup = group
                                                    showingGroupDetails = true
                                                } label: {
                                                    Label("View Details", systemImage: "info.circle")
                                                }
                                                
                                                Button {
                                                    groupActionSheet = group
                                                } label: {
                                                    Label("Options", systemImage: "ellipsis.circle")
                                                }
                                            }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            .padding(.bottom, 100) // Add padding at bottom for tab bar
                        }
                    }
                }
                .alert(isPresented: $showError, content: {
                    Alert(
                        title: Text("Error"),
                        message: Text(error ?? "An unknown error occurred"),
                        dismissButton: .default(Text("OK"))
                    )
                })
                .sheet(isPresented: $showingCreateGroup) {
                    CreateGroupView { success in
                        if success {
                            Task {
                                await refreshGroups()
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingInvites) {
                    GroupInvitesView {
                        Task {
                            await refreshGroups()
                        }
                    }
                }
                .sheet(isPresented: $showingGroupDetails) {
                    if let group = selectedGroup {
                        GroupDetailView(group: group)
                    }
                }
                .sheet(isPresented: $showingGroupChat) {
                    if let group = selectedGroup {
                        GroupChatView(group: group)
                            .environmentObject(userService)
                            .environmentObject(handStore)
                            .environmentObject(sessionStore)
                            .environmentObject(postService)
                    }
                }
                .confirmationDialog("Group Options", isPresented: .init(
                    get: { groupActionSheet != nil },
                    set: { if !$0 { groupActionSheet = nil } }
                ), titleVisibility: .visible) {
                    if let group = groupActionSheet {
                        Button("View Details") {
                            selectedGroup = group
                            showingGroupDetails = true
                        }
                        
                        Button("Invite Members") {
                            selectedGroup = group
                            showingGroupDetails = true
                        }
                        
                        if group.ownerId != Auth.auth().currentUser?.uid {
                            Button("Leave Group", role: .destructive) {
                                Task {
                                    await leaveGroup(group: group)
                                }
                            }
                        }
                        
                        Button("Cancel", role: .cancel) {
                            groupActionSheet = nil
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await refreshGroups()
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func refreshGroups() async {
        do {
            try await groupService.fetchUserGroups()
            try await groupService.fetchPendingInvites()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }
    
    private func leaveGroup(group: UserGroup) async {
        do {
            try await groupService.leaveGroup(groupId: group.id)
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }
}

struct GroupCard: View {
    let group: UserGroup
    
    var body: some View {
        HStack(spacing: 16) {
            // Group avatar or placeholder
            ZStack {
                Circle()
                    .fill(Color(UIColor(red: 40/255, green: 40/255, blue: 50/255, alpha: 1.0)))
                    .frame(width: 60, height: 60)
                
                if let avatarURL = group.avatarURL, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                HStack {
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text("\(group.memberCount) member\(group.memberCount != 1 ? "s" : "")")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.system(size: 14))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor(red: 30/255, green: 30/255, blue: 35/255, alpha: 0.7)))
        )
    }
}

struct CreateGroupView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var groupService = GroupService()
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var isCreating = false
    @State private var error: String?
    @State private var showError = false
    
    let onComplete: (Bool) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                AppBackgroundView()
                
                VStack(spacing: 24) {
                    Text("Create New Group")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 24)
                    
                    VStack(spacing: 16) {
                        TextField("Group Name", text: $groupName)
                            .padding()
                            .background(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 1.0)))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                        
                        TextField("Description (Optional)", text: $groupDescription)
                            .padding()
                            .background(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 1.0)))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    
                    Button(action: {
                        createGroup()
                    }) {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Text("Create Group")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 15)
                    .background(
                        groupName.isEmpty || isCreating
                            ? Color.green.opacity(0.5)
                            : Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0))
                    )
                    .cornerRadius(10)
                    .padding(.horizontal, 24)
                    .disabled(groupName.isEmpty || isCreating)
                    
                    Spacer()
                }
                .alert(isPresented: $showError, content: {
                    Alert(
                        title: Text("Error"),
                        message: Text(error ?? "An unknown error occurred"),
                        dismissButton: .default(Text("OK"))
                    )
                })
            }
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
            )
        }
    }
    
    private func createGroup() {
        guard !groupName.isEmpty else { return }
        
        isCreating = true
        
        Task {
            do {
                let description = groupDescription.isEmpty ? nil : groupDescription
                _ = try await groupService.createGroup(name: groupName, description: description)
                
                await MainActor.run {
                    isCreating = false
                    onComplete(true)
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.showError = true
                    isCreating = false
                }
            }
        }
    }
}

struct GroupInvitesView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var groupService = GroupService()
    @State private var isLoading = true
    @State private var error: String?
    @State private var showError = false
    
    let onComplete: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                AppBackgroundView()
                
                VStack(spacing: 16) {
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Spacer()
                    } else if groupService.pendingInvites.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No Invites")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("You don't have any pending group invites")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(groupService.pendingInvites) { invite in
                                    InviteCard(invite: invite, onAccept: {
                                        acceptInvite(invite: invite)
                                    }, onDecline: {
                                        declineInvite(invite: invite)
                                    })
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        }
                    }
                }
                .alert(isPresented: $showError, content: {
                    Alert(
                        title: Text("Error"),
                        message: Text(error ?? "An unknown error occurred"),
                        dismissButton: .default(Text("OK"))
                    )
                })
            }
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                },
                trailing: Text("Group Invites")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            )
            .onAppear {
                Task {
                    await loadInvites()
                }
            }
        }
    }
    
    private func loadInvites() async {
        isLoading = true
        
        do {
            try await groupService.fetchPendingInvites()
            
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.showError = true
                isLoading = false
            }
        }
    }
    
    private func acceptInvite(invite: GroupInvite) {
        Task {
            do {
                try await groupService.acceptInvite(inviteId: invite.id)
                onComplete()
                
                // If there are no more invites, dismiss the sheet
                if groupService.pendingInvites.isEmpty {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
    
    private func declineInvite(invite: GroupInvite) {
        Task {
            do {
                try await groupService.declineInvite(inviteId: invite.id)
                
                // If there are no more invites, dismiss the sheet
                if groupService.pendingInvites.isEmpty {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}

struct InviteCard: View {
    let invite: GroupInvite
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                    .frame(width: 36, height: 36)
                    .background(Color(UIColor(red: 40/255, green: 60/255, blue: 40/255, alpha: 1.0)))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(invite.groupName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Invited by \(invite.inviterName)")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(action: onAccept) {
                    Text("Accept")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                        .cornerRadius(8)
                }
                
                Button(action: onDecline) {
                    Text("Decline")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(UIColor(red: 70/255, green: 70/255, blue: 75/255, alpha: 1.0)))
                        .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor(red: 30/255, green: 30/255, blue: 35/255, alpha: 0.7)))
        )
    }
}

struct GroupDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var groupService = GroupService()
    let group: UserGroup
    @State private var selectedUser: UserListItem?
    @State private var searchText = ""
    @State private var isInviting = false
    @State private var error: String?
    @State private var showError = false
    @State private var inviteSuccess = false
    @State private var isDropdownVisible = false
    @State private var isLoadingUsers = false
    @State private var isLoadingMembers = false
    @State private var selectedTab = 0 // 0 = Info, 1 = Members, 2 = Invites
    
    // For image upload
    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var imagePickerItem: PhotosPickerItem?
    @State private var isUploadingImage = false
    
    // If the current user is the owner
    var isOwner: Bool {
        return group.ownerId == Auth.auth().currentUser?.uid
    }
    
    var filteredUsers: [UserListItem] {
        if searchText.isEmpty {
            return groupService.availableUsers
        } else {
            return groupService.availableUsers.filter { user in
                user.username.lowercased().contains(searchText.lowercased()) || 
                (user.displayName?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                AppBackgroundView()
                
                VStack(spacing: 0) {
                    // Group info header
                    VStack(spacing: 16) {
                        // Group avatar
                        ZStack {
                            Circle()
                                .fill(Color(UIColor(red: 40/255, green: 40/255, blue: 50/255, alpha: 1.0)))
                                .frame(width: 100, height: 100)
                            
                            if let selectedImage = selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if let avatarURL = group.avatarURL, let url = URL(string: avatarURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                            
                            // Camera icon for uploading if owner
                            if isOwner {
                                PhotosPicker(selection: $imagePickerItem, matching: .images) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 0.8)))
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    }
                                }
                                .onChange(of: imagePickerItem) { newItem in
                                    loadTransferableImage(from: newItem)
                                }
                                .position(x: 75, y: 75)
                            }
                            
                            // Loading indicator during upload
                            if isUploadingImage {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 100, height: 100)
                                    
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                }
                            }
                        }
                        
                        Text(group.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        if let description = group.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        HStack {
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text("\(group.memberCount) member\(group.memberCount != 1 ? "s" : "")")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                    
                    // Tab selector
                    HStack(spacing: 0) {
                        GroupTabButton(text: "Info", isSelected: selectedTab == 0) {
                            selectedTab = 0
                        }
                        
                        GroupTabButton(text: "Members", isSelected: selectedTab == 1) {
                            selectedTab = 1
                            loadGroupMembers()
                        }
                        
                        GroupTabButton(text: "Invite", isSelected: selectedTab == 2) {
                            selectedTab = 2
                            loadUsers()
                        }
                    }
                    .background(Color(UIColor(red: 30/255, green: 30/255, blue: 35/255, alpha: 1.0)))
                    .cornerRadius(10)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    
                    // Content based on selected tab
                    ScrollView {
                        if selectedTab == 0 {
                            // Group Info Tab
                            GroupInfoView(group: group)
                        } else if selectedTab == 1 {
                            // Members Tab
                            MembersView(
                                groupService: groupService,
                                isLoadingMembers: isLoadingMembers
                            )
                        } else {
                            // Invite Tab
                            InviteView(
                                groupService: groupService,
                                groupId: group.id,
                                selectedUser: $selectedUser,
                                searchText: $searchText,
                                isInviting: $isInviting,
                                inviteSuccess: $inviteSuccess,
                                isDropdownVisible: $isDropdownVisible,
                                isLoadingUsers: isLoadingUsers,
                                filteredUsers: filteredUsers,
                                inviteUser: inviteUser
                            )
                        }
                    }
                    .padding(.bottom, 16)
                }
                .alert(isPresented: $showError, content: {
                    Alert(
                        title: Text("Error"),
                        message: Text(error ?? "An unknown error occurred"),
                        dismissButton: .default(Text("OK"))
                    )
                })
            }
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                },
                trailing: Text(group.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            )
            .onAppear {
                if selectedTab == 1 {
                    loadGroupMembers()
                } else if selectedTab == 2 {
                    loadUsers()
                }
            }
            .onTapGesture {
                // Hide dropdown when tapping outside
                isDropdownVisible = false
            }
        }
    }
    
    private func loadTransferableImage(from imageSelection: PhotosPickerItem?) {
        guard let imageSelection else { return }
        
        Task {
            do {
                if let data = try await imageSelection.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = image
                        uploadGroupImage(image)
                    }
                }
            } catch {
                print("Error loading image: \(error)")
            }
        }
    }
    
    private func uploadGroupImage(_ image: UIImage) {
        isUploadingImage = true
        
        Task {
            do {
                _ = try await groupService.uploadGroupImage(image, groupId: group.id)
                
                await MainActor.run {
                    isUploadingImage = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.showError = true
                    isUploadingImage = false
                }
            }
        }
    }
    
    private func loadUsers() {
        isLoadingUsers = true
        Task {
            do {
                try await groupService.fetchAvailableUsers()
                await MainActor.run {
                    isLoadingUsers = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.showError = true
                    isLoadingUsers = false
                }
            }
        }
    }
    
    private func loadGroupMembers() {
        isLoadingMembers = true
        Task {
            do {
                try await groupService.fetchGroupMembers(groupId: group.id)
                await MainActor.run {
                    isLoadingMembers = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.showError = true
                    isLoadingMembers = false
                }
            }
        }
    }
    
    private func inviteUser() {
        guard let selectedUser = selectedUser else { return }
        
        isInviting = true
        inviteSuccess = false
        
        Task {
            do {
                try await groupService.inviteUserToGroup(username: selectedUser.username, groupId: group.id)
                
                await MainActor.run {
                    isInviting = false
                    self.selectedUser = nil
                    searchText = ""
                    inviteSuccess = true
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.showError = true
                    isInviting = false
                }
            }
        }
    }
}

// Sub-views for GroupDetailView
struct GroupInfoView: View {
    let group: UserGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Group Details section
            VStack(alignment: .leading, spacing: 8) {
                Text("Group Details")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Created")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(formattedDate(group.createdAt))
                            .foregroundColor(.white)
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    HStack {
                        Text("Members")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(group.memberCount)")
                            .foregroundColor(.white)
                    }
                }
                .padding(16)
                .background(Color(UIColor(red: 30/255, green: 30/255, blue: 35/255, alpha: 0.7)))
                .cornerRadius(10)
                .padding(.horizontal, 16)
            }
            
            if let description = group.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                    Text(description)
                        .foregroundColor(.white)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor(red: 30/255, green: 30/255, blue: 35/255, alpha: 0.7)))
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                }
            }
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct MembersView: View {
    let groupService: GroupService
    let isLoadingMembers: Bool
    
    var body: some View {
        if isLoadingMembers {
            VStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                Spacer()
            }
            .frame(height: 200)
        } else if groupService.groupMembers.isEmpty {
            VStack {
                Spacer()
                Text("No members found")
                    .foregroundColor(.gray)
                Spacer()
            }
            .frame(height: 200)
        } else {
            VStack(spacing: 16) {
                ForEach(groupService.groupMembers) { member in
                    MemberRow(member: member)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct MemberRow: View {
    let member: GroupMemberInfo
    
    var body: some View {
        HStack(spacing: 12) {
            // Member avatar
            ZStack {
                Circle()
                    .fill(Color(UIColor(red: 40/255, green: 40/255, blue: 50/255, alpha: 1.0)))
                    .frame(width: 48, height: 48)
                
                if let avatarURL = member.avatarURL, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                }
            }
            
            // Member info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let displayName = member.displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Text("@\(member.username)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    if member.isOwner {
                        Text("Owner")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                            .cornerRadius(4)
                    }
                }
                
                if member.displayName != nil {
                    Text("@\(member.username)")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Text("Joined \(formattedDate(member.joinedAt))")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(UIColor(red: 30/255, green: 30/255, blue: 35/255, alpha: 0.7)))
        .cornerRadius(10)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct InviteView: View {
    let groupService: GroupService
    let groupId: String
    @Binding var selectedUser: UserListItem?
    @Binding var searchText: String
    @Binding var isInviting: Bool
    @Binding var inviteSuccess: Bool
    @Binding var isDropdownVisible: Bool
    let isLoadingUsers: Bool
    let filteredUsers: [UserListItem]
    let inviteUser: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Invite Members")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
            
            // Custom dropdown field with search
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .trailing) {
                    TextField("Search users...", text: $searchText)
                        .padding()
                        .background(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 1.0)))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: searchText) { _ in
                            isDropdownVisible = true
                        }
                        .onTapGesture {
                            isDropdownVisible = true
                        }
                    
                    if isLoadingUsers {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(.trailing, 12)
                    } else {
                        Button(action: {
                            isDropdownVisible.toggle()
                        }) {
                            Image(systemName: isDropdownVisible ? "chevron.up" : "chevron.down")
                                .foregroundColor(.gray)
                                .padding(.trailing, 12)
                        }
                    }
                }
                
                // Dropdown menu
                if isDropdownVisible && !filteredUsers.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredUsers) { user in
                                HStack {
                                    // User avatar
                                    ZStack {
                                        Circle()
                                            .fill(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 1.0)))
                                            .frame(width: 36, height: 36)
                                        
                                        if let avatarURL = user.avatarURL, let url = URL(string: avatarURL) {
                                            AsyncImage(url: url) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                ProgressView()
                                            }
                                            .frame(width: 36, height: 36)
                                            .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(.leading, 8)
                                    
                                    // User info
                                    VStack(alignment: .leading) {
                                        if let displayName = user.displayName, !displayName.isEmpty {
                                            Text(displayName)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white)
                                            
                                            Text("@\(user.username)")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        } else {
                                            Text("@\(user.username)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.leading, 8)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                                .background(selectedUser?.id == user.id ? Color(UIColor(red: 50/255, green: 50/255, blue: 55/255, alpha: 1.0)) : Color.clear)
                                .onTapGesture {
                                    selectedUser = user
                                    searchText = user.displayText
                                    isDropdownVisible = false
                                }
                            }
                        }
                    }
                    .background(Color(UIColor(red: 30/255, green: 30/255, blue: 35/255, alpha: 1.0)))
                    .frame(maxHeight: 200)
                    .cornerRadius(10)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            
            // Invite button
            Button(action: inviteUser) {
                if isInviting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .frame(width: 20, height: 20)
                        .padding(.horizontal, 20)
                } else {
                    Text("Invite")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 15)
            .background(
                selectedUser == nil || isInviting
                    ? Color.green.opacity(0.5)
                    : Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0))
            )
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .disabled(selectedUser == nil || isInviting)
            
            if inviteSuccess {
                Text("Invitation sent!")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
            }
        }
    }
}

struct GroupTabButton: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 1.0)) : Color.clear)
                .cornerRadius(8)
        }
    }
} 
