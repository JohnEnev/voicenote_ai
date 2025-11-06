import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/audio_recorder_service.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final AudioRecorderService _recorderService = AudioRecorderService();
  RecordingState _recordingState = RecordingState.uninitialized;
  Duration _recordingDuration = Duration.zero;
  String? _lastRecordingPath;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    // Listen to state changes
    _recorderService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _recordingState = state;
        });

        // Show error or permission denied messages
        if (state == RecordingState.permissionDenied) {
          _showMessage('Microphone permission denied');
        } else if (state == RecordingState.error) {
          _showMessage('Recording error occurred');
        }
      }
    });

    // Listen to duration updates
    _recorderService.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _recordingDuration = duration;
        });
      }
    });

    // Initialize
    await _recorderService.initialize();
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _toggleRecording() async {
    if (_recordingState == RecordingState.recording) {
      // Stop recording
      final path = await _recorderService.stopRecording();
      if (path != null) {
        setState(() {
          _lastRecordingPath = path;
        });
        _showMessage('Recording saved to $path');
      }
    } else {
      // Start recording
      final path = await _recorderService.startRecording();
      if (path != null) {
        _showMessage('Recording started');
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Color _getMicIconColor() {
    switch (_recordingState) {
      case RecordingState.recording:
        return Colors.red;
      case RecordingState.paused:
        return Colors.orange;
      case RecordingState.ready:
      case RecordingState.stopped:
        return Colors.blue;
      case RecordingState.permissionDenied:
      case RecordingState.error:
        return Colors.grey;
      case RecordingState.uninitialized:
        return Colors.grey;
    }
  }

  IconData _getButtonIcon() {
    switch (_recordingState) {
      case RecordingState.recording:
        return Icons.stop;
      case RecordingState.paused:
        return Icons.play_arrow;
      default:
        return Icons.mic;
    }
  }

  String _getButtonText() {
    switch (_recordingState) {
      case RecordingState.recording:
        return 'Stop Recording';
      case RecordingState.paused:
        return 'Resume Recording';
      case RecordingState.ready:
      case RecordingState.stopped:
        return 'Start Recording';
      case RecordingState.permissionDenied:
        return 'Permission Denied';
      case RecordingState.error:
        return 'Error';
      case RecordingState.uninitialized:
        return 'Initializing...';
    }
  }

  bool _isButtonEnabled() {
    return _recordingState == RecordingState.ready ||
        _recordingState == RecordingState.stopped ||
        _recordingState == RecordingState.recording ||
        _recordingState == RecordingState.paused;
  }

  @override
  void dispose() {
    _recorderService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => context.go('/notes'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Microphone icon with pulsing animation when recording
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _recordingState == RecordingState.recording
                    ? Colors.red.withAlpha(50)
                    : Colors.transparent,
              ),
              padding: const EdgeInsets.all(32),
              child: Icon(
                Icons.mic,
                size: 100,
                color: _getMicIconColor(),
              ),
            ),
            const SizedBox(height: 24),

            // Recording duration
            if (_recordingState == RecordingState.recording ||
                _recordingState == RecordingState.paused)
              Text(
                _formatDuration(_recordingDuration),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),

            const SizedBox(height: 16),

            // Status text
            Text(
              _recordingState == RecordingState.recording
                  ? 'Recording...'
                  : _recordingState == RecordingState.paused
                      ? 'Paused'
                      : _recordingState == RecordingState.stopped &&
                              _lastRecordingPath != null
                          ? 'Recording saved'
                          : 'Tap to record',
              style: const TextStyle(fontSize: 20),
            ),

            const SizedBox(height: 48),

            // Record/Stop button
            ElevatedButton.icon(
              onPressed: _isButtonEnabled() ? _toggleRecording : null,
              icon: Icon(_getButtonIcon()),
              label: Text(_getButtonText()),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: _recordingState == RecordingState.recording
                    ? Colors.red
                    : null,
              ),
            ),

            // Last recording info
            if (_lastRecordingPath != null) ...[
              const SizedBox(height: 32),
              const Text(
                'Last recording:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                _lastRecordingPath!.split('/').last,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
