import 'package:drift/drift.dart';
import '../database.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [Notes, Tags, NoteTags])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(AppDatabase db) : super(db);

  // Get all notes
  Future<List<Note>> getAllNotes() => select(notes).get();

  // Get notes ordered by creation date (newest first)
  Future<List<Note>> getNotesOrderedByDate() {
    return (select(notes)
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  // Get a single note by ID
  Future<Note?> getNoteById(String id) {
    return (select(notes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Get starred notes
  Future<List<Note>> getStarredNotes() {
    return (select(notes)..where((t) => t.isStarred.equals(true))).get();
  }

  // Get pinned notes
  Future<List<Note>> getPinnedNotes() {
    return (select(notes)..where((t) => t.isPinned.equals(true))).get();
  }

  // Search notes by content
  Future<List<Note>> searchNotes(String query) {
    return (select(notes)..where((t) => t.content.like('%$query%'))).get();
  }

  // Insert a new note
  Future<int> insertNote(NotesCompanion note) {
    return into(notes).insert(note);
  }

  // Update a note
  Future<bool> updateNote(NotesCompanion note) {
    return update(notes).replace(note);
  }

  // Delete a note
  Future<int> deleteNote(String id) {
    return (delete(notes)..where((t) => t.id.equals(id))).go();
  }

  // Toggle star
  Future<void> toggleStar(String id, bool isStarred) {
    return (update(notes)..where((t) => t.id.equals(id)))
        .write(NotesCompanion(isStarred: Value(isStarred)));
  }

  // Toggle pin
  Future<void> togglePin(String id, bool isPinned) {
    return (update(notes)..where((t) => t.id.equals(id)))
        .write(NotesCompanion(isPinned: Value(isPinned)));
  }

  // Get tags for a note
  Future<List<Tag>> getTagsForNote(String noteId) {
    final query = select(tags).join([
      innerJoin(noteTags, noteTags.tagId.equalsExp(tags.id)),
    ])
      ..where(noteTags.noteId.equals(noteId));

    return query.map((row) => row.readTable(tags)).get();
  }

  // Add tag to note
  Future<void> addTagToNote(String noteId, String tagId) {
    return into(noteTags).insert(
      NoteTagsCompanion.insert(noteId: noteId, tagId: tagId),
    );
  }

  // Remove tag from note
  Future<void> removeTagFromNote(String noteId, String tagId) {
    return (delete(noteTags)
          ..where((t) => t.noteId.equals(noteId) & t.tagId.equals(tagId)))
        .go();
  }

  // Get notes by tag
  Future<List<Note>> getNotesByTag(String tagId) {
    final query = select(notes).join([
      innerJoin(noteTags, noteTags.noteId.equalsExp(notes.id)),
    ])
      ..where(noteTags.tagId.equals(tagId));

    return query.map((row) => row.readTable(notes)).get();
  }
}
