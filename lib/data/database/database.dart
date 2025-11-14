import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'daos/notes_dao.dart';
import 'daos/tags_dao.dart';

part 'database.g.dart';

// Notes Table
class Notes extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get content => text()();  // Renamed from 'text' to 'content' to avoid conflict
  TextColumn get lang => text().withDefault(const Constant('auto'))();
  TextColumn get source => text().withDefault(const Constant('voice'))();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get deviceHint => text().nullable()();
  TextColumn get summary => text().nullable()();
  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// Tags Table
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();

  @override
  Set<Column> get primaryKey => {id};
}

// NoteTags Join Table
class NoteTags extends Table {
  TextColumn get noteId => text().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId => text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}

// Attachments Table
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get path => text()();
  TextColumn get mime => text()();
  BlobColumn get bytes => blob().nullable()();
  TextColumn get supabaseUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// SyncState Table
class SyncState extends Table {
  TextColumn get noteId => text().references(Notes, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get lastPushedAt => dateTime().nullable()();
  DateTimeColumn get lastPulledAt => dateTime().nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {noteId};
}

@DriftDatabase(
  tables: [Notes, Tags, NoteTags, Attachments, SyncState],
  daos: [NotesDao, TagsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations will go here
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'note_taking_ai.sqlite'));
    return NativeDatabase(file);
  });
}
