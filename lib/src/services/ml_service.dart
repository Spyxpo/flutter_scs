import 'dart:io';
import 'dart:typed_data';

import '../utils/http_client.dart';

/// Service for machine learning operations.
///
/// Provides methods for text recognition, image labeling, and custom models.
class MlService {
  final ScsHttpClient _client;

  MlService(this._client);

  /// Performs text recognition (OCR) on an image file.
  Future<TextRecognitionResult> recognizeTextFromFile(File image) async {
    final response = await _client.uploadFile(
      'ml/text-recognition',
      file: image,
      fieldName: 'image',
    );
    return TextRecognitionResult.fromJson(response);
  }

  /// Performs text recognition (OCR) on image bytes.
  Future<TextRecognitionResult> recognizeText(
    Uint8List imageBytes, {
    required String filename,
  }) async {
    final response = await _client.uploadBytes(
      'ml/text-recognition',
      bytes: imageBytes,
      filename: filename,
      fieldName: 'image',
    );
    return TextRecognitionResult.fromJson(response);
  }

  /// Performs image labeling on a file.
  Future<ImageLabelingResult> labelImageFromFile(File image) async {
    final response = await _client.uploadFile(
      'ml/image-labeling',
      file: image,
      fieldName: 'image',
    );
    return ImageLabelingResult.fromJson(response);
  }

  /// Performs image labeling on image bytes.
  Future<ImageLabelingResult> labelImage(
    Uint8List imageBytes, {
    required String filename,
  }) async {
    final response = await _client.uploadBytes(
      'ml/image-labeling',
      bytes: imageBytes,
      filename: filename,
      fieldName: 'image',
    );
    return ImageLabelingResult.fromJson(response);
  }

  /// Lists all custom models.
  Future<List<CustomModel>> listModels() async {
    final response = await _client.get('ml/models');
    final models = response['models'] as List<dynamic>? ?? [];
    return models
        .map((m) => CustomModel.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// Gets a specific model.
  Future<CustomModel> getModel(String modelId) async {
    final response = await _client.get('ml/models/$modelId');
    return CustomModel.fromJson(
        response['model'] as Map<String, dynamic>? ?? response);
  }

  /// Deletes a model.
  Future<void> deleteModel(String modelId) async {
    await _client.delete('ml/models/$modelId');
  }

  /// Runs prediction with a custom model.
  Future<PredictionResult> predict(
    String modelId,
    File image,
  ) async {
    final response = await _client.uploadFile(
      'ml/models/$modelId/predict',
      file: image,
      fieldName: 'image',
    );
    return PredictionResult.fromJson(response);
  }

  /// Runs prediction with a custom model using image bytes.
  Future<PredictionResult> predictFromBytes(
    String modelId,
    Uint8List imageBytes, {
    required String filename,
  }) async {
    final response = await _client.uploadBytes(
      'ml/models/$modelId/predict',
      bytes: imageBytes,
      filename: filename,
      fieldName: 'image',
    );
    return PredictionResult.fromJson(response);
  }

  /// Gets ML service statistics.
  Future<Map<String, dynamic>> getStats() async {
    final response = await _client.get('ml/stats');
    return response['stats'] as Map<String, dynamic>? ?? response;
  }
}

/// Result of text recognition.
class TextRecognitionResult {
  final String text;
  final List<TextBlock> blocks;
  final double? confidence;

  const TextRecognitionResult({
    required this.text,
    this.blocks = const [],
    this.confidence,
  });

  factory TextRecognitionResult.fromJson(Map<String, dynamic> json) {
    final blocks = (json['blocks'] as List<dynamic>? ?? [])
        .map((b) => TextBlock.fromJson(b as Map<String, dynamic>))
        .toList();

    return TextRecognitionResult(
      text: json['text'] as String? ?? blocks.map((b) => b.text).join('\n'),
      blocks: blocks,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}

/// A block of recognized text.
class TextBlock {
  final String text;
  final BoundingBox? boundingBox;
  final double? confidence;
  final List<TextLine> lines;

  const TextBlock({
    required this.text,
    this.boundingBox,
    this.confidence,
    this.lines = const [],
  });

  factory TextBlock.fromJson(Map<String, dynamic> json) {
    return TextBlock(
      text: json['text'] as String? ?? '',
      boundingBox: json['boundingBox'] != null
          ? BoundingBox.fromJson(json['boundingBox'] as Map<String, dynamic>)
          : null,
      confidence: (json['confidence'] as num?)?.toDouble(),
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map((l) => TextLine.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A line of recognized text.
class TextLine {
  final String text;
  final BoundingBox? boundingBox;
  final double? confidence;

  const TextLine({
    required this.text,
    this.boundingBox,
    this.confidence,
  });

  factory TextLine.fromJson(Map<String, dynamic> json) {
    return TextLine(
      text: json['text'] as String? ?? '',
      boundingBox: json['boundingBox'] != null
          ? BoundingBox.fromJson(json['boundingBox'] as Map<String, dynamic>)
          : null,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}

/// A bounding box for detected elements.
class BoundingBox {
  final double left;
  final double top;
  final double width;
  final double height;

  const BoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      left: (json['left'] as num? ?? json['x'] as num? ?? 0).toDouble(),
      top: (json['top'] as num? ?? json['y'] as num? ?? 0).toDouble(),
      width: (json['width'] as num? ?? 0).toDouble(),
      height: (json['height'] as num? ?? 0).toDouble(),
    );
  }
}

/// Result of image labeling.
class ImageLabelingResult {
  final List<ImageLabel> labels;

  const ImageLabelingResult({required this.labels});

  factory ImageLabelingResult.fromJson(Map<String, dynamic> json) {
    final labels = (json['labels'] as List<dynamic>? ?? [])
        .map((l) => ImageLabel.fromJson(l as Map<String, dynamic>))
        .toList();
    return ImageLabelingResult(labels: labels);
  }
}

/// An image label.
class ImageLabel {
  final String label;
  final double confidence;
  final String? category;

  const ImageLabel({
    required this.label,
    required this.confidence,
    this.category,
  });

  factory ImageLabel.fromJson(Map<String, dynamic> json) {
    return ImageLabel(
      label: json['label'] as String? ?? json['name'] as String? ?? '',
      confidence: (json['confidence'] as num? ?? json['score'] as num? ?? 0).toDouble(),
      category: json['category'] as String?,
    );
  }
}

/// A custom ML model.
class CustomModel {
  final String id;
  final String name;
  final String? description;
  final String? type;
  final DateTime? createdAt;

  const CustomModel({
    required this.id,
    required this.name,
    this.description,
    this.type,
    this.createdAt,
  });

  factory CustomModel.fromJson(Map<String, dynamic> json) {
    return CustomModel(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      type: json['type'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

/// Result of a custom model prediction.
class PredictionResult {
  final List<Prediction> predictions;
  final int? executionTime;

  const PredictionResult({
    required this.predictions,
    this.executionTime,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final predictions = (json['predictions'] as List<dynamic>? ?? [])
        .map((p) => Prediction.fromJson(p as Map<String, dynamic>))
        .toList();
    return PredictionResult(
      predictions: predictions,
      executionTime: json['executionTime'] as int?,
    );
  }
}

/// A single prediction from a custom model.
class Prediction {
  final String label;
  final double confidence;
  final Map<String, dynamic>? metadata;

  const Prediction({
    required this.label,
    required this.confidence,
    this.metadata,
  });

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      label: json['label'] as String? ?? json['class'] as String? ?? '',
      confidence: (json['confidence'] as num? ?? json['score'] as num? ?? 0).toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
