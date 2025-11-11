import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';

/// Cloud-based STT service using OpenAI Whisper API
/// Provides high-accuracy transcription with internet connection
class WhisperSTTService {
  final Dio _dio = Dio();
  bool _isInitialized = false;
  String? _apiKey;

  final StreamController<TranscriptionResult> _transcriptionController =
      StreamController<TranscriptionResult>.broadcast();

  /// Stream of transcription results
  Stream<TranscriptionResult> get transcriptionStream =>
      _transcriptionController.stream;

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize Whisper with API key
  Future<bool> initialize(String apiKey) async {
    if (_isInitialized) return true;

    if (apiKey.isEmpty) {
      print('Whisper API key is empty');
      return false;
    }

    try {
      _apiKey = apiKey;

      // Configure Dio for Whisper API
      _dio.options = BaseOptions(
        baseUrl: 'https://api.openai.com/v1',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );

      _isInitialized = true;
      print('Whisper STT initialized successfully');
      return true;
    } catch (e) {
      print('Error initializing Whisper: $e');
      return false;
    }
  }

  /// Transcribe audio file using Whisper API
  /// Supports various formats: m4a, mp3, mp4, mpeg, mpga, wav, webm
  Future<String> transcribeFile(String filePath, {String language = 'en'}) async {
    if (!_isInitialized || _apiKey == null) {
      print('Whisper not initialized');
      return '';
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('Audio file not found: $filePath');
        return '';
      }

      print('Transcribing with Whisper API...');
      final fileSize = await file.length();
      print('File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      // Create multipart form data
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
        'model': 'whisper-1',
        'language': language,
        'response_format': 'text', // Get plain text response
      });

      // Send request to Whisper API
      final response = await _dio.post(
        '/audio/transcriptions',
        data: formData,
      );

      if (response.statusCode == 200) {
        final transcription = response.data.toString().trim();
        print('Whisper transcription: $transcription');

        // Emit result to stream
        _transcriptionController.add(TranscriptionResult(
          text: transcription,
          isFinal: true,
          confidence: 0.95, // Whisper doesn't provide confidence, using high default
        ));

        return transcription;
      } else {
        print('Whisper API error: ${response.statusCode}');
        return '';
      }
    } on DioException catch (e) {
      if (e.response != null) {
        print('Whisper API error: ${e.response?.statusCode} - ${e.response?.data}');
      } else {
        print('Whisper network error: ${e.message}');
      }
      return '';
    } catch (e) {
      print('Error transcribing with Whisper: $e');
      return '';
    }
  }

  /// Transcribe audio file with detailed response including segments
  Future<Map<String, dynamic>?> transcribeFileDetailed(
    String filePath, {
    String language = 'en',
  }) async {
    if (!_isInitialized || _apiKey == null) {
      print('Whisper not initialized');
      return null;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('Audio file not found: $filePath');
        return null;
      }

      print('Transcribing with Whisper API (detailed)...');

      // Create multipart form data
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
        'model': 'whisper-1',
        'language': language,
        'response_format': 'verbose_json', // Get detailed JSON response
      });

      // Send request to Whisper API
      final response = await _dio.post(
        '/audio/transcriptions',
        data: formData,
      );

      if (response.statusCode == 200) {
        final result = response.data as Map<String, dynamic>;
        print('Whisper detailed transcription received');

        // Emit result to stream
        if (result['text'] != null) {
          _transcriptionController.add(TranscriptionResult(
            text: result['text'],
            isFinal: true,
            confidence: 0.95,
          ));
        }

        return result;
      } else {
        print('Whisper API error: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      if (e.response != null) {
        print('Whisper API error: ${e.response?.statusCode} - ${e.response?.data}');
      } else {
        print('Whisper network error: ${e.message}');
      }
      return null;
    } catch (e) {
      print('Error transcribing with Whisper: $e');
      return null;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _transcriptionController.close();
    _dio.close();
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
