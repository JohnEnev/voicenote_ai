import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../services/audio_recorder_service.dart';
import '../../services/stt_service.dart';
import '../../data/database/database.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final AudioRecorderService _recorderService = AudioRecorderService();
  final STTService _sttService = STTService();
  late final AppDatabase _database;
  RecordingState _recordingState = RecordingState.uninitialized;
  Duration _recordingDuration = Duration.zero;
  String? _lastRecordingPath;
  String _transcription = '';
  String _partialTranscription = '';
  STTProvider _currentSTTProvider = STTProvider.vosk;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
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

    // Listen to STT transcription results (only for Vosk partial results)
    // Whisper doesn't use this stream - it returns directly from processWavFile
    _sttService.transcriptionStream.listen((result) {
      if (mounted && _currentSTTProvider == STTProvider.vosk) {
        setState(() {
          if (result.isFinal) {
            // Replace with final result (don't append)
            _transcription = result.text;
            _partialTranscription = '';
          } else {
            // Show partial result (only for Vosk)
            _partialTranscription = result.text;
          }
        });
      }
    });

    // Initialize services
    await _recorderService.initialize();

    // Initialize STT service with default provider (Vosk)
    final sttInitialized = await _sttService.initialize(provider: _currentSTTProvider);
    if (!sttInitialized) {
      _showMessage('Failed to initialize speech recognition');
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _switchSTTProvider() async {
    // Toggle between providers
    final newProvider = _currentSTTProvider == STTProvider.vosk
        ? STTProvider.whisper
        : STTProvider.vosk;

    // Update UI immediately for better UX
    setState(() {
      _currentSTTProvider = newProvider;
    });

    // Switch provider in background
    final success = await _sttService.switchProvider(newProvider);
    if (!success) {
      // Revert on failure
      setState(() {
        _currentSTTProvider = _currentSTTProvider == STTProvider.vosk
            ? STTProvider.whisper
            : STTProvider.vosk;
      });
      _showMessage('Failed to switch provider');
    }
  }

  Future<void> _saveNoteToDatabase(String transcription, String? audioPath) async {
    try {
      // Create note with transcription
      final note = NotesCompanion.insert(
        content: transcription,  // Changed from 'text' to 'content'
        lang: const drift.Value('auto'),
        source: const drift.Value('voice'),
        durationMs: drift.Value(_recordingDuration.inMilliseconds),
        deviceHint: drift.Value(_currentSTTProvider.name), // Store STT provider used
      );

      // Insert note and get the ID
      await _database.notesDao.insertNote(note);
      print('Note saved');

      // If there's an audio file, save it as an attachment
      if (audioPath != null && audioPath.isNotEmpty) {
        // We need to get the note ID first - let's query for the most recent note
        final notes = await _database.notesDao.getNotesOrderedByDate();
        if (notes.isNotEmpty) {
          final noteId = notes.first.id;
          final attachment = AttachmentsCompanion.insert(
            noteId: noteId,
            path: audioPath,
            mime: const drift.Value('audio/wav'),
          );
          await _database.into(_database.attachments).insert(attachment);
          print('Audio attachment saved');
        }
      }

      _showMessage('Note saved successfully');
    } catch (e) {
      print('Error saving note: $e');
      _showMessage('Failed to save note');
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

        // Process the recorded file with active STT provider
        final transcribedText = await _sttService.processWavFile(path);

        if (transcribedText.isNotEmpty) {
          setState(() {
            _transcription = transcribedText;
            _partialTranscription = '';
          });

          // Save note to database
          await _saveNoteToDatabase(transcribedText, path);
        }
      }
    } else {
      // Clear previous transcription
      setState(() {
        _transcription = '';
        _partialTranscription = '';
      });

      // Start recording
      await _recorderService.startRecording();
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
    _sttService.dispose();
    _database.close();
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

            const SizedBox(height: 24),

            // STT Provider selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Speech Recognition:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _sttService.getProviderDisplayName(_currentSTTProvider),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _sttService.getProviderDescription(_currentSTTProvider),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.swap_horiz),
                        onPressed: _switchSTTProvider,
                        tooltip: 'Switch provider',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Transcription display
            if (_transcription.isNotEmpty || _partialTranscription.isNotEmpty) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transcription:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _transcription.trim() +
                          (_partialTranscription.isNotEmpty
                              ? ' ${_partialTranscription}'
                              : ''),
                      style: TextStyle(
                        fontSize: 16,
                        color: _partialTranscription.isNotEmpty
                            ? Colors.grey
                            : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Last recording info
            if (_lastRecordingPath != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Last recording:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                _lastRecordingPath!.split('/').last,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
