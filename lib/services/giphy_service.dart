import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:toptap/model/sticker/sticker_model.dart';
import 'package:toptap/common/manager/logger.dart';

class GiphyService {
  // Free API Key - Get yours at: https://developers.giphy.com/
  static const String _apiKey =
      'WlBRCW21M2SCZRaARkx5hHa97AtEMB7L';
  static const String _baseUrl =
      'https://api.giphy.com/v1/stickers';

  /// Fetch trending stickers (static only)
  static Future<List<StickerModel>> getTrendingStickers({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final url = Uri.parse(
          '$_baseUrl/trending?api_key=$_apiKey&limit=$limit&offset=$offset&rating=g');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List stickers = data['data'] ?? [];
        // Return stickers (will use still image URLs from model)
        return stickers
            .map((json) => StickerModel.fromGiphy(json))
            .toList();
      } else {
        Loggers.error(
            'Giphy API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      Loggers.error('Giphy fetch error: $e');
      return [];
    }
  }

  /// Search stickers by keyword (static only)
  static Future<List<StickerModel>> searchStickers(
    String query, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (query.isEmpty)
      return getTrendingStickers(
          limit: limit, offset: offset);

    try {
      final url = Uri.parse(
          '$_baseUrl/search?api_key=$_apiKey&q=$query&limit=$limit&offset=$offset&rating=g');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List stickers = data['data'] ?? [];
        // Return stickers (will use still image URLs from model)
        return stickers
            .map((json) => StickerModel.fromGiphy(json))
            .toList();
      } else {
        Loggers.error(
            'Giphy search error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      Loggers.error('Giphy search error: $e');
      return [];
    }
  }

  /// Get stickers by category
  static Future<List<StickerModel>> getStickersByCategory(
    String category, {
    int limit = 50,
  }) async {
    return searchStickers(category, limit: limit);
  }
}
