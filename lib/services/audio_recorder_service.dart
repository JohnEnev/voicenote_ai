import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_session/audio_session.dart';

/// Service for managing audio recording with flutter_sound
/// Captures audio at 16kHz mono PCM for STT processing
class AudioRecorderService {
  static const platform = MethodChannel('com.notetaking.note_taking_ai/audio');

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isInitialized = false;
  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  final StreamController<RecordingState> _stateController =
      StreamController<RecordingState>.broadcast();

  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();

  /// Stream of recording state changes
  Stream<RecordingState> get stateStream => _stateController.stream;

  /// Stream of recording duration updates
  Stream<Duration> get durationStream => _durationController.stream;

  /// Whether the recorder is currently recording
  bool get isRecording => _isRecording;

  /// Current recording file path (if recording)
  String? get currentRecordingPath => _currentRecordingPath;

  /// Initialize the audio recorder and request permissions
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _stateController.add(RecordingState.permissionDenied);
        return false;
      }

      // Open the audio session
      await _recorder.openRecorder();

      // Configure audio session for recording
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media, // Changed from voiceCommunication to media
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      _isInitialized = true;
      _stateController.add(RecordingState.ready);
      return true;
    } catch (e) {
      _stateController.add(RecordingState.error);
      return false;
    }
  }

  /// Start recording audio
  /// Returns the file path where audio is being saved
  Future<String?> startRecording() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return null;
    }

    if (_isRecording) {
      return _currentRecordingPath;
    }

    try {
      // Create file path for recording
      // Use AAC since it's the only codec that captures audio on this device
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/recording_$timestamp.m4a';

      // Record in AAC/MP4 format (most reliable on Android)
      print('Starting recording to: $filePath');
      await _recorder.startRecorder(
        toFile: filePath,
        codec: Codec.aacMP4,
        sampleRate: 16000,
        numChannels: 1,
      );

      _isRecording = true;
      _currentRecordingPath = filePath;
      _recordingStartTime = DateTime.now();
      _stateController.add(RecordingState.recording);
      print('Recording started successfully');

      // Start duration updates
      _startDurationTimer();

      return filePath;
    } catch (e) {
      _stateController.add(RecordingState.error);
      return null;
    }
  }

  /// Stop recording audio
  /// Returns the file path of the recorded audio (converted to WAV)
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      print('Stop called but not recording');
      return null;
    }

    try {
      print('Stopping recorder...');
      await _recorder.stopRecorder();

      final m4aPath = _currentRecordingPath;
      _isRecording = false;
      _currentRecordingPath = null;
      _recordingStartTime = null;

      _stateController.add(RecordingState.stopped);

      print('Recording stopped, M4A file saved at: $m4aPath');
      if (m4aPath != null) {
        final m4aFile = File(m4aPath);
        if (await m4aFile.exists()) {
          final size = await m4aFile.length();
          print('M4A file size: $size bytes');

          // Use platform channel to decode M4A to WAV on Android
          final wavPath = await _decodeToWav(m4aPath);
          if (wavPath != null) {
            print('Decoded to WAV: $wavPath');
            return wavPath;
          } else {
            print('WARNING: Failed to decode M4A to WAV');
            return null;
          }
        } else {
          print('WARNING: M4A file does not exist at path!');
          return null;
        }
      }

      return null;
    } catch (e) {
      print('Error in stopRecording: $e');
      _stateController.add(RecordingState.error);
      return null;
    }
  }

  /// Decode M4A/AAC to WAV using platform channel (Android MediaCodec)
  Future<String?> _decodeToWav(String m4aPath) async {
    try {
      print('Calling Android MediaCodec to decode M4A to WAV');

      final result = await platform.invokeMethod('decodeToWav', {
        'inputPath': m4aPath,
        'sampleRate': 16000,
        'channels': 1,
      });

      if (result != null && result is String) {
        print('Android decoder returned WAV path: $result');

        // Verify file exists
        final wavFile = File(result);
        if (await wavFile.exists()) {
          final size = await wavFile.length();
          print('WAV file size: $size bytes');

          // Delete M4A file to save space
          await File(m4aPath).delete();
          print('Deleted M4A file');

          return result;
        } else {
          print('WAV file does not exist at returned path');
          return null;
        }
      } else {
        print('Android decoder returned null or invalid result');
        return null;
      }
    } catch (e) {
      print('Error calling platform channel for decoding: $e');
      return null;
    }
  }

  /// Pause recording (if supported)
  Future<void> pauseRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder.pauseRecorder();
      _stateController.add(RecordingState.paused);
    } catch (e) {
      _stateController.add(RecordingState.error);
    }
  }

  /// Resume recording (if paused)
  Future<void> resumeRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder.resumeRecorder();
      _stateController.add(RecordingState.recording);
    } catch (e) {
      _stateController.add(RecordingState.error);
    }
  }

  /// Get current recording duration
  Duration? getRecordingDuration() {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Start timer for duration updates
  void _startDurationTimer() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      final duration = getRecordingDuration();
      if (duration != null) {
        _durationController.add(duration);
      }
    });
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _recorder.closeRecorder();
    await _stateController.close();
    await _durationController.close();
    _isInitialized = false;
  }
}

/// Enum representing the state of the audio recorder
enum RecordingState {
  uninitialized,
  ready,
  recording,
  paused,
  stopped,
  permissionDenied,
  error,
}
