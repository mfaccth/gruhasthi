import 'package:flutter/services.dart';

enum GemmaModel {
  e2b(
    id: 'e2b',
    displayName: 'Gemma 4 E2B',
    fileName: 'gemma-4-E2B-it.litertlm',
    downloadSize: '2.59 GB download',
    storageGuidance: 'Keep about 6 GB of free storage while installing.',
    memoryGuidance: 'Recommended: phone with 6 GB RAM or more.',
    description: 'Recommended — smaller and faster for most phones.',
    modelPage:
        'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm',
  ),
  e4b(
    id: 'e4b',
    displayName: 'Gemma 4 E4B',
    fileName: 'gemma-4-E4B-it.litertlm',
    downloadSize: '3.66 GB download (3.41 GiB)',
    storageGuidance:
        'Keep about 10 GB of free storage while replacing a model.',
    memoryGuidance:
        'Recommended: phone with 8 GB RAM or more; 12 GB is best for smoother use.',
    description:
        'Higher capability (pilot) — needs a capable phone and more memory.',
    modelPage:
        'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm',
  );

  const GemmaModel({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.downloadSize,
    required this.storageGuidance,
    required this.memoryGuidance,
    required this.description,
    required this.modelPage,
  });

  final String id;
  final String displayName;
  final String fileName;
  final String downloadSize;
  final String storageGuidance;
  final String memoryGuidance;
  final String description;
  final String modelPage;

  static GemmaModel fromId(String id) => GemmaModel.values.firstWhere(
    (model) => model.id == id,
    orElse: () => e2b,
  );
}

class GemmaModelStatus {
  const GemmaModelStatus({
    required this.isReady,
    required this.modelPath,
    required this.model,
    required this.modelFileName,
    required this.sizeBytes,
  });

  final bool isReady;
  final String modelPath;
  final GemmaModel model;
  final String modelFileName;
  final int sizeBytes;

  factory GemmaModelStatus.fromMap(Map<Object?, Object?> values) {
    return GemmaModelStatus(
      isReady: values['ready'] == true,
      modelPath: values['modelPath'] as String? ?? '',
      model: GemmaModel.fromId(values['modelId'] as String? ?? 'e2b'),
      modelFileName: values['modelFileName'] as String? ?? '',
      sizeBytes: (values['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  static const unavailable = GemmaModelStatus(
    isReady: false,
    modelPath: '',
    model: GemmaModel.e2b,
    modelFileName: 'gemma-4-E2B-it.litertlm',
    sizeBytes: 0,
  );
}

class GemmaDownloadStatus {
  const GemmaDownloadStatus({
    required this.state,
    required this.modelId,
    required this.bytesDownloaded,
    required this.totalBytes,
    this.message = '',
  });

  final String state;
  final String modelId;
  final int bytesDownloaded;
  final int totalBytes;
  final String message;

  bool get isActive => state == 'pending' || state == 'downloading';
  bool get isDownloaded => state == 'downloaded';
  bool get hasFailed => state == 'failed';
  double? get progress => totalBytes > 0 ? bytesDownloaded / totalBytes : null;

  factory GemmaDownloadStatus.fromMap(Map<Object?, Object?> values) {
    return GemmaDownloadStatus(
      state: values['state'] as String? ?? 'none',
      modelId: values['modelId'] as String? ?? '',
      bytesDownloaded: (values['bytesDownloaded'] as num?)?.toInt() ?? 0,
      totalBytes: (values['totalBytes'] as num?)?.toInt() ?? 0,
      message: values['message'] as String? ?? '',
    );
  }
}

/// Flutter bridge to the optional on-device Gemma proof of concept.
///
/// The bridge is deliberately unavailable on non-Android targets. Voice
/// commands continue to use the local rule-based interpreter in that case.
class GemmaCommandInterpreter {
  const GemmaCommandInterpreter();

  static const _channel = MethodChannel('com.gruhasthi.gruhasthi/gemma');

  Future<GemmaModelStatus> status() async {
    try {
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'status',
      );
      return response == null
          ? GemmaModelStatus.unavailable
          : GemmaModelStatus.fromMap(response);
    } on MissingPluginException {
      return GemmaModelStatus.unavailable;
    } on PlatformException {
      return GemmaModelStatus.unavailable;
    }
  }

  /// Opens Android's document picker and imports the approved model file into
  /// Gruhasthi's private model storage.
  Future<GemmaModelStatus> pickAndInstallModel(GemmaModel model) async {
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'pickAndInstallModel',
      {'modelId': model.id},
    );
    if (response == null) {
      throw PlatformException(
        code: 'EMPTY_RESPONSE',
        message: 'Gruhasthi could not install the selected Gemma model.',
      );
    }
    return GemmaModelStatus.fromMap(response);
  }

  Future<GemmaDownloadStatus> startModelDownload(GemmaModel model) async {
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'startModelDownload',
      {'modelId': model.id},
    );
    if (response == null) {
      throw PlatformException(
        code: 'EMPTY_RESPONSE',
        message: 'Gruhasthi could not start the Gemma download.',
      );
    }
    return GemmaDownloadStatus.fromMap(response);
  }

  Future<GemmaDownloadStatus> modelDownloadStatus() async {
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'modelDownloadStatus',
    );
    return response == null
        ? const GemmaDownloadStatus(
            state: 'none',
            modelId: '',
            bytesDownloaded: 0,
            totalBytes: 0,
          )
        : GemmaDownloadStatus.fromMap(response);
  }

  Future<GemmaModelStatus> installDownloadedModel(GemmaModel model) async {
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'installDownloadedModel',
      {'modelId': model.id},
    );
    if (response == null) {
      throw PlatformException(
        code: 'EMPTY_RESPONSE',
        message: 'Gruhasthi could not install the downloaded Gemma model.',
      );
    }
    return GemmaModelStatus.fromMap(response);
  }

  Future<void> cancelModelDownload() =>
      _channel.invokeMethod<void>('cancelModelDownload');

  Future<Map<Object?, Object?>> interpret({
    required String transcript,
    required List<String> storeNames,
  }) async {
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'interpretTranscript',
      {'transcript': transcript, 'stores': storeNames},
    );
    if (response == null) {
      throw PlatformException(
        code: 'EMPTY_RESPONSE',
        message: 'Gemma did not return an interpretation.',
      );
    }
    return response;
  }
}
