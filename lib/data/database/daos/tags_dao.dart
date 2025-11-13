import 'package:drift/drift.dart';
import '../database.dart';

part 'tags_dao.g.dart';

@DriftAccessor(tables: [Tags])
class TagsDao extends DatabaseAccessor<AppDatabase> with _$TagsDaoMixin {
  TagsDao(AppDatabase db) : super(db);

  // Get all tags
  Future<List<Tag>> getAllTags() => select(tags).get();

  // Get tag by ID
  Future<Tag?> getTagById(String id) {
    return (select(tags)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Get tag by name
  Future<Tag?> getTagByName(String name) {
    return (select(tags)..where((t) => t.name.equals(name))).getSingleOrNull();
  }

  // Insert a new tag
  Future<int> insertTag(TagsCompanion tag) async {
    return await into(tags).insert(tag);
  }

  // Find or create tag by name
  Future<Tag> findOrCreateTag(String name) async {
    final existing = await getTagByName(name);
    if (existing != null) {
      return existing;
    }

    await insertTag(TagsCompanion.insert(name: name));
    // Fetch the newly created tag
    final newTag = await getTagByName(name);
    return newTag!;
  }

  // Update a tag
  Future<bool> updateTag(TagsCompanion tag) {
    return update(tags).replace(tag);
  }

  // Delete a tag
  Future<int> deleteTag(String id) {
    return (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  // Get tags ordered alphabetically
  Future<List<Tag>> getTagsAlphabetically() {
    return (select(tags)
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)
          ]))
        .get();
  }
}
