import 'dart:async';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_session/audio_session.dart';

/// Service for managing audio recording with flutter_sound
/// Captures audio at 16kHz mono PCM for STT processing
class AudioRecorderService {
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
          usage: AndroidAudioUsage.voiceCommunication,
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
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/recording_$timestamp.wav';

      // Start recording with 16kHz mono PCM configuration
      await _recorder.startRecorder(
        toFile: filePath,
        codec: Codec.pcm16WAV,
        numChannels: 1, // Mono
        sampleRate: 16000, // 16kHz
        bitRate: 256000,
      );

      _isRecording = true;
      _currentRecordingPath = filePath;
      _recordingStartTime = DateTime.now();
      _stateController.add(RecordingState.recording);

      // Start duration updates
      _startDurationTimer();

      return filePath;
    } catch (e) {
      _stateController.add(RecordingState.error);
      return null;
    }
  }

  /// Stop recording audio
  /// Returns the file path of the recorded audio
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      await _recorder.stopRecorder();

      final path = _currentRecordingPath;
      _isRecording = false;
      _currentRecordingPath = null;
      _recordingStartTime = null;

      _stateController.add(RecordingState.stopped);

      return path;
    } catch (e) {
      _stateController.add(RecordingState.error);
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
