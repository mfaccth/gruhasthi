import 'package:flutter/services.dart';

class GemmaModelStatus {
  const GemmaModelStatus({
    required this.isReady,
    required this.modelPath,
    required this.modelFileName,
    required this.sizeBytes,
  });

  final bool isReady;
  final String modelPath;
  final String modelFileName;
  final int sizeBytes;

  factory GemmaModelStatus.fromMap(Map<Object?, Object?> values) {
    return GemmaModelStatus(
      isReady: values['ready'] == true,
      modelPath: values['modelPath'] as String? ?? '',
      modelFileName: values['modelFileName'] as String? ?? '',
      sizeBytes: (values['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  static const unavailable = GemmaModelStatus(
    isReady: false,
    modelPath: '',
    modelFileName: 'gemma-4-E2B-it.litertlm',
    sizeBytes: 0,
  );
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
  Future<GemmaModelStatus> pickAndInstallModel() async {
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'pickAndInstallModel',
    );
    if (response == null) {
      throw PlatformException(
        code: 'EMPTY_RESPONSE',
        message: 'Gruhasthi could not install the selected Gemma model.',
      );
    }
    return GemmaModelStatus.fromMap(response);
  }

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
