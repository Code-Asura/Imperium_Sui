import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imperium_sui/app/app.dart';
import 'package:imperium_sui/core/data/imperium_app_repository.dart';
import 'package:imperium_sui/features/habits/presentation/habits_home_screen.dart';

void main() {
  Finder verticalScrollable() => find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );

  Future<void> settleUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));
  }

  String financeMonthLabel(DateTime date) {
    const months = [
      'Января',
      'Февраля',
      'Марта',
      'Апреля',
      'Мая',
      'Июня',
      'Июля',
      'Августа',
      'Сентября',
      'Октября',
      'Ноября',
      'Декабря',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  List<Map<String, Object?>> seedHabits() {
    return [
      {
        'id': 'stretch',
        'title': 'Утренняя зарядка',
        'description': 'Короткий запуск тела перед первым экраном.',
        'cue': 'после стакана воды',
        'timeLabel': '07:30',
        'streakDays': 12,
        'focusMinutes': 8,
        'iconCodePoint': Icons.self_improvement_rounded.codePoint,
        'iconFontFamily': Icons.self_improvement_rounded.fontFamily,
        'iconFontPackage': Icons.self_improvement_rounded.fontPackage,
        'iconMatchTextDirection':
            Icons.self_improvement_rounded.matchTextDirection,
        'tone': 'mint',
        'targetCount': 1,
        'completedCount': 1,
      },
      {
        'id': 'focus',
        'title': 'Фокус-спринт',
        'description': 'Один плотный блок без переключений.',
        'cue': 'сразу после плана',
        'timeLabel': '09:00',
        'streakDays': 9,
        'focusMinutes': 45,
        'iconCodePoint': Icons.bolt_rounded.codePoint,
        'iconFontFamily': Icons.bolt_rounded.fontFamily,
        'iconFontPackage': Icons.bolt_rounded.fontPackage,
        'iconMatchTextDirection': Icons.bolt_rounded.matchTextDirection,
        'tone': 'denim',
        'targetCount': 3,
        'completedCount': 1,
      },
      {
        'id': 'water',
        'title': 'Вода и пауза',
        'description': 'Небольшой reset после встреч.',
        'cue': 'после каждого созвона',
        'timeLabel': '14:00',
        'streakDays': 6,
        'focusMinutes': 5,
        'iconCodePoint': Icons.local_drink_rounded.codePoint,
        'iconFontFamily': Icons.local_drink_rounded.fontFamily,
        'iconFontPackage': Icons.local_drink_rounded.fontPackage,
        'iconMatchTextDirection': Icons.local_drink_rounded.matchTextDirection,
        'tone': 'amber',
        'targetCount': 3,
        'completedCount': 3,
      },
      {
        'id': 'review',
        'title': 'Вечерний обзор',
        'description': 'Три строки о дне перед сном.',
        'cue': 'перед тем как убрать телефон',
        'timeLabel': '21:30',
        'streakDays': 16,
        'focusMinutes': 10,
        'iconCodePoint': Icons.nightlight_round.codePoint,
        'iconFontFamily': Icons.nightlight_round.fontFamily,
        'iconFontPackage': Icons.nightlight_round.fontPackage,
        'iconMatchTextDirection': Icons.nightlight_round.matchTextDirection,
        'tone': 'coral',
        'targetCount': 1,
        'completedCount': 0,
      },
    ];
  }

  List<Map<String, Object?>> seedJournalFolders() {
    return [
      {
        'id': 'folder-archive',
        'title': 'Личный архив',
        'entryCount': 3,
        'iconCodePoint': Icons.inventory_2_rounded.codePoint,
        'iconFontFamily': Icons.inventory_2_rounded.fontFamily,
        'iconFontPackage': Icons.inventory_2_rounded.fontPackage,
        'iconMatchTextDirection': Icons.inventory_2_rounded.matchTextDirection,
        'accentValue': const Color(0xFF5A3126).toARGB32(),
      },
    ];
  }

  List<Map<String, Object?>> seedJournalEntries() {
    return [
      {
        'id': 'journal-entry-1',
        'folder': 'Личный архив',
        'content': 'Утренние заметки\nФокус перед первым спринтом.',
        'dateLabel': 'Сегодня, 07:40',
        'durationLabel': '3 мин',
        'isPinned': true,
      },
      {
        'id': 'journal-entry-2',
        'folder': 'Личный архив',
        'content': 'Дневной обзор\nМедитация и короткая перезагрузка.',
        'dateLabel': 'Сегодня, 13:10',
        'durationLabel': '4 мин',
        'isPinned': false,
      },
      {
        'id': 'journal-entry-3',
        'folder': 'Личный архив',
        'content': 'Вечернее завершение\nПара строк о дне.',
        'dateLabel': 'Вчера, 21:15',
        'durationLabel': '3 мин',
        'isPinned': true,
      },
    ];
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = ImperiumAppRepository.memory(
      habits: seedHabits(),
      journalFolders: seedJournalFolders(),
      journalEntries: seedJournalEntries(),
    );

    addTearDown(() async {
      await repository.close();
    });

    await tester.pumpWidget(ImperiumSuiApp(repository: repository));
    await settleUi(tester);
  }

  Future<void> openJournalTab(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await settleUi(tester);
  }

  Future<void> openFinanceTab(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.account_balance_wallet_rounded));
    await settleUi(tester);
  }

  testWidgets('switches between bottom navigation tabs', (tester) async {
    await pumpApp(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(HabitsHomeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('imperial-bottom-nav')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-habits')), findsOneWidget);

    await openJournalTab(tester);
    expect(find.byKey(const ValueKey('tab-journal')), findsOneWidget);

    await openFinanceTab(tester);

    expect(find.byKey(const ValueKey('tab-finance')), findsOneWidget);
  });

  testWidgets('creates finance entry from add button', (tester) async {
    await pumpApp(tester);
    await openFinanceTab(tester);

    await tester.tap(find.byKey(const ValueKey('add-finance-entry-button')));
    await settleUi(tester);

    await tester.tap(find.byKey(const ValueKey('finance-entry-type-income')));
    await settleUi(tester);

    await tester.tap(
      find.byKey(const ValueKey('finance-entry-class-income-main')),
    );
    await settleUi(tester);

    await tester.enterText(
      find.byKey(const ValueKey('finance-entry-amount')),
      '120000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('finance-entry-note')),
      'За март',
    );
    await tester.tap(find.byKey(const ValueKey('finance-entry-save')));
    await settleUi(tester);

    await tester.scrollUntilVisible(
      find.text('Основной доход'),
      300,
      scrollable: verticalScrollable(),
    );
    await settleUi(tester);

    expect(find.text('Основной доход'), findsOneWidget);
    expect(find.text('+120 000 ₽'), findsWidgets);
    expect(find.text(financeMonthLabel(DateTime.now())), findsOneWidget);
  });

  testWidgets('creates finance income class', (tester) async {
    await pumpApp(tester);
    await openFinanceTab(tester);

    await tester.tap(find.byKey(const ValueKey('open-finance-classes-button')));
    await settleUi(tester);

    expect(
      find.byKey(const ValueKey('finance-classes-scroll')),
      findsOneWidget,
    );
    expect(find.text('Накопления'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('add-finance-class-income-button')),
    );
    await settleUi(tester);

    await tester.enterText(
      find.byKey(const ValueKey('finance-class-name-income')),
      'Роялти',
    );
    await tester.tap(find.byKey(const ValueKey('finance-class-save-income')));
    await settleUi(tester);

    expect(find.text('Роялти'), findsOneWidget);
  });

  testWidgets('edits finance class from classes screen', (tester) async {
    await pumpApp(tester);
    await openFinanceTab(tester);

    await tester.tap(find.byKey(const ValueKey('open-finance-classes-button')));
    await settleUi(tester);

    await tester.tap(
      find.byKey(const ValueKey('edit-finance-class-income-main')),
    );
    await settleUi(tester);

    await tester.enterText(
      find.byKey(const ValueKey('finance-class-name-income')),
      'Зарплата',
    );
    await tester.tap(find.byKey(const ValueKey('finance-class-save-income')));
    await settleUi(tester);

    expect(find.text('Зарплата'), findsOneWidget);
  });

  testWidgets('journal tab shows folders and pinned entries', (tester) async {
    await pumpApp(tester);
    await openJournalTab(tester);

    expect(find.byKey(const ValueKey('journal-hero-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('journal-hero-words')), findsOneWidget);
    expect(find.byKey(const ValueKey('journal-hero-entries')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('journal-folders')),
      250,
      scrollable: verticalScrollable(),
    );
    await settleUi(tester);

    expect(find.byKey(const ValueKey('journal-folders')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journal-folder-card-folder-archive')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('journal-scroll')),
        matching: find.byKey(const ValueKey('journal-entry-journal-entry-1')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('creates journal folder from add button', (tester) async {
    await pumpApp(tester);
    await openJournalTab(tester);

    final addFolderButton = find.byKey(
      const ValueKey('add-journal-folder-button'),
    );

    await tester.scrollUntilVisible(
      addFolderButton,
      250,
      scrollable: verticalScrollable(),
    );
    await settleUi(tester);

    await tester.tap(addFolderButton);
    await settleUi(tester);

    await tester.enterText(
      find.byKey(const ValueKey('journal-folder-title')),
      'Artifacts',
    );
    await tester.tap(find.byKey(const ValueKey('journal-folder-save')));
    await settleUi(tester);

    expect(find.text('Artifacts'), findsWidgets);
  });

  testWidgets('opens and edits journal folder details', (tester) async {
    await pumpApp(tester);
    await openJournalTab(tester);

    await tester.tap(
      find.byKey(const ValueKey('journal-folder-card-folder-archive')),
    );
    await settleUi(tester);

    final folderSheet = find.byKey(
      const ValueKey('journal-folder-sheet-folder-archive'),
    );

    expect(folderSheet, findsOneWidget);
    expect(
      find.descendant(
        of: folderSheet,
        matching: find.byKey(const ValueKey('journal-entry-journal-entry-1')),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('edit-journal-folder-button')));
    await settleUi(tester);

    await tester.enterText(
      find.byKey(const ValueKey('journal-folder-title')),
      'Chronicles',
    );
    await tester.tap(find.byKey(const ValueKey('journal-folder-save')));
    await settleUi(tester);

    expect(find.text('Chronicles'), findsWidgets);
  });

  testWidgets('creates journal entry from add button', (tester) async {
    await pumpApp(tester);
    await openJournalTab(tester);

    final addEntryButton = find.byKey(
      const ValueKey('add-journal-entry-button'),
    );
    await tester.scrollUntilVisible(
      addEntryButton,
      250,
      scrollable: verticalScrollable(),
    );
    await settleUi(tester);

    await tester.tap(addEntryButton);
    await settleUi(tester);

    await tester.enterText(
      find.byKey(const ValueKey('journal-entry-content')),
      'Field note\nShort reflection after the sprint.',
    );
    await tester.tap(find.byKey(const ValueKey('journal-entry-save')));
    await settleUi(tester);

    expect(find.text('Field note'), findsNothing);

    final archiveFolder = find
        .byKey(const ValueKey('journal-folder-card-folder-archive'))
        .first;
    await tester.ensureVisible(archiveFolder);
    await settleUi(tester);

    await tester.tap(archiveFolder, warnIfMissed: false);
    await settleUi(tester);

    expect(find.text('Field note'), findsOneWidget);
  });

  testWidgets('journal entry swipes right to edit', (tester) async {
    await pumpApp(tester);
    await openJournalTab(tester);

    final entry = find.byKey(const ValueKey('journal-entry-journal-entry-1'));
    await tester.scrollUntilVisible(
      entry,
      250,
      scrollable: verticalScrollable(),
    );
    await settleUi(tester);

    await tester.drag(entry, const Offset(320, 0));
    await settleUi(tester);

    await tester.enterText(
      find.byKey(const ValueKey('journal-entry-content')),
      'Edited note\nEvening block',
    );
    await tester.tap(find.byKey(const ValueKey('journal-entry-save')));
    await settleUi(tester);

    expect(find.text('Edited note'), findsOneWidget);
  });

  testWidgets('journal entry swipes left on home to hide only', (tester) async {
    await pumpApp(tester);
    await openJournalTab(tester);

    final entry = find.byKey(const ValueKey('journal-entry-journal-entry-1'));
    await tester.scrollUntilVisible(
      entry,
      250,
      scrollable: verticalScrollable(),
    );
    await settleUi(tester);

    await tester.drag(entry, const Offset(-320, 0));
    await settleUi(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('journal-scroll')),
        matching: find.byKey(const ValueKey('journal-entry-journal-entry-1')),
      ),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('journal-folder-card-folder-archive')),
    );
    await settleUi(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('journal-folder-sheet-folder-archive')),
        matching: find.byKey(const ValueKey('journal-entry-journal-entry-1')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('journal entry swipes left in folder to pin', (tester) async {
    await pumpApp(tester);
    await openJournalTab(tester);

    await tester.tap(
      find.byKey(const ValueKey('journal-folder-card-folder-archive')),
    );
    await settleUi(tester);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('journal-entry-journal-entry-2')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('journal-folder-sheet-folder-archive')),
        matching: find.byType(Scrollable),
      ),
    );
    await settleUi(tester);

    await tester.drag(
      find.byKey(const ValueKey('journal-entry-journal-entry-2')),
      const Offset(-320, 0),
    );
    await settleUi(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('journal-entry-journal-entry-2')),
        matching: find.byIcon(Icons.push_pin_rounded),
      ),
      findsWidgets,
    );
  });

  testWidgets('long press deletes journal entry after confirmation', (
    tester,
  ) async {
    await pumpApp(tester);
    await openJournalTab(tester);

    final entry = find.byKey(const ValueKey('journal-entry-journal-entry-1'));
    await tester.scrollUntilVisible(
      entry,
      250,
      scrollable: verticalScrollable(),
    );
    await settleUi(tester);

    final gesture = await tester.startGesture(tester.getCenter(entry));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await settleUi(tester);

    expect(
      find.byKey(const ValueKey('journal-entry-delete-confirm')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('journal-entry-delete-confirm')),
    );
    await settleUi(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('journal-scroll')),
        matching: find.byKey(const ValueKey('journal-entry-journal-entry-1')),
      ),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('journal-folder-card-folder-archive')),
    );
    await settleUi(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('journal-folder-sheet-folder-archive')),
        matching: find.byKey(const ValueKey('journal-entry-journal-entry-1')),
      ),
      findsNothing,
    );
  });

  testWidgets('swipes update habit counter', (tester) async {
    await pumpApp(tester);

    final focusCard = find.byKey(const ValueKey('habit-card-focus'));
    await tester.scrollUntilVisible(focusCard, 300);
    await settleUi(tester);

    expect(
      find.descendant(of: focusCard, matching: find.text('1/3')),
      findsOneWidget,
    );

    await tester.drag(focusCard, const Offset(320, 0));
    await settleUi(tester);

    expect(
      find.descendant(of: focusCard, matching: find.text('2/3')),
      findsOneWidget,
    );

    await tester.drag(focusCard, const Offset(-320, 0));
    await settleUi(tester);

    expect(
      find.descendant(of: focusCard, matching: find.text('1/3')),
      findsOneWidget,
    );
  });

  testWidgets('long press radial menu deletes habit', (tester) async {
    await pumpApp(tester);

    final reviewHabit = find.byKey(const ValueKey('habit-card-review'));
    await tester.scrollUntilVisible(reviewHabit, 400);
    await settleUi(tester);

    final gesture = await tester.startGesture(tester.getCenter(reviewHabit));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump(const Duration(milliseconds: 80));
    await gesture.up();
    await settleUi(tester);

    expect(reviewHabit, findsNothing);
  });

  testWidgets('long press radial menu edits habit', (tester) async {
    await pumpApp(tester);

    final stretchHabit = find.byKey(const ValueKey('habit-card-stretch'));
    await tester.scrollUntilVisible(stretchHabit, 250);
    await settleUi(tester);

    final gesture = await tester.startGesture(tester.getCenter(stretchHabit));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 80));
    await gesture.up();
    await settleUi(tester);

    expect(find.byKey(const ValueKey('habit-editor-title')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('habit-editor-title')),
      'Stretch reset',
    );
    await tester.tap(find.byKey(const ValueKey('habit-editor-save')));
    await settleUi(tester);

    expect(find.text('Stretch reset'), findsOneWidget);
  });

  testWidgets('creates habit from new habit button', (tester) async {
    await pumpApp(tester);

    final addButton = find.byKey(const ValueKey('add-habit-button'));
    await tester.scrollUntilVisible(addButton, 400);
    await settleUi(tester);

    await tester.tap(addButton);
    await settleUi(tester);

    await tester.enterText(
      find.byKey(const ValueKey('habit-editor-title')),
      'New habit',
    );
    await tester.tap(find.byKey(const ValueKey('habit-editor-save')));
    await settleUi(tester);

    await tester.scrollUntilVisible(find.text('New habit'), 300);
    await settleUi(tester);

    expect(find.text('New habit'), findsOneWidget);
  });
}
