import 'package:hive/hive.dart';

class ImperiumJournalDocument {
  const ImperiumJournalDocument({required this.folders, required this.entries});

  final List<Map<String, Object?>> folders;
  final List<Map<String, Object?>> entries;
}

abstract class ImperiumAppRepository {
  List<Map<String, Object?>> readHabitsSync();
  ImperiumJournalDocument readJournalSync();
  List<Map<String, Object?>> readFinanceSync();
  List<Map<String, Object?>> readFinanceClassesSync();
  Future<void> saveHabits(List<Map<String, Object?>> habits);
  Future<void> saveJournal({
    required List<Map<String, Object?>> folders,
    required List<Map<String, Object?>> entries,
  });
  Future<void> saveFinance(List<Map<String, Object?>> financeEntries);
  Future<void> saveFinanceClasses(List<Map<String, Object?>> financeClasses);
  Future<void> close();

  static Future<ImperiumAppRepository> open({required String storagePath}) {
    return _HiveImperiumAppRepository.open(storagePath: storagePath);
  }

  static ImperiumAppRepository memory({
    List<Map<String, Object?>> habits = const [],
    List<Map<String, Object?>> journalFolders = const [],
    List<Map<String, Object?>> journalEntries = const [],
    List<Map<String, Object?>> financeEntries = const [],
    List<Map<String, Object?>> financeClasses = const [],
  }) {
    return _MemoryImperiumAppRepository(
      habits: habits,
      journalFolders: journalFolders,
      journalEntries: journalEntries,
      financeEntries: financeEntries,
      financeClasses: financeClasses,
    );
  }
}

class _HiveImperiumAppRepository implements ImperiumAppRepository {
  _HiveImperiumAppRepository._(this._box);

  static const _boxName = 'imperium_sui_documents';
  static const _habitsKey = 'habits';
  static const _journalFoldersKey = 'journal_folders';
  static const _journalEntriesKey = 'journal_entries';
  static const _financeEntriesKey = 'finance_entries';
  static const _financeClassesKey = 'finance_classes';

  final Box<dynamic> _box;

  static Future<ImperiumAppRepository> open({
    required String storagePath,
  }) async {
    if (Hive.isBoxOpen(_boxName)) {
      final openBox = Hive.box<dynamic>(_boxName);
      final normalizedBasePath = storagePath.replaceAll('\\', '/');
      final normalizedBoxPath = (openBox.path ?? '').replaceAll('\\', '/');

      if (normalizedBoxPath.startsWith(normalizedBasePath)) {
        return _HiveImperiumAppRepository._(openBox);
      }

      await Hive.close();
    }

    Hive.init(storagePath);
    final box = await Hive.openBox<dynamic>(_boxName);
    return _HiveImperiumAppRepository._(box);
  }

  @override
  List<Map<String, Object?>> readHabitsSync() {
    return _readDocument(_habitsKey) ?? const [];
  }

  @override
  ImperiumJournalDocument readJournalSync() {
    return ImperiumJournalDocument(
      folders: _readDocument(_journalFoldersKey) ?? const [],
      entries: _readDocument(_journalEntriesKey) ?? const [],
    );
  }

  @override
  List<Map<String, Object?>> readFinanceSync() {
    return _readDocument(_financeEntriesKey) ?? const [];
  }

  @override
  List<Map<String, Object?>> readFinanceClassesSync() {
    return _readDocument(_financeClassesKey) ?? const [];
  }

  @override
  Future<void> saveHabits(List<Map<String, Object?>> habits) async {
    await _box.put(_habitsKey, _normalizeDocument(habits));
  }

  @override
  Future<void> saveJournal({
    required List<Map<String, Object?>> folders,
    required List<Map<String, Object?>> entries,
  }) async {
    await _box.put(_journalFoldersKey, _normalizeDocument(folders));
    await _box.put(_journalEntriesKey, _normalizeDocument(entries));
  }

  @override
  Future<void> saveFinance(List<Map<String, Object?>> financeEntries) async {
    await _box.put(_financeEntriesKey, _normalizeDocument(financeEntries));
  }

  @override
  Future<void> saveFinanceClasses(
    List<Map<String, Object?>> financeClasses,
  ) async {
    await _box.put(_financeClassesKey, _normalizeDocument(financeClasses));
  }

  @override
  Future<void> close() async {
    await _box.close();
  }

  List<Map<String, Object?>>? _readDocument(String key) {
    final rawDocument = _box.get(key);

    if (rawDocument is! List) {
      return null;
    }

    return _normalizeDocument(rawDocument);
  }

  List<Map<String, Object?>> _normalizeDocument(List<dynamic> rawDocument) {
    return rawDocument
        .whereType<Map>()
        .map(
          (item) => item.map<String, Object?>(
            (key, value) => MapEntry(key.toString(), value),
          ),
        )
        .toList(growable: false);
  }
}

class _MemoryImperiumAppRepository implements ImperiumAppRepository {
  _MemoryImperiumAppRepository({
    required List<Map<String, Object?>> habits,
    required List<Map<String, Object?>> journalFolders,
    required List<Map<String, Object?>> journalEntries,
    required List<Map<String, Object?>> financeEntries,
    required List<Map<String, Object?>> financeClasses,
  }) : _habits = _cloneDocument(habits),
       _journalFolders = _cloneDocument(journalFolders),
       _journalEntries = _cloneDocument(journalEntries),
       _financeEntries = _cloneDocument(financeEntries),
       _financeClasses = _cloneDocument(financeClasses);

  List<Map<String, Object?>> _habits;
  List<Map<String, Object?>> _journalFolders;
  List<Map<String, Object?>> _journalEntries;
  List<Map<String, Object?>> _financeEntries;
  List<Map<String, Object?>> _financeClasses;

  @override
  List<Map<String, Object?>> readHabitsSync() {
    return _cloneDocument(_habits);
  }

  @override
  ImperiumJournalDocument readJournalSync() {
    return ImperiumJournalDocument(
      folders: _cloneDocument(_journalFolders),
      entries: _cloneDocument(_journalEntries),
    );
  }

  @override
  List<Map<String, Object?>> readFinanceSync() {
    return _cloneDocument(_financeEntries);
  }

  @override
  List<Map<String, Object?>> readFinanceClassesSync() {
    return _cloneDocument(_financeClasses);
  }

  @override
  Future<void> saveHabits(List<Map<String, Object?>> habits) async {
    _habits = _cloneDocument(habits);
  }

  @override
  Future<void> saveJournal({
    required List<Map<String, Object?>> folders,
    required List<Map<String, Object?>> entries,
  }) async {
    _journalFolders = _cloneDocument(folders);
    _journalEntries = _cloneDocument(entries);
  }

  @override
  Future<void> saveFinance(List<Map<String, Object?>> financeEntries) async {
    _financeEntries = _cloneDocument(financeEntries);
  }

  @override
  Future<void> saveFinanceClasses(
    List<Map<String, Object?>> financeClasses,
  ) async {
    _financeClasses = _cloneDocument(financeClasses);
  }

  @override
  Future<void> close() async {}

  static List<Map<String, Object?>> _cloneDocument(
    List<Map<String, Object?>> document,
  ) {
    return document
        .map((entry) => Map<String, Object?>.from(entry))
        .toList(growable: false);
  }
}
