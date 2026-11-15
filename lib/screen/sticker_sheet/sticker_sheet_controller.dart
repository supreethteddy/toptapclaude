import 'package:get/get.dart';
import 'package:toptap/model/sticker/sticker_model.dart';
import 'package:toptap/services/giphy_service.dart';

class StickerSheetController extends GetxController {
  // State
  RxList<StickerModel> stickers = <StickerModel>[].obs;
  RxBool isLoading = false.obs;
  RxString selectedCategory = 'Trending'.obs;
  RxString searchQuery = ''.obs;

  // Categories
  final List<String> categories = [
    'Trending',
    'Emoji',
    'Love',
    'Funny',
    'Happy',
    'Sad',
    'Dance',
    'Animals',
  ];

  @override
  void onInit() {
    super.onInit();
    loadTrendingStickers();
  }

  /// Load trending stickers
  Future<void> loadTrendingStickers() async {
    isLoading.value = true;
    try {
      final result =
          await GiphyService.getTrendingStickers(limit: 50);
      stickers.value = result;
    } catch (e) {
      stickers.value = [];
    } finally {
      isLoading.value = false;
    }
  }

  /// Search stickers
  Future<void> searchStickers(String query) async {
    searchQuery.value = query;
    if (query.isEmpty) {
      loadTrendingStickers();
      return;
    }

    isLoading.value = true;
    try {
      final result = await GiphyService.searchStickers(
          query,
          limit: 50);
      stickers.value = result;
    } catch (e) {
      stickers.value = [];
    } finally {
      isLoading.value = false;
    }
  }

  /// Load stickers by category
  Future<void> loadCategory(String category) async {
    selectedCategory.value = category;
    searchQuery.value = '';

    if (category == 'Trending') {
      loadTrendingStickers();
      return;
    }

    isLoading.value = true;
    try {
      final result =
          await GiphyService.getStickersByCategory(
        category.toLowerCase(),
        limit: 50,
      );
      stickers.value = result;
    } catch (e) {
      stickers.value = [];
    } finally {
      isLoading.value = false;
    }
  }

  /// On sticker selected
  void onStickerSelected(StickerModel sticker) {
    Get.back(result: sticker);
  }
}
