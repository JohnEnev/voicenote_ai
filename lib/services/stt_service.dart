import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'vosk_stt_service.dart';
import 'whisper_stt_service.dart';

/// Enum for STT provider types
enum STTProvider {
  vosk,    // On-device, private, offline
  whisper, // Cloud-based, high accuracy, requires internet
}

/// Unified STT service that manages multiple providers
/// Allows switching between on-device (Vosk) and cloud (Whisper) STT
class STTService {
  final VoskSTTService _voskService = VoskSTTService();
  final WhisperSTTService _whisperService = WhisperSTTService();

  STTProvider _currentProvider = STTProvider.vosk;
  bool _isInitialized = false;

  final StreamController<TranscriptionResult> _transcriptionController =
      StreamController<TranscriptionResult>.broadcast();

  /// Stream of transcription results from active provider
  Stream<TranscriptionResult> get transcriptionStream =>
      _transcriptionController.stream;

  /// Current STT provider
  STTProvider get currentProvider => _currentProvider;

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize STT service with specified provider
  Future<bool> initialize({STTProvider provider = STTProvider.vosk}) async {
    _currentProvider = provider;

    try {
      bool success = false;

      switch (provider) {
        case STTProvider.vosk:
          print('Initializing Vosk (on-device) STT...');
          success = await _voskService.initialize();
          if (success) {
            // Forward Vosk transcription stream
            _voskService.transcriptionStream.listen((result) {
              _transcriptionController.add(TranscriptionResult(
                text: result.text,
                isFinal: result.isFinal,
                confidence: result.confidence,
              ));
            });
          }
          break;

        case STTProvider.whisper:
          print('Initializing Whisper (cloud) STT...');
          final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
          if (apiKey.isEmpty) {
            print('ERROR: OPENAI_API_KEY not found in .env file');
            print('Please add your OpenAI API key to .env file');
            return false;
          }
          success = await _whisperService.initialize(apiKey);
          if (success) {
            // Forward Whisper transcription stream
            _whisperService.transcriptionStream.listen((result) {
              _transcriptionController.add(TranscriptionResult(
                text: result.text,
                isFinal: result.isFinal,
                confidence: result.confidence,
              ));
            });
          }
          break;
      }

      _isInitialized = success;
      if (success) {
        print('STT Service initialized with ${provider.name}');
      }
      return success;
    } catch (e) {
      print('Error initializing STT service: $e');
      return false;
    }
  }

  /// Switch to a different STT provider
  Future<bool> switchProvider(STTProvider newProvider) async {
    if (newProvider == _currentProvider) {
      return true; // Already using this provider
    }

    print('Switching STT provider from ${_currentProvider.name} to ${newProvider.name}');
    return await initialize(provider: newProvider);
  }

  /// Process WAV file and get transcription
  Future<String> processWavFile(String filePath) async {
    if (!_isInitialized) {
      print('STT Service not initialized');
      return '';
    }

    try {
      switch (_currentProvider) {
        case STTProvider.vosk:
          return await _voskService.processWavFile(filePath);

        case STTProvider.whisper:
          // Whisper can process WAV files directly
          return await _whisperService.transcribeFile(filePath);
      }
    } catch (e) {
      print('Error processing WAV file: $e');
      return '';
    }
  }

  /// Process M4A file (only for Whisper, Vosk needs WAV)
  Future<String> processM4aFile(String filePath) async {
    if (!_isInitialized) {
      print('STT Service not initialized');
      return '';
    }

    if (_currentProvider != STTProvider.whisper) {
      print('M4A processing only available with Whisper provider');
      return '';
    }

    try {
      return await _whisperService.transcribeFile(filePath);
    } catch (e) {
      print('Error processing M4A file: $e');
      return '';
    }
  }

  /// Reset the recognizer (mainly for Vosk)
  Future<void> reset() async {
    if (_currentProvider == STTProvider.vosk) {
      await _voskService.reset();
    }
  }

  /// Get provider display name
  String getProviderDisplayName(STTProvider provider) {
    switch (provider) {
      case STTProvider.vosk:
        return 'On-Device (Vosk)';
      case STTProvider.whisper:
        return 'Cloud (Whisper)';
    }
  }

  /// Get provider description
  String getProviderDescription(STTProvider provider) {
    switch (provider) {
      case STTProvider.vosk:
        return 'Private, offline, works anywhere. Lower accuracy.';
      case STTProvider.whisper:
        return 'High accuracy, handles noise well. Requires internet.';
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _transcriptionController.close();
    await _voskService.dispose();
    await _whisperService.dispose();
    _isInitialized = false;
  }
}

/// Result from speech recognition
class TranscriptionResult {
  final String text;
  final bool isFinal;
  final double confidence;

  TranscriptionResult({
    required this.text,
    required this.isFinal,
    required this.confidence,
  });

  @override
  String toString() {
    return 'TranscriptionResult(text: $text, isFinal: $isFinal, confidence: $confidence)';
  }
}
