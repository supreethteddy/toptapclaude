// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:toptap/common/widget/loader_widget.dart';
// import 'package:toptap/common/widget/my_refresh_indicator.dart';
// import 'package:toptap/common/widget/no_data_widget.dart';
// import 'package:toptap/common/widget/post_list.dart';
// import 'package:toptap/languages/languages_keys.dart';
// import 'package:toptap/model/user_model/user_model.dart';
// import 'package:toptap/screen/feed_screen/feed_screen_controller.dart';
// import 'package:toptap/screen/feed_screen/widget/feed_top_view.dart';
// import 'package:toptap/screen/feed_screen/widget/story_view.dart';

// class FeedScreen extends StatelessWidget {
//   final User? myUser;

//   const FeedScreen({super.key, this.myUser});

//   @override
//   Widget build(BuildContext context) {
//     final controller = Get.put(FeedScreenController(myUser.obs));
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         FeedTopView(controller: controller),
//         Expanded(
//             child: MyRefreshIndicator(
//           refreshKey: controller.refreshKey,
//           onRefresh: controller.onRefresh,
//           shouldRefresh: true,
//           child: Stack(
//             children: [
//               Obx(() {
//                 if (!controller.isLoading.value && controller.posts.isEmpty) {
//                   return Stack(
//                     children: [
//                       NoDataView(
//                           safeAreaTop: false,
//                           title: LKey.noUserPostsTitle.tr,
//                           description: LKey.noUserPostsDescription.tr),
//                       SingleChildScrollView(
//                         child: SizedBox(
//                             width: double.infinity, height: Get.height),
//                       ),
//                     ],
//                   );
//                 }
//                 if (controller.isLoading.value && controller.posts.isEmpty) {
//                   return const LoaderWidget();
//                 }
//                 return const SizedBox();
//               }),
//               SingleChildScrollView(
//                 controller: controller.postScrollController,
//                 physics: const AlwaysScrollableScrollPhysics(),
//                 // Allows bouncing on edge

//                 child: Column(
//                   children: [
//                     StoryView(controller: controller),
//                     PostList(
//                         posts: controller.posts,
//                         isLoading: false.obs,
//                         shrinkWrap: true,
//                         showNoData: false)
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ))
//       ],
//     );
//   }
// }
