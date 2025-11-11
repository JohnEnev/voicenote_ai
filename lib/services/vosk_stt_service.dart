import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

/// Service for speech-to-text using Vosk (on-device)
class VoskSTTService {
  VoskFlutterPlugin? _vosk;
  ModelLoader? _modelLoader;
  Model? _model;
  Recognizer? _recognizer;
  bool _isInitialized = false;

  final StreamController<TranscriptionResult> _transcriptionController =
      StreamController<TranscriptionResult>.broadcast();

  /// Stream of transcription results (partial and final)
  Stream<TranscriptionResult> get transcriptionStream =>
      _transcriptionController.stream;

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize Vosk with the model
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _vosk = VoskFlutterPlugin.instance();
      _modelLoader = ModelLoader();

      // Load the model from network (downloads on first run, then cached)
      final modelPath = await _loadModelFromNetwork();

      if (modelPath == null) {
        print('Failed to copy Vosk model from assets');
        return false;
      }

      print('Creating model from path: $modelPath');
      _model = await _vosk!.createModel(modelPath);

      // Create recognizer with 16kHz sample rate (matching our recorder)
      _recognizer = await _vosk!.createRecognizer(
        model: _model!,
        sampleRate: 16000,
      );

      _isInitialized = true;
      print('Vosk STT initialized successfully');
      return true;
    } catch (e) {
      print('Error initializing Vosk: $e');
      return false;
    }
  }

  /// Load model from network (downloads on first run, cached afterwards)
  Future<String?> _loadModelFromNetwork() async {
    try {
      final modelLoader = ModelLoader();

      print('Loading Vosk model...');

      // First, try to get the model list
      final modelsList = await modelLoader.loadModelsList();
      print('Available models: ${modelsList.length}');

      // Use the small English model (40MB - optimized for mobile devices)
      // The medium model (128MB) causes out-of-memory errors on mobile
      final modelDescription = modelsList.firstWhere(
        (model) => model.name == 'vosk-model-small-en-us-0.15',
        orElse: () => throw Exception('Model not found in list'),
      );

      print('Found model: ${modelDescription.name}');
      print('Downloading from: ${modelDescription.url}');
      print('This may take a minute on first run...');
      print('Download progress will be shown below:');

      // Download/load the model with progress tracking
      final startTime = DateTime.now();
      int lastProgress = 0;

      // Note: vosk_flutter's ModelLoader doesn't expose progress callbacks
      // So we'll just show a spinner-style progress indicator
      final progressTimer = Timer.periodic(Duration(seconds: 2), (timer) {
        final elapsed = DateTime.now().difference(startTime).inSeconds;
        final dots = '.' * ((elapsed ~/ 2) % 4 + 1);
        print('Downloading$dots (${elapsed}s elapsed)');
      });

      try {
        final modelPath = await modelLoader.loadFromNetwork(modelDescription.url);
        progressTimer.cancel();

        final totalTime = DateTime.now().difference(startTime).inSeconds;
        print('✓ Download complete! Took ${totalTime}s');
        print('Model cached to: $modelPath');

        return modelPath;
      } finally {
        progressTimer.cancel();
      }
    } catch (e) {
      print('Error loading model from network: $e');
      return null;
    }
  }

  /// Process audio data and get transcription
  /// [audioData] should be Int16 PCM audio at 16kHz
  Future<void> processAudio(Uint8List audioData) async {
    if (!_isInitialized || _recognizer == null) {
      print('Vosk not initialized');
      return;
    }

    try {
      // Feed audio to recognizer
      final resultReady = await _recognizer!.acceptWaveformBytes(audioData);

      if (resultReady) {
        // Get final result
        final result = await _recognizer!.getResult();
        if (result.isNotEmpty) {
          _transcriptionController.add(TranscriptionResult(
            text: _parseVoskResult(result),
            isFinal: true,
            confidence: 1.0,
          ));
        }
      } else {
        // Get partial result
        final partialResult = await _recognizer!.getPartialResult();
        if (partialResult.isNotEmpty) {
          _transcriptionController.add(TranscriptionResult(
            text: _parseVoskPartialResult(partialResult),
            isFinal: false,
            confidence: 0.8,
          ));
        }
      }
    } catch (e) {
      print('Error processing audio: $e');
    }
  }

  /// Process test audio file from assets (for testing without recording)
  Future<String> processTestAudio() async {
    if (!_isInitialized || _recognizer == null) {
      print('Vosk not initialized');
      return '';
    }

    try {
      print('Loading test audio from assets...');

      // Load test audio from assets
      final ByteData data = await rootBundle.load('assets/test_audio/test_speech.wav');
      final bytes = data.buffer.asUint8List();

      print('Test audio loaded: ${bytes.length} bytes');

      // Reset recognizer
      await reset();

      // Skip WAV header (44 bytes) and get PCM data
      if (bytes.length <= 44) {
        print('Test audio file too small');
        return '';
      }

      final pcmData = bytes.sublist(44);
      print('Processing ${pcmData.length} bytes of PCM data...');

      // Process in chunks
      const chunkSize = 8000;
      for (var i = 0; i < pcmData.length; i += chunkSize) {
        final end = (i + chunkSize < pcmData.length) ? i + chunkSize : pcmData.length;
        final chunk = Uint8List.sublistView(pcmData, i, end);
        await _recognizer!.acceptWaveformBytes(chunk);
      }

      // Get final result
      final result = await _recognizer!.getFinalResult();
      print('Vosk result: $result');

      if (result.isNotEmpty) {
        final text = _parseVoskResult(result);
        _transcriptionController.add(TranscriptionResult(
          text: text,
          isFinal: true,
          confidence: 1.0,
        ));
        return text;
      }

      return '(no speech detected in test audio)';
    } catch (e) {
      print('Error processing test audio: $e');
      return '';
    }
  }

  /// Process a complete WAV file and get transcription
  /// This is useful for processing a recorded file after recording stops
  Future<String> processWavFile(String filePath) async {
    if (!_isInitialized || _recognizer == null) {
      print('Vosk not initialized');
      return '';
    }

    try {
      // Reset recognizer before processing new file
      await reset();

      // Read WAV file and process it
      final file = File(filePath);
      if (!await file.exists()) {
        print('WAV file not found: $filePath');
        return '';
      }

      // Read file as bytes
      final bytes = await file.readAsBytes();
      print('WAV file size: ${bytes.length} bytes');

      // WAV file has a 44-byte header, skip it to get raw PCM data
      if (bytes.length <= 44) {
        print('WAV file too small (${bytes.length} bytes, need > 44)');
        return '';
      }

      final pcmData = bytes.sublist(44);
      print('PCM data size: ${pcmData.length} bytes (${(pcmData.length / 32000).toStringAsFixed(2)}s of audio)');

      // Process the PCM data in chunks
      const chunkSize = 8000; // Process in 0.5s chunks (16kHz * 2 bytes * 0.5s / 2)
      for (var i = 0; i < pcmData.length; i += chunkSize) {
        final end = (i + chunkSize < pcmData.length) ? i + chunkSize : pcmData.length;
        final chunk = Uint8List.sublistView(pcmData, i, end);
        await _recognizer!.acceptWaveformBytes(chunk);
      }

      // Get final result
      final result = await _recognizer!.getFinalResult();
      if (result.isNotEmpty) {
        final text = _parseVoskResult(result);
        // Emit final result to stream
        _transcriptionController.add(TranscriptionResult(
          text: text,
          isFinal: true,
          confidence: 1.0,
        ));
        return text;
      }
    } catch (e) {
      print('Error processing WAV file: $e');
    }
    return '';
  }

  /// Get final result (call after recording is complete)
  Future<String> getFinalResult() async {
    if (!_isInitialized || _recognizer == null) {
      return '';
    }

    try {
      final result = await _recognizer!.getFinalResult();
      if (result.isNotEmpty) {
        return _parseVoskResult(result);
      }
    } catch (e) {
      print('Error getting final result: $e');
    }
    return '';
  }

  /// Parse Vosk JSON result to extract text
  String _parseVoskResult(String jsonResult) {
    try {
      // Vosk returns: {"text" : "hello world"}
      final match = RegExp(r'"text"\s*:\s*"([^"]*)"').firstMatch(jsonResult);
      return match?.group(1) ?? '';
    } catch (e) {
      return jsonResult;
    }
  }

  /// Parse Vosk partial JSON result
  String _parseVoskPartialResult(String jsonResult) {
    try {
      // Vosk returns: {"partial" : "hello"}
      final match = RegExp(r'"partial"\s*:\s*"([^"]*)"').firstMatch(jsonResult);
      return match?.group(1) ?? '';
    } catch (e) {
      return jsonResult;
    }
  }

  /// Reset the recognizer (call between recordings)
  Future<void> reset() async {
    if (!_isInitialized || _recognizer == null) return;

    try {
      await _recognizer!.reset();
    } catch (e) {
      print('Error resetting recognizer: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _transcriptionController.close();

    if (_recognizer != null) {
      try {
        await _recognizer!.dispose();
      } catch (e) {
        print('Error disposing recognizer: $e');
      }
    }

    // Note: Model disposal is handled by the recognizer

    _isInitialized = false;
  }
}

/// Result from speech recognition
class TranscriptionResult {
  final String text;
  final bool isFinal; // false = partial hypothesis, true = final result
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
