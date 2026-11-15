// Example of how to use the updated UserList with Add Friend functionality

/*

// In your screen where you want to use UserList:

import 'package:toptap/common/widget/user_list.dart';

class YourScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<YourController>();
    
    return Scaffold(
      body: UserList<User>( // Replace User with your actual user model type
        users: controller.users,
        isLoading: controller.isLoading,
        
        // Required functions to extract data from your user model
        getProfilePhoto: (user) => user.profilePhoto ?? '',
        getUserName: (user) => user.username ?? '',
        getFullName: (user) => user.fullname ?? '',
        getVerified: (user) => user.isVerified ?? 0,
        
        // When user card is tapped (navigate to user profile)
        onTap: (user) {
          // Navigate to user profile
          Get.to(() => ProfileScreen(user: user));
        },
        
        // NEW: When add friend button is tapped
        onAddFriend: (user) {
          // Navigate to your UserList screen or handle add friend action
          print("Add friend tapped for: ${user.fullname}");
          
          // Example: Navigate to another UserList screen
          Get.to(() => AnotherUserListScreen(selectedUser: user));
          
          // Or: Call API to send friend request
          // controller.sendFriendRequest(user);
        },
        
        // Optional: Load more functionality
        loadMore: () async {
          await controller.loadMoreUsers();
        },
      ),
    );
  }
}

*/
