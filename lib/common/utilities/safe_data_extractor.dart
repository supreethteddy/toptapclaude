import 'package:toptap/common/exceptions/camera_exceptions.dart' as exceptions;

/// Safe data extraction utilities to replace dangerous type casting
/// Provides type-safe extraction from dynamic data structures with validation

/// Safe data extractor for removing brittle type casting
class SafeDataExtractor {
  /// Safely extract a Map from dynamic data
  static Map<String, dynamic>? extractMap(dynamic data, [String? fieldName]) {
    if (data == null) return null;
    
    if (data is Map<String, dynamic>) {
      return data;
    }
    
    if (data is Map) {
      // Convert other Map types to Map<String, dynamic>
      return Map<String, dynamic>.from(data);
    }
    
    throw exceptions.DataExtractionException(
      'Expected Map<String, dynamic> but got ${data.runtimeType}',
      fieldName: fieldName ?? 'unknown',
      actualType: data.runtimeType.toString(),
      expectedType: 'Map<String, dynamic>',
    );
  }

  /// Safely extract a String from dynamic data
  static String? extractString(dynamic data, [String? fieldName]) {
    if (data == null) return null;
    
    if (data is String) return data;
    
    // Try converting other types to string
    if (data is num || data is bool) {
      return data.toString();
    }
    
    throw exceptions.DataExtractionException(
      'Expected String but got ${data.runtimeType}',
      fieldName: fieldName ?? 'unknown',
      actualType: data.runtimeType.toString(),
      expectedType: 'String',
    );
  }

  /// Safely extract an int from dynamic data
  static int? extractInt(dynamic data, [String? fieldName]) {
    if (data == null) return null;
    
    if (data is int) return data;
    
    if (data is num) return data.round();
    
    if (data is String) {
      final parsed = int.tryParse(data);
      if (parsed != null) return parsed;
    }
    
    throw exceptions.DataExtractionException(
      'Expected int but got ${data.runtimeType}',
      fieldName: fieldName ?? 'unknown',
      actualType: data.runtimeType.toString(),
      expectedType: 'int',
    );
  }

  /// Safely extract a double from dynamic data
  static double? extractDouble(dynamic data, [String? fieldName]) {
    if (data == null) return null;
    
    if (data is double) return data;
    
    if (data is num) return data.toDouble();
    
    if (data is String) {
      final parsed = double.tryParse(data);
      if (parsed != null) return parsed;
    }
    
    throw exceptions.DataExtractionException(
      'Expected double but got ${data.runtimeType}',
      fieldName: fieldName ?? 'unknown',
      actualType: data.runtimeType.toString(),
      expectedType: 'double',
    );
  }

  /// Safely extract a List from dynamic data
  static List<T>? extractList<T>(dynamic data, [String? fieldName]) {
    if (data == null) return null;
    
    if (data is List<T>) return data;
    
    if (data is List) {
      try {
        return data.cast<T>();
      } catch (e) {
        throw exceptions.DataExtractionException(
          'Failed to cast List to List<$T>',
          fieldName: fieldName ?? 'unknown',
          actualType: data.runtimeType.toString(),
          expectedType: 'List<$T>',
          details: 'Cast error: $e',
        );
      }
    }
    
    throw exceptions.DataExtractionException(
      'Expected List<$T> but got ${data.runtimeType}',
      fieldName: fieldName ?? 'unknown',
      actualType: data.runtimeType.toString(),
      expectedType: 'List<$T>',
    );
  }

  /// Safely extract nested map field with path notation
  static dynamic extractNestedField(Map<String, dynamic> data, String path) {
    final parts = path.split('.');
    dynamic current = data;
    
    for (final part in parts) {
      if (current is! Map<String, dynamic>) {
        throw exceptions.DataExtractionException(
          'Expected Map<String, dynamic> at path segment "$part"',
          fieldName: path,
          actualType: current.runtimeType.toString(),
          expectedType: 'Map<String, dynamic>',
        );
      }
      
      if (!current.containsKey(part)) {
        return null;
      }
      
      current = current[part];
    }
    
    return current;
  }

  /// Safely extract coordinate data from position maps
  static Map<String, double> extractPosition(dynamic positionData) {
    final positionMap = extractMap(positionData, 'position');
    
    if (positionMap == null) {
      return {'x': 0.0, 'y': 0.0};
    }
    
    final x = extractDouble(positionMap['x'], 'position.x') ?? 0.0;
    final y = extractDouble(positionMap['y'], 'position.y') ?? 0.0;
    
    return {'x': x, 'y': y};
  }

  /// Safely extract device capabilities data
  static Map<String, dynamic> extractDeviceCapabilities(dynamic data) {
    final capabilities = extractMap(data, 'deviceCapabilities');
    
    if (capabilities == null) {
      // Return default capabilities if none provided
      return {
        'processingDelays': {
          'preProcessing': 500,
          'postProcessing': 1000,
        },
        'maxConcurrentOperations': 1,
        'supportedFormats': ['mp4', 'jpg'],
      };
    }
    
    return capabilities;
  }

  /// Safely extract processing delays with defaults
  static Map<String, int> extractProcessingDelays(dynamic data) {
    final delays = extractMap(data, 'processingDelays');
    
    if (delays == null) {
      return {
        'preProcessing': 500,
        'postProcessing': 1000,
        'validation': 200,
      };
    }
    
    return {
      'preProcessing': extractInt(delays['preProcessing'], 'processingDelays.preProcessing') ?? 500,
      'postProcessing': extractInt(delays['postProcessing'], 'processingDelays.postProcessing') ?? 1000,
      'validation': extractInt(delays['validation'], 'processingDelays.validation') ?? 200,
    };
  }
}