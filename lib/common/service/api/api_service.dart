import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:toptap/common/functions/debounce_action.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/service/utils/params.dart';
import 'package:toptap/screen/session_expired_screen/session_expired_screen.dart';
import 'package:toptap/utilities/const_res.dart';

class CancelToken {
  bool _isCancelled = false;
  final Set<VoidCallback> _cancelListeners = {};

  bool get isCancelled => _isCancelled;

  void addCancelListener(VoidCallback listener) {
    if (_isCancelled) {
      listener();
      return;
    }
    _cancelListeners.add(listener);
  }

  void removeCancelListener(VoidCallback listener) {
    _cancelListeners.remove(listener);
  }

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in _cancelListeners.toList()) {
      listener();
    }
    _cancelListeners.clear();
  }

  void dispose() {
    _isCancelled = false;
    _cancelListeners.clear();
  }
}

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();
  static const String _emptyAuthTokenPlaceholder = 'AUTH TOKEN EMPTY';

  final Map<CancelToken, http.Client> _activeClients = {};

  Future<T> call<T>({
    required String url,
    Map<String, dynamic>? param,
    CancelToken? cancelToken,
    bool cancelAuthToken = false,
    T Function(Map<String, dynamic> json)? fromJson,
  }) async {
    final token = cancelToken;
    final client = http.Client();
    VoidCallback? onCancel;
    if (token != null) {
      _activeClients[token] = client;
      onCancel = () {
        _activeClients[token]?.close();
        _activeClients.remove(token);
      };
      token.addCancelListener(onCancel);
    }

    Map<String, String> params = {};
    final sanitizedParams = Map<String, dynamic>.from(param ?? {});
    sanitizedParams.removeWhere(
        (key, value) => value == null || value == 'null' || value == '');
    sanitizedParams.forEach((key, value) {
      params[key] = "$value";
    });

    final headers = _buildHeaders(cancelAuthToken: cancelAuthToken);
    Loggers.info("URL: $url");
    // Loggers.info("header: $header");
    Loggers.info("Parameters: ${params.isEmpty ? "Empty" : params}");
    try {
      if (token?.isCancelled ?? false) {
        throw Exception('Request was cancelled');
      }
      final response =
          await client.post(Uri.parse(url), headers: headers, body: params);
      Loggers.success(response.statusCode);
      if (token?.isCancelled ?? false) {
        if (kDebugMode) {
          print("Request cancelled: $url");
        }
        throw Exception('Request was cancelled');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decodedResponse =
            jsonDecode(response.body) as Map<String, dynamic>;

        if (decodedResponse['message'] == 'this user is freezed!') {
          DebounceAction.shared.call(() {
            Get.offAll(
                () => const SessionExpiredScreen(type: SessionType.freeze));
          });
          return decodedResponse as T;
        }

        if (decodedResponse['status'] == false) {
          Loggers.error('API RESPONSE : ${decodedResponse['message']}');
        }

        var prettyString =
            const JsonEncoder.withIndent('  ').convert(decodedResponse);
        Loggers.info(prettyString);

        // Use the provided `fromJson` function to parse the response
        if (fromJson != null) {
          return fromJson(decodedResponse);
        }

        // If no `fromJson` is provided, return the raw response
        return decodedResponse as T;
      } else if (response.statusCode == 401) {
        Loggers.error('Unauthorized Error 401: ${response.statusCode}');
        _handleUnauthorized(cancelAuthToken: cancelAuthToken);
        throw Exception("Unauthorized Error: ${response.statusCode}");
      } else if (response.statusCode == 404) {
        Loggers.error('Please check baseURL in const.dart file');
        throw Exception("URL Error: ${response.statusCode} - $url");
      } else {
        final errorBody = response.body;
        final errorMessage = _extractErrorMessage(errorBody);
        Loggers.error('HTTP Error: $errorMessage');
        // Handle HTTP errors
        throw Exception(
            "HTTP Error: ${response.statusCode} - ${response.reasonPhrase}");
      }
    } on HttpException {
      throw Exception('Could not connect to the server');
    } on FormatException catch (e) {
      // Handle JSON decoding errors
      Loggers.error("Invalid JSON format: ${e.message}");
      throw Exception("Invalid JSON format: ${e.message}");
    } on Exception catch (e) {
      Loggers.error("Unexpected error : $e");
      rethrow;
    } finally {
      if (token != null && onCancel != null) {
        token.removeCancelListener(onCancel);
      }
      _cleanupClient(token, client);
    }
  }

  Map<String, String> _buildHeaders({required bool cancelAuthToken}) {
    final headers = <String, String>{Params.apikey: apiKey};
    if (!cancelAuthToken) {
      final token = _normalizedAuthToken();
      if (token.isNotEmpty) {
        headers[Params.authToken] = token;
      }
    }
    return headers;
  }

  String _normalizedAuthToken() {
    final token = SessionManager.instance.getAuthToken().trim();
    if (token.isEmpty || token == _emptyAuthTokenPlaceholder) {
      return '';
    }
    return token;
  }

  bool _shouldHandleUnauthorized({required bool cancelAuthToken}) {
    if (cancelAuthToken) return false;
    if (!SessionManager.instance.isLogin()) return false;
    return _normalizedAuthToken().isNotEmpty;
  }

  void _handleUnauthorized({required bool cancelAuthToken}) {
    if (!_shouldHandleUnauthorized(cancelAuthToken: cancelAuthToken)) {
      Loggers.warning(
          'Skipping session-expired navigation for a non-authenticated request.');
      return;
    }
    DebounceAction.shared.call(() {
      Get.offAll(() => const SessionExpiredScreen(type: SessionType.unauthorized));
    });
  }

  String _extractErrorMessage(String responseBody) {
    final regex = RegExp(
      r'<!--\s*(.*?)\s*#0 ', // Matches everything between <!-- and #0
      dotAll: true,
    );
    final match = regex.firstMatch(responseBody);
    return match?.group(1)?.trim() ??
        "Unknown error occurred: ${_shorten(responseBody)}";
  }

  /// Shortens the response body if no specific error is found
  String _shorten(String responseBody) {
    const maxLength = 100;
    return responseBody.length > maxLength
        ? "${responseBody.substring(0, maxLength)}..."
        : responseBody;
  }

  Future<T> callGet<T>({required String url}) async {
    http.Response response = await http.get(Uri.parse(url));
    return jsonDecode(response.body);
  }

  Future<T> multiPartCallApi<T>({
    required String url,
    Map<String, dynamic>? param,
    required Map<String, List<XFile?>> filesMap,
    Function(double percentage)? onProgress,
    CancelToken? cancelToken,
    bool cancelAuthToken = false,
    T Function(Map<String, dynamic> json)? fromJson,
  }) async {
    final token = cancelToken;
    final client = http.Client();
    VoidCallback? onCancel;
    if (token != null) {
      _activeClients[token] = client;
      onCancel = () {
        _activeClients[token]?.close();
        _activeClients.remove(token);
      };
      token.addCancelListener(onCancel);
    }

    final request = MultipartRequest(
      'POST',
      Uri.parse(url),
      onProgress: (bytes, totalBytes) {
        if (onProgress != null) {
          onProgress(bytes / totalBytes);
        }
      },
    );

    Map<String, String> params = {};
    param?.removeWhere((key, value) => value == null || value == 'null');
    param?.forEach((key, value) {
      params[key] = "$value";
    });

    request.fields.addAll(params);
    request.headers.addAll(
      _buildHeaders(cancelAuthToken: cancelAuthToken),
    );

    filesMap.forEach((keyName, files) {
      for (var xFile in files) {
        if (xFile != null && xFile.path.isNotEmpty) {
          final file = File(xFile.path);
          final multipartFile = http.MultipartFile(
              keyName, file.readAsBytes().asStream(), file.lengthSync(),
              filename: xFile.name);
          request.files.add(multipartFile);
        }
      }
    });
    Loggers.info("URL : $url");
    Loggers.info("HEADERS : ${request.headers}");
    Loggers.info("FIELDS : ${request.fields}");
    Loggers.info("FILES : ${request.files.map((e) => e)}");
    if (kDebugMode) {
      Loggers.info("Multipart parameters: $param");
    }

    try {
      if (token?.isCancelled ?? false) {
        throw Exception('Request was cancelled');
      }
      final responseStream = await client.send(request);

      if (token?.isCancelled ?? false) {
        if (kDebugMode) {
          Loggers.error("Request cancelled: $url");
        }
        throw Exception('Request was cancelled');
      }

      final responseStatusCode = responseStream.statusCode;
      final responseStr = await responseStream.stream.bytesToString();
      final decodedResponse = _tryDecodeJsonMap(responseStr);

      Loggers.info('Multipart response status: $responseStatusCode');
      if (responseStatusCode >= 400 || decodedResponse == null) {
        Loggers.error(
            'Multipart response body: ${_shorten(responseStr)}');
      }

      if (responseStatusCode == 401) {
        _handleUnauthorized(cancelAuthToken: cancelAuthToken);
        throw Exception('Unauthorized Error: $responseStatusCode');
      }

      if (decodedResponse == null) {
        final errorMessage = _extractErrorMessage(responseStr);
        throw Exception(
            'Upload failed: server returned non-JSON response (HTTP $responseStatusCode). $errorMessage');
      }

      if (responseStatusCode < 200 || responseStatusCode >= 300) {
        final message =
            '${decodedResponse['message'] ?? _extractErrorMessage(responseStr)}';
        throw Exception(
            'Upload failed (HTTP $responseStatusCode): ${message.trim()}');
      }

      if (kDebugMode) {
        // Loggers.info(responseStr);
      }
      if (decodedResponse['status'] == false) {
        Loggers.error(decodedResponse['message']);
      }
      // Use the provided `fromJson` function to parse the response
      if (fromJson != null) {
        return fromJson(decodedResponse);
      }

      // If no `fromJson` is provided, return the raw response
      return decodedResponse as T;
    } on FormatException catch (e) {
      Loggers.error('Invalid multipart response format: ${e.message}');
      throw Exception('Invalid server response: ${e.message}');
    } finally {
      if (token != null && onCancel != null) {
        token.removeCancelListener(onCancel);
      }
      _cleanupClient(token, client);
    }
  }

  Map<String, dynamic>? _tryDecodeJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _cleanupClient(CancelToken? cancelToken, http.Client client) {
    if (cancelToken != null) {
      _activeClients.remove(cancelToken);
    }
    client.close();
  }

  Future<void> useAndDeleteFile(File file) async {
    try {
      // Use the file as needed
      Loggers.warning('File path: ${file.path}');

      // Delete the file after use
      if (await file.exists()) {
        await file.delete();
        Loggers.success('File deleted from: ${file.path}');
      }
    } catch (e) {
      Loggers.error('Error: $e');
    }
  }
}

class MultipartRequest extends http.MultipartRequest {
  MultipartRequest(
    super.method,
    super.url, {
    this.onProgress,
  });

  final void Function(int bytes, int totalBytes)? onProgress;

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    final total = contentLength;
    int bytes = 0;

    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        bytes += data.length;
        if (onProgress != null) {
          onProgress!(bytes, total);
        }
        sink.add(data);
      },
    );

    return http.ByteStream(byteStream.transform(transformer));
  }
}
