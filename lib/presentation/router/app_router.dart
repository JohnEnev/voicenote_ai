import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/capture_screen.dart';
import '../screens/notes_list_screen.dart';
import '../screens/note_detail_screen.dart';
import '../screens/settings_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/capture',
    routes: [
      GoRoute(
        path: '/capture',
        name: 'capture',
        builder: (context, state) => const CaptureScreen(),
      ),
      GoRoute(
        path: '/notes',
        name: 'notes',
        builder: (context, state) => const NotesListScreen(),
      ),
      GoRoute(
        path: '/note/:id',
        name: 'note-detail',
        builder: (context, state) {
          final noteId = state.pathParameters['id']!;
          return NoteDetailScreen(noteId: noteId);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
}
