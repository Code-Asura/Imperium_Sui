import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/data/imperium_app_repository.dart';
import '../../journal/presentation/journal_home_screen.dart';

class HabitsHomeScreen extends StatefulWidget {
  const HabitsHomeScreen({super.key, required this.repository});

  final ImperiumAppRepository repository;

  @override
  State<HabitsHomeScreen> createState() => _HabitsHomeScreenState();
}

class _HabitsHomeScreenState extends State<HabitsHomeScreen> {
  int _selectedIndex = 1;
  List<_HabitSnapshot> _habits = const [];
  bool _isLoadingHabits = true;

  @override
  void initState() {
    super.initState();
    _hydrateHabits();
  }

  void _hydrateHabits() {
    try {
      final storedHabits = widget.repository.readHabitsSync();
      _habits = storedHabits.map(_HabitSnapshot.fromMap).toList();
      _isLoadingHabits = false;
    } catch (_) {
      _habits = const [];
      _isLoadingHabits = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showStorageMessage('Не удалось загрузить привычки из базы.');
        }
      });
    }
  }

  Future<void> _saveHabits() async {
    try {
      await widget.repository.saveHabits(
        _habits.map((habit) => habit.toMap()).toList(growable: false),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showStorageMessage('Не удалось сохранить привычки.');
    }
  }

  void _showStorageMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  int get _completedHabitsCount =>
      _habits.where((habit) => habit.isCompleted).length;

  _HabitSnapshot _buildDraftHabit(int index) {
    final now = DateTime.now();

    return _HabitSnapshot(
      id: 'habit-${now.microsecondsSinceEpoch}',
      title: '',
      description: '',
      cue: '',
      timeLabel: '',
      streakDays: 0,
      focusMinutes: 10,
      icon: _draftHabitIcons[index % _draftHabitIcons.length],
      tone: _HabitTone.values[index % _HabitTone.values.length],
      targetCount: 1,
      completedCount: 0,
    );
  }

  Future<_HabitSnapshot?> _showHabitEditor(
    _HabitSnapshot habit, {
    required bool isCreating,
  }) {
    return showModalBottomSheet<_HabitSnapshot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _HabitEditorSheet(habit: habit, isCreating: isCreating),
    );
  }

  Future<void> _addHabit() async {
    final createdHabit = await _showHabitEditor(
      _buildDraftHabit(_habits.length),
      isCreating: true,
    );

    if (!mounted || createdHabit == null) {
      return;
    }

    setState(() {
      _habits = [..._habits, createdHabit];
    });
    await _saveHabits();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('Привычка "${createdHabit.title}" добавлена')),
      );
  }

  Future<void> _editHabit(String id) async {
    final index = _habits.indexWhere((habit) => habit.id == id);
    if (index == -1) {
      return;
    }

    final editedHabit = await _showHabitEditor(
      _habits[index],
      isCreating: false,
    );

    if (!mounted || editedHabit == null) {
      return;
    }

    setState(() {
      _habits[index] = editedHabit;
    });

    await _saveHabits();
  }

  void _deleteHabit(String id) {
    final index = _habits.indexWhere((habit) => habit.id == id);
    if (index == -1) {
      return;
    }

    final removedHabit = _habits[index];

    setState(() {
      _habits.removeAt(index);
    });
    unawaited(_saveHabits());

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Привычка "${removedHabit.title}" удалена'),
        action: SnackBarAction(
          label: 'Вернуть',
          onPressed: () {
            if (!mounted) {
              return;
            }

            setState(() {
              final insertIndex = math.min(index, _habits.length);
              _habits.insert(insertIndex, removedHabit);
            });
            unawaited(_saveHabits());
          },
        ),
      ),
    );
  }

  void _incrementHabit(String id) {
    var didChange = false;

    setState(() {
      final index = _habits.indexWhere((habit) => habit.id == id);
      if (index == -1) {
        return;
      }

      final habit = _habits[index];
      if (!habit.canIncrement) {
        return;
      }

      _habits[index] = habit.copyWith(
        completedCount: math.min(habit.completedCount + 1, habit.targetCount),
      );
      didChange = true;
    });

    if (didChange) {
      unawaited(_saveHabits());
    }
  }

  void _decrementHabit(String id) {
    var didChange = false;

    setState(() {
      final index = _habits.indexWhere((habit) => habit.id == id);
      if (index == -1) {
        return;
      }

      final habit = _habits[index];
      if (!habit.canDecrement) {
        return;
      }

      _habits[index] = habit.copyWith(
        completedCount: math.max(habit.completedCount - 1, 0),
      );
      didChange = true;
    });

    if (didChange) {
      unawaited(_saveHabits());
    }
  }

  Widget _buildCurrentTab() {
    if (_selectedIndex == 0) {
      return JournalHomeTab(
        key: const ValueKey('tab-journal'),
        repository: widget.repository,
      );
    }

    if (_selectedIndex == 2) {
      return _FinanceTab(
        key: const ValueKey('tab-finance'),
        repository: widget.repository,
      );
    }

    if (_isLoadingHabits) {
      return const _LoadingTab(key: ValueKey('tab-habits-loading'));
    }

    return switch (_selectedIndex) {
      0 => const _PlaceholderTab(
        key: ValueKey('tab-journal'),
        icon: Icons.menu_book_rounded,
        title: 'Дневник',
        subtitle: 'Здесь будут записи дня, короткие выводы и личные заметки.',
      ),
      1 => _TodayTab(
        key: const ValueKey('tab-habits'),
        habits: _habits,
        completedHabitsCount: _completedHabitsCount,
        onIncrementHabit: _incrementHabit,
        onDecrementHabit: _decrementHabit,
        onAddHabit: _addHabit,
        onEditHabit: _editHabit,
        onDeleteHabit: _deleteHabit,
      ),
      _ => const _PlaceholderTab(
        key: ValueKey('tab-profile'),
        icon: Icons.person_rounded,
        title: 'Профиль',
        subtitle: 'Тут появятся настройки, цели и личная статистика.',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      backgroundColor: const Color(0xFF0A0707),
      body: _ScreenFrame(child: _buildCurrentTab()),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: _ImperialBottomNav(
          selectedIndex: _selectedIndex,
          onSelect: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
      ),
    );
  }
}

class _ScreenFrame extends StatelessWidget {
  const _ScreenFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _ScreenBackgroundLayer()),
        SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _ScreenUiLayer(child: child),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScreenBackgroundLayer extends StatelessWidget {
  const _ScreenBackgroundLayer();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Color(0xFF0A0707));
  }
}

class _ScreenUiLayer extends StatelessWidget {
  const _ScreenUiLayer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class _LoadingTab extends StatelessWidget {
  const _LoadingTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _TextRenderLayer extends StatelessWidget {
  const _TextRenderLayer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class _ImperialBottomNav extends StatelessWidget {
  const _ImperialBottomNav({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _items = [
    _ImperialNavItemData(label: 'Дневник', icon: Icons.menu_book_rounded),
    _ImperialNavItemData(label: 'Привычки', icon: Icons.shield_moon_rounded),
    _ImperialNavItemData(label: 'Профиль', icon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;

    return Container(
      key: const ValueKey('imperial-bottom-nav'),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A100F), Color(0xFF0E0909)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: gold.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_items.length, (index) {
          final item = index == 2
              ? const _ImperialNavItemData(
                  label: '\u0424\u0438\u043d\u0430\u043d\u0441\u044b',
                  icon: Icons.account_balance_wallet_rounded,
                )
              : _items[index];

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _ImperialBottomNavItem(
                item: item,
                isSelected: index == selectedIndex,
                isCenter: index == 1,
                onTap: () => onSelect(index),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ImperialBottomNavItem extends StatelessWidget {
  const _ImperialBottomNavItem({
    required this.item,
    required this.isSelected,
    required this.isCenter,
    required this.onTap,
  });

  final _ImperialNavItemData item;
  final bool isSelected;
  final bool isCenter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;
    final foreground = isSelected
        ? (isCenter ? const Color(0xFF150D0C) : Colors.white)
        : Colors.white.withValues(alpha: 0.68);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(6, isCenter ? 5 : 6, 6, 6),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isCenter
                        ? const [Color(0xFFD5B277), Color(0xFFB2874B)]
                        : [
                            gold.withValues(alpha: 0.24),
                            const Color(0xFF2A1713),
                          ],
                  )
                : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? gold.withValues(alpha: isCenter ? 0.34 : 0.22)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: isCenter ? 24 : 20,
                height: isCenter ? 24 : 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Colors.black.withValues(alpha: isCenter ? 0.08 : 0.14)
                      : Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: isSelected
                        ? gold.withValues(alpha: isCenter ? 0.16 : 0.24)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Icon(
                  item.icon,
                  size: isCenter ? 14 : 12,
                  color: foreground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: isCenter && isSelected ? 0.4 : 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImperialNavItemData {
  const _ImperialNavItemData({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _LocalClampedScrollBehavior extends ScrollBehavior {
  const _LocalClampedScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab({
    super.key,
    required this.habits,
    required this.completedHabitsCount,
    required this.onIncrementHabit,
    required this.onDecrementHabit,
    required this.onAddHabit,
    required this.onEditHabit,
    required this.onDeleteHabit,
  });

  final List<_HabitSnapshot> habits;
  final int completedHabitsCount;
  final ValueChanged<String> onIncrementHabit;
  final ValueChanged<String> onDecrementHabit;
  final VoidCallback onAddHabit;
  final ValueChanged<String> onEditHabit;
  final ValueChanged<String> onDeleteHabit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;

    return ScrollConfiguration(
      behavior: const _LocalClampedScrollBehavior(),
      child: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: (notification) {
          notification.disallowIndicator();
          return true;
        },
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TextRenderLayer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IMPERIUM SUI',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: gold,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            'Привычки',
                            maxLines: 1,
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontSize: 30,
                              height: 1.08,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF39201A), Color(0xFF170F0D)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gold.withValues(alpha: 0.45)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(Icons.workspace_premium_rounded, color: gold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SummaryCard(
              habits: habits,
              completedHabitsCount: completedHabitsCount,
              totalHabitsCount: habits.length,
            ),
            const SizedBox(height: 14),
            _AddHabitCard(onAdd: onAddHabit),
            const SizedBox(height: 18),
            for (final habit in habits) ...[
              _HabitCard(
                habit: habit,
                onIncrement: () => onIncrementHabit(habit.id),
                onDecrement: () => onDecrementHabit(habit.id),
                onEdit: () => onEditHabit(habit.id),
                onDelete: () => onDeleteHabit(habit.id),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _FinanceTab extends StatefulWidget {
  const _FinanceTab({super.key, required this.repository});

  final ImperiumAppRepository repository;

  @override
  State<_FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<_FinanceTab> {
  List<_FinanceEntrySnapshot> _entries = const [];
  List<_FinanceClassSnapshot> _classes = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _hydrateFinance();
  }

  Map<String, _FinanceClassSnapshot> get _classesById => {
    for (final financeClass in _classes) financeClass.id: financeClass,
  };

  Map<String, int> get _classEntryCounts {
    final counts = <String, int>{};

    for (final entry in _entries) {
      counts.update(entry.classId, (value) => value + 1, ifAbsent: () => 1);
    }

    return counts;
  }

  int get _totalBalance =>
      _entries.fold(0, (sum, entry) => sum + entry.signedAmount);

  int get _monthlyIncome => _entries
      .where(
        (entry) =>
            entry.type == _FinanceEntryType.income &&
            _isCurrentMonth(entry.occurredAt),
      )
      .fold(0, (sum, entry) => sum + entry.amount);

  int get _monthlyExpense => _entries
      .where(
        (entry) =>
            entry.type == _FinanceEntryType.expense &&
            _isCurrentMonth(entry.occurredAt),
      )
      .fold(0, (sum, entry) => sum + entry.amount);

  int get _monthlyIncomeCount => _entries
      .where(
        (entry) =>
            entry.type == _FinanceEntryType.income &&
            _isCurrentMonth(entry.occurredAt),
      )
      .length;

  int get _monthlyExpenseCount => _entries
      .where(
        (entry) =>
            entry.type == _FinanceEntryType.expense &&
            _isCurrentMonth(entry.occurredAt),
      )
      .length;

  int get _reserveBalance => _bucketBalance(_FinanceBucket.reserve);

  int get _plannedSpend => _entries
      .where(
        (entry) =>
            entry.type == _FinanceEntryType.expense &&
            _isCurrentMonth(entry.occurredAt),
      )
      .fold(0, (sum, entry) => sum + entry.amount);

  List<_FinanceMonthGroup> get _monthlyGroups {
    final groupedEntries = <String, List<_FinanceEntrySnapshot>>{};

    for (final entry in _entries) {
      final key = '${entry.occurredAt.year}-${entry.occurredAt.month}';
      groupedEntries.putIfAbsent(key, () => []).add(entry);
    }

    final groups =
        groupedEntries.entries
            .map((entry) {
              final parts = entry.key.split('-');
              final year = int.tryParse(parts[0]) ?? 0;
              final month = int.tryParse(parts[1]) ?? 1;
              final entries = [...entry.value]
                ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

              return _FinanceMonthGroup(
                year: year,
                month: month,
                entries: entries,
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final yearCompare = b.year.compareTo(a.year);
            if (yearCompare != 0) {
              return yearCompare;
            }

            return b.month.compareTo(a.month);
          });

    return groups;
  }

  void _hydrateFinance() {
    try {
      final loadedClasses = widget.repository.readFinanceClassesSync();
      final parsedClasses = loadedClasses
          .map(_FinanceClassSnapshot.fromMap)
          .toList(growable: false);

      _classes = parsedClasses.isEmpty ? _defaultFinanceClasses : parsedClasses;
      _entries =
          widget.repository
              .readFinanceSync()
              .map(_FinanceEntrySnapshot.fromMap)
              .toList()
            ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      _isLoading = false;

      if (parsedClasses.isEmpty) {
        unawaited(_saveFinanceClasses());
      }
    } catch (_) {
      _entries = const [];
      _classes = _defaultFinanceClasses;
      _isLoading = false;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMessage('Не удалось загрузить финансы из базы.');
        }
      });
    }
  }

  Future<void> _saveFinance() async {
    try {
      await widget.repository.saveFinance(
        _entries.map((entry) => entry.toMap()).toList(growable: false),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Не удалось сохранить финансы.');
    }
  }

  Future<void> _saveFinanceClasses() async {
    try {
      await widget.repository.saveFinanceClasses(
        _classes
            .map((financeClass) => financeClass.toMap())
            .toList(growable: false),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Не удалось сохранить классы операций.');
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<_FinanceEntrySnapshot?> _showFinanceEntryEditor() {
    return showModalBottomSheet<_FinanceEntrySnapshot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FinanceEntryComposerSheet(classes: _classes),
    );
  }

  Future<void> _addEntry() async {
    final createdEntry = await _showFinanceEntryEditor();

    if (!mounted || createdEntry == null) {
      return;
    }

    setState(() {
      _entries = [createdEntry, ..._entries]
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    });
    await _saveFinance();

    if (!mounted) {
      return;
    }

    _showMessage('Операция "${createdEntry.title}" сохранена.');
  }

  Future<void> _openFinanceClasses() async {
    final updatedClasses = await Navigator.of(context)
        .push<List<_FinanceClassSnapshot>>(
          MaterialPageRoute(
            builder: (context) => _FinanceClassesScreen(
              classes: _classes,
              entryCounts: _classEntryCounts,
            ),
          ),
        );

    if (!mounted || updatedClasses == null) {
      return;
    }

    setState(() {
      _classes = updatedClasses;
    });
    await _saveFinanceClasses();
  }

  int _bucketBalance(_FinanceBucket bucket) {
    return _entries
        .where((entry) => entry.bucket == bucket)
        .fold(0, (sum, entry) => sum + entry.bucketDelta);
  }

  double _bucketProgress(_FinanceBucket bucket) {
    final positiveTotal = _FinanceBucket.values.fold<int>(
      0,
      (sum, currentBucket) => sum + math.max(_bucketBalance(currentBucket), 0),
    );

    if (positiveTotal == 0) {
      return 0;
    }

    return math.max(_bucketBalance(bucket), 0) / positiveTotal;
  }

  bool _isCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  String _resolveClassName(_FinanceEntrySnapshot entry) {
    return _classesById[entry.classId]?.name ?? entry.title;
  }

  String _buildEntryNote(_FinanceEntrySnapshot entry) {
    final parts = <String>[];
    final trimmedNote = entry.note.trim();

    if (trimmedNote.isNotEmpty) {
      parts.add(trimmedNote);
    }

    parts.add(entry.bucket.title);
    parts.add(_formatFinanceDate(entry.occurredAt));
    return parts.join(' • ');
  }

  String _buildEntryAmount(_FinanceEntrySnapshot entry) {
    return switch (entry.type) {
      _FinanceEntryType.income => _formatRubles(entry.amount, signed: true),
      _FinanceEntryType.expense => _formatRubles(-entry.amount, signed: true),
      _FinanceEntryType.savings => _formatRubles(entry.amount),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const _LoadingTab(key: ValueKey('tab-finance-loading'));
    }

    return ListView(
      key: const ValueKey('finance-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IMPERIUM SUI',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Финансы',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontSize: 30,
                      height: 1.08,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3A211B), Color(0xFF150D0C)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.45),
                ),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _FinanceHeroCard(
          totalBalance: _totalBalance,
          reserveBalance: _reserveBalance,
          plannedSpend: _plannedSpend,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('add-finance-entry-button'),
                onPressed: _addEntry,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Новая операция'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              key: const ValueKey('open-finance-classes-button'),
              onPressed: _openFinanceClasses,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1.2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Классы'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _FinanceMetricCard(
                label: 'Доходы',
                value: _formatRubles(_monthlyIncome),
                detail:
                    '$_monthlyIncomeCount ${_pluralize(_monthlyIncomeCount, 'операция', 'операции', 'операций')}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FinanceMetricCard(
                label: 'Расходы',
                value: _formatRubles(_monthlyExpense),
                detail:
                    '$_monthlyExpenseCount ${_pluralize(_monthlyExpenseCount, 'операция', 'операции', 'операций')}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _FinanceSectionHeading(title: 'Контуры казны'),
        const SizedBox(height: 14),
        _FinancePocketTile(
          title: _FinanceBucket.flex.title,
          amount: _formatRubles(_bucketBalance(_FinanceBucket.flex)),
          note: _FinanceBucket.flex.note,
          progress: _bucketProgress(_FinanceBucket.flex),
        ),
        const SizedBox(height: 24),
        const _FinanceSectionHeading(title: 'Последние движения'),
        const SizedBox(height: 14),
        if (_entries.isEmpty)
          const _FinanceEmptyLedger()
        else
          for (final group in _monthlyGroups) ...[
            _FinanceMonthHeader(group: group),
            const SizedBox(height: 12),
            for (var index = 0; index < group.entries.length; index++) ...[
              _FinanceLedgerTile(
                title: _resolveClassName(group.entries[index]),
                amount: _buildEntryAmount(group.entries[index]),
                note: _buildEntryNote(group.entries[index]),
                tone: group.entries[index].tone,
              ),
              if (index != group.entries.length - 1) const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IMPERIAL WING',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox.shrink(),
          Text(
            title,
            style: theme.textTheme.displaySmall?.copyWith(color: Colors.white),
          ),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF3E8D4), Color(0xFFE9D7B7)],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1C120F).withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF4D2A21), Color(0xFF21120E)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(title, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  Text(
                    'Экран уже переключается. Дальше сюда можно спокойно '
                    'добавлять реальный функционал.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceHeroCard extends StatelessWidget {
  const _FinanceHeroCard({
    required this.totalBalance,
    required this.reserveBalance,
    required this.plannedSpend,
  });

  final int totalBalance;
  final int reserveBalance;
  final int plannedSpend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF231411), Color(0xFF58242B), Color(0xFF241513)],
          stops: [0, 0.62, 1],
        ),
        border: Border.all(color: gold.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF180F0D).withValues(alpha: 0.32),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'КАЗНА И ПОРЯДОК',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: gold,
                    letterSpacing: 2.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _formatRubles(totalBalance),
            style: theme.textTheme.displayMedium?.copyWith(
              color: Colors.white,
              fontSize: 42,
              height: 1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _FinanceLedgerPill(
                  label: 'Запас',
                  value: _formatRubles(reserveBalance),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FinanceLedgerPill(
                  label: 'Траты месяца',
                  value: _formatRubles(plannedSpend),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceLedgerPill extends StatelessWidget {
  const _FinanceLedgerPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceMetricCard extends StatelessWidget {
  const _FinanceMetricCard({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171011),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox.shrink(),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.64),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceSectionHeading extends StatelessWidget {
  const _FinanceSectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

class _FinancePocketTile extends StatelessWidget {
  const _FinancePocketTile({
    required this.title,
    required this.amount,
    required this.note,
    required this.progress,
  });

  final String title;
  final String amount;
  final String note;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161010),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                amount,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(gold),
            ),
          ),
        ],
      ),
    );
  }
}

enum _FinanceLedgerTone { positive, negative, savings }

class _FinanceLedgerTile extends StatelessWidget {
  const _FinanceLedgerTile({
    required this.title,
    required this.amount,
    required this.note,
    required this.tone,
  });

  final String title;
  final String amount;
  final String note;
  final _FinanceLedgerTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = switch (tone) {
      _FinanceLedgerTone.positive => const Color(0xFFD5B277),
      _FinanceLedgerTone.negative => const Color(0xFFC6766A),
      _FinanceLedgerTone.savings => const Color(0xFF78A87B),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151010),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(switch (tone) {
              _FinanceLedgerTone.positive => Icons.south_west_rounded,
              _FinanceLedgerTone.negative => Icons.north_east_rounded,
              _FinanceLedgerTone.savings => Icons.savings_rounded,
            }, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.66),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: theme.textTheme.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceEmptyLedger extends StatelessWidget {
  const _FinanceEmptyLedger();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151010),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        'Пока пусто. Добавь первую операцию, и здесь появится живая история движения денег.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class _FinanceMonthHeader extends StatelessWidget {
  const _FinanceMonthHeader({required this.group});

  final _FinanceMonthGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      key: ValueKey('finance-month-${group.year}-${group.month}'),
      children: [
        Expanded(
          child: Text(
            _formatFinanceMonth(group.year, group.month),
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${group.entries.length} ${_pluralize(group.entries.length, 'операция', 'операции', 'операций')}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }
}

class _FinanceClassesScreen extends StatefulWidget {
  const _FinanceClassesScreen({
    required this.classes,
    required this.entryCounts,
  });

  final List<_FinanceClassSnapshot> classes;
  final Map<String, int> entryCounts;

  @override
  State<_FinanceClassesScreen> createState() => _FinanceClassesScreenState();
}

class _FinanceClassesScreenState extends State<_FinanceClassesScreen> {
  late List<_FinanceClassSnapshot> _classes;

  @override
  void initState() {
    super.initState();
    _classes = [...widget.classes];
  }

  List<_FinanceClassSnapshot> _classesForType(_FinanceEntryType type) {
    return _classes
        .where((financeClass) => financeClass.type == type)
        .toList(growable: false);
  }

  Future<void> _createClass(_FinanceEntryType type) async {
    final createdClass = await showModalBottomSheet<_FinanceClassSnapshot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FinanceClassComposerSheet(type: type),
    );

    if (!mounted || createdClass == null) {
      return;
    }

    final duplicateExists = _classes.any(
      (financeClass) =>
          financeClass.type == type &&
          financeClass.name.trim().toLowerCase() ==
              createdClass.name.trim().toLowerCase(),
    );

    if (duplicateExists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Такой класс уже есть.')));
      return;
    }

    setState(() {
      _classes = [..._classes, createdClass];
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('Класс "${createdClass.name}" добавлен.')),
      );
  }

  Future<void> _editClass(_FinanceClassSnapshot financeClass) async {
    final updatedClass = await showModalBottomSheet<_FinanceClassSnapshot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FinanceClassComposerSheet(
        type: financeClass.type,
        existingClass: financeClass,
      ),
    );

    if (!mounted || updatedClass == null) {
      return;
    }

    final duplicateExists = _classes.any(
      (item) =>
          item.id != financeClass.id &&
          item.type == financeClass.type &&
          item.name.trim().toLowerCase() ==
              updatedClass.name.trim().toLowerCase(),
    );

    if (duplicateExists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Такой класс уже есть.')));
      return;
    }

    setState(() {
      final index = _classes.indexWhere((item) => item.id == financeClass.id);
      if (index != -1) {
        _classes[index] = updatedClass;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0707),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(_classes),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Классы операций'),
        backgroundColor: const Color(0xFF0A0707),
        actions: [
          TextButton(
            key: const ValueKey('finance-classes-done-button'),
            onPressed: () => Navigator.of(context).pop(_classes),
            child: const Text('Р“РѕС‚РѕРІРѕ'),
          ),
        ],
      ),
      body: _ScreenFrame(
        child: ListView(
          key: const ValueKey('finance-classes-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
          children: [
            _FinanceClassesSection(
              title: 'Доходы',
              classes: _classesForType(_FinanceEntryType.income),
              counts: widget.entryCounts,
              addButtonKey: const ValueKey('add-finance-class-income-button'),
              onAdd: () => _createClass(_FinanceEntryType.income),
              onEdit: _editClass,
            ),
            const SizedBox(height: 14),
            _FinanceClassesSection(
              title: 'Накопления',
              classes: _classesForType(_FinanceEntryType.savings),
              counts: widget.entryCounts,
              addButtonKey: const ValueKey('add-finance-class-savings-button'),
              onAdd: () => _createClass(_FinanceEntryType.savings),
              onEdit: _editClass,
            ),
            const SizedBox(height: 14),
            _FinanceClassesSection(
              title: 'Траты',
              classes: _classesForType(_FinanceEntryType.expense),
              counts: widget.entryCounts,
              addButtonKey: const ValueKey('add-finance-class-expense-button'),
              onAdd: () => _createClass(_FinanceEntryType.expense),
              onEdit: _editClass,
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceClassesSection extends StatelessWidget {
  const _FinanceClassesSection({
    required this.title,
    required this.classes,
    required this.counts,
    required this.addButtonKey,
    required this.onAdd,
    required this.onEdit,
  });

  final String title;
  final List<_FinanceClassSnapshot> classes;
  final Map<String, int> counts;
  final Key addButtonKey;
  final VoidCallback onAdd;
  final ValueChanged<_FinanceClassSnapshot> onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151010),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              TextButton.icon(
                key: addButtonKey,
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Новый класс'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < classes.length; index++) ...[
            ListTile(
              key: ValueKey('finance-class-tile-${classes[index].id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                classes[index].name,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
              ),
              subtitle: Text(
                '${counts[classes[index].id] ?? 0} ${_pluralize(counts[classes[index].id] ?? 0, 'операция', 'операции', 'операций')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.66),
                ),
              ),
              trailing: IconButton(
                key: ValueKey('edit-finance-class-${classes[index].id}'),
                onPressed: () => onEdit(classes[index]),
                icon: const Icon(Icons.edit_rounded),
              ),
              onTap: () => onEdit(classes[index]),
            ),
            if (index != classes.length - 1)
              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          ],
        ],
      ),
    );
  }
}

enum _FinanceEntryType { income, savings, expense }

extension on _FinanceEntryType {
  _FinanceLedgerTone get tone => switch (this) {
    _FinanceEntryType.income => _FinanceLedgerTone.positive,
    _FinanceEntryType.savings => _FinanceLedgerTone.savings,
    _FinanceEntryType.expense => _FinanceLedgerTone.negative,
  };
}

enum _FinanceBucket { budget, reserve, flex }

extension on _FinanceBucket {
  String get title => switch (this) {
    _FinanceBucket.budget => 'Основной бюджет',
    _FinanceBucket.reserve => 'Резерв',
    _FinanceBucket.flex => 'Свободные средства',
  };

  String get note => switch (this) {
    _FinanceBucket.budget => 'Повседневные траты и обязательные платежи',
    _FinanceBucket.reserve => 'Подушка, накопления и запас прочности',
    _FinanceBucket.flex => 'Поездки, покупки и всё гибкое по желанию',
  };
}

class _FinanceClassSnapshot {
  const _FinanceClassSnapshot({
    required this.id,
    required this.name,
    required this.type,
  });

  final String id;
  final String name;
  final _FinanceEntryType type;

  Map<String, Object?> toMap() {
    return {'id': id, 'name': name, 'type': type.name};
  }

  factory _FinanceClassSnapshot.fromMap(Map<String, Object?> map) {
    return _FinanceClassSnapshot(
      id: _readString(
        map['id'],
        fallback: 'finance-class-${DateTime.now().microsecondsSinceEpoch}',
      ),
      name: _readString(map['name']),
      type: _financeEntryTypeFromName(
        _readString(map['type'], fallback: _FinanceEntryType.expense.name),
      ),
    );
  }
}

class _FinanceMonthGroup {
  const _FinanceMonthGroup({
    required this.year,
    required this.month,
    required this.entries,
  });

  final int year;
  final int month;
  final List<_FinanceEntrySnapshot> entries;
}

const _defaultFinanceClasses = [
  _FinanceClassSnapshot(
    id: 'income-main',
    name: 'Основной доход',
    type: _FinanceEntryType.income,
  ),
  _FinanceClassSnapshot(
    id: 'income-freelance',
    name: 'Фриланс',
    type: _FinanceEntryType.income,
  ),
  _FinanceClassSnapshot(
    id: 'income-interest',
    name: 'Проценты',
    type: _FinanceEntryType.income,
  ),
  _FinanceClassSnapshot(
    id: 'savings-cushion',
    name: 'Подушка',
    type: _FinanceEntryType.savings,
  ),
  _FinanceClassSnapshot(
    id: 'savings-investment',
    name: 'Инвестиции',
    type: _FinanceEntryType.savings,
  ),
  _FinanceClassSnapshot(
    id: 'savings-goal',
    name: 'Цель',
    type: _FinanceEntryType.savings,
  ),
  _FinanceClassSnapshot(
    id: 'expense-food',
    name: 'Еда',
    type: _FinanceEntryType.expense,
  ),
  _FinanceClassSnapshot(
    id: 'expense-housing',
    name: 'Жильё',
    type: _FinanceEntryType.expense,
  ),
  _FinanceClassSnapshot(
    id: 'expense-fun',
    name: 'Развлечения',
    type: _FinanceEntryType.expense,
  ),
  _FinanceClassSnapshot(
    id: 'expense-transport',
    name: 'Транспорт',
    type: _FinanceEntryType.expense,
  ),
];

class _FinanceEntrySnapshot {
  const _FinanceEntrySnapshot({
    required this.id,
    required this.title,
    required this.classId,
    required this.note,
    required this.type,
    required this.bucket,
    required this.amount,
    required this.occurredAt,
  });

  final String id;
  final String title;
  final String classId;
  final String note;
  final _FinanceEntryType type;
  final _FinanceBucket bucket;
  final int amount;
  final DateTime occurredAt;

  int get signedAmount => switch (type) {
    _FinanceEntryType.income => amount,
    _FinanceEntryType.savings => 0,
    _FinanceEntryType.expense => -amount,
  };

  int get bucketDelta => switch (type) {
    _FinanceEntryType.income => amount,
    _FinanceEntryType.savings => amount,
    _FinanceEntryType.expense => -amount,
  };

  _FinanceLedgerTone get tone => type.tone;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'classId': classId,
      'className': title,
      'note': note,
      'type': type.name,
      'bucket': bucket.name,
      'amount': amount,
      'occurredAt': occurredAt.toIso8601String(),
    };
  }

  factory _FinanceEntrySnapshot.fromMap(Map<String, Object?> map) {
    final parsedDate = DateTime.tryParse(_readString(map['occurredAt']));

    return _FinanceEntrySnapshot(
      id: _readString(
        map['id'],
        fallback: 'finance-${DateTime.now().microsecondsSinceEpoch}',
      ),
      title: _readString(
        map['className'],
        fallback: _readString(map['title'], fallback: 'Операция'),
      ),
      classId: _readString(
        map['classId'],
        fallback: _readString(map['title'], fallback: 'finance-class-legacy'),
      ),
      note: _readString(map['note']),
      type: _financeEntryTypeFromName(
        _readString(map['type'], fallback: _FinanceEntryType.expense.name),
      ),
      bucket: _financeBucketFromName(
        _readString(map['bucket'], fallback: _FinanceBucket.budget.name),
      ),
      amount: math.max(_readInt(map['amount']), 0),
      occurredAt: parsedDate ?? DateTime.now(),
    );
  }
}

class _FinanceEntryComposerSheet extends StatefulWidget {
  const _FinanceEntryComposerSheet({required this.classes});

  final List<_FinanceClassSnapshot> classes;

  @override
  State<_FinanceEntryComposerSheet> createState() =>
      _FinanceEntryComposerSheetState();
}

class _FinanceEntryComposerSheetState
    extends State<_FinanceEntryComposerSheet> {
  late final TextEditingController _noteController;
  late final TextEditingController _amountController;
  late _FinanceEntryType _selectedType;
  late _FinanceBucket _selectedBucket;
  late String _selectedClassId;

  List<_FinanceClassSnapshot> get _classesForSelectedType => widget.classes
      .where((financeClass) => financeClass.type == _selectedType)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _amountController = TextEditingController();
    _selectedType = _FinanceEntryType.expense;
    _selectedBucket = _FinanceBucket.budget;
    _selectedClassId = _initialClassId(_selectedType);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String _initialClassId(_FinanceEntryType type) {
    final financeClass = widget.classes
        .cast<_FinanceClassSnapshot?>()
        .firstWhere((item) => item?.type == type, orElse: () => null);

    return financeClass?.id ?? '';
  }

  void _updateType(_FinanceEntryType type) {
    setState(() {
      _selectedType = type;
      _selectedClassId = _initialClassId(type);
      if (type == _FinanceEntryType.savings) {
        _selectedBucket = _FinanceBucket.reserve;
      }
    });
  }

  void _save() {
    final amount = int.tryParse(_amountController.text.trim());
    final selectedClass = widget.classes
        .cast<_FinanceClassSnapshot?>()
        .firstWhere(
          (financeClass) => financeClass?.id == _selectedClassId,
          orElse: () => null,
        );

    if (selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выбери класс операции.')),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Укажи сумму больше нуля.')));
      return;
    }

    Navigator.of(context).pop(
      _FinanceEntrySnapshot(
        id: 'finance-${DateTime.now().microsecondsSinceEpoch}',
        title: selectedClass.name,
        classId: selectedClass.id,
        note: _noteController.text.trim(),
        type: _selectedType,
        bucket: _selectedBucket,
        amount: amount,
        occurredAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          top: 16,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF171010),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Новая операция',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    key: const ValueKey('finance-entry-type-income'),
                    label: const Text('Доход'),
                    selected: _selectedType == _FinanceEntryType.income,
                    onSelected: (_) => _updateType(_FinanceEntryType.income),
                  ),
                  ChoiceChip(
                    key: const ValueKey('finance-entry-type-savings'),
                    label: const Text('Накопления'),
                    selected: _selectedType == _FinanceEntryType.savings,
                    onSelected: (_) => _updateType(_FinanceEntryType.savings),
                  ),
                  ChoiceChip(
                    key: const ValueKey('finance-entry-type-expense'),
                    label: const Text('Трата'),
                    selected: _selectedType == _FinanceEntryType.expense,
                    onSelected: (_) => _updateType(_FinanceEntryType.expense),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Класс операции',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _classesForSelectedType
                    .map(
                      (financeClass) => ChoiceChip(
                        key: ValueKey('finance-entry-class-${financeClass.id}'),
                        label: Text(financeClass.name),
                        selected: _selectedClassId == financeClass.id,
                        onSelected: (_) {
                          setState(() {
                            _selectedClassId = financeClass.id;
                          });
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 14),
              _EditorField(
                key: const ValueKey('finance-entry-amount'),
                controller: _amountController,
                label: 'Сумма в рублях',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<_FinanceBucket>(
                key: const ValueKey('finance-entry-bucket'),
                initialValue: _selectedBucket,
                isExpanded: true,
                dropdownColor: const Color(0xFF221614),
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Контур',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                items: _FinanceBucket.values
                    .map(
                      (bucket) => DropdownMenuItem<_FinanceBucket>(
                        value: bucket,
                        child: Text(bucket.title),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (bucket) {
                  if (bucket == null) {
                    return;
                  }

                  setState(() {
                    _selectedBucket = bucket;
                  });
                },
              ),
              const SizedBox(height: 14),
              _EditorField(
                key: const ValueKey('finance-entry-note'),
                controller: _noteController,
                label: 'Р—Р°РјРµС‚РєР°',
                maxLines: 3,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('finance-entry-save'),
                      onPressed: _save,
                      child: const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceClassComposerSheet extends StatefulWidget {
  const _FinanceClassComposerSheet({required this.type, this.existingClass});

  final _FinanceEntryType type;
  final _FinanceClassSnapshot? existingClass;

  @override
  State<_FinanceClassComposerSheet> createState() =>
      _FinanceClassComposerSheetState();
}

class _FinanceClassComposerSheetState
    extends State<_FinanceClassComposerSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingClass?.name ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Назови новый класс.')));
      return;
    }

    Navigator.of(context).pop(
      _FinanceClassSnapshot(
        id:
            widget.existingClass?.id ??
            'finance-class-${widget.type.name}-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        type: widget.type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          top: 16,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF171010),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                switch (widget.type) {
                  _FinanceEntryType.income =>
                    widget.existingClass == null
                        ? 'Новый класс дохода'
                        : 'Редактировать класс дохода',
                  _FinanceEntryType.savings =>
                    widget.existingClass == null
                        ? 'Новый класс накоплений'
                        : 'Редактировать класс накоплений',
                  _FinanceEntryType.expense =>
                    widget.existingClass == null
                        ? 'Новый класс траты'
                        : 'Редактировать класс траты',
                },
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              _EditorField(
                key: ValueKey('finance-class-name-${widget.type.name}'),
                controller: _nameController,
                label: 'Название класса',
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: ValueKey('finance-class-save-${widget.type.name}'),
                      onPressed: _save,
                      child: Text(
                        widget.existingClass == null ? 'Сохранить' : 'Обновить',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

_FinanceEntryType _financeEntryTypeFromName(String name) {
  for (final type in _FinanceEntryType.values) {
    if (type.name == name) {
      return type;
    }
  }

  return _FinanceEntryType.expense;
}

_FinanceBucket _financeBucketFromName(String name) {
  for (final bucket in _FinanceBucket.values) {
    if (bucket.name == name) {
      return bucket;
    }
  }

  return _FinanceBucket.budget;
}

String _formatRubles(int amount, {bool signed = false}) {
  final absolute = _formatThousands(amount.abs());
  final prefix = switch ((signed, amount.isNegative, amount > 0)) {
    (true, true, _) => '-',
    (true, false, true) => '+',
    (_, true, _) => '-',
    _ => '',
  };

  return '$prefix$absolute ₽';
}

String _formatThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    buffer.write(digits[index]);
    final remaining = digits.length - index - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write(' ');
    }
  }

  return buffer.toString();
}

String _formatFinanceDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);

  final dayLabel = switch (target.difference(today).inDays) {
    0 => 'Сегодня',
    -1 => 'Вчера',
    _ => '${date.day} ${_monthName(date.month)}',
  };

  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$dayLabel, $hour:$minute';
}

String _formatFinanceMonth(int year, int month) {
  final monthLabel = _monthName(month);
  final capitalizedMonth =
      monthLabel[0].toUpperCase() + monthLabel.substring(1);
  return '$capitalizedMonth $year';
}

String _monthName(int month) {
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  final safeIndex = month < 1
      ? 0
      : month > months.length
      ? months.length - 1
      : month - 1;

  return months[safeIndex];
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.habits,
    required this.completedHabitsCount,
    required this.totalHabitsCount,
  });

  final List<_HabitSnapshot> habits;
  final int completedHabitsCount;
  final int totalHabitsCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF251511), Color(0xFF562229), Color(0xFF241514)],
          stops: [0, 0.62, 1],
        ),
        border: Border.all(color: gold.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF180F0D).withValues(alpha: 0.34),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: gold.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'THRONE OF DISCIPLINE',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: gold,
                    letterSpacing: 2.8,
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF714B27), Color(0xFF22120E)],
                  ),
                  border: Border.all(color: gold.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.shield_moon_rounded, size: 20, color: gold),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _HeroProgressBlock(
            habits: habits,
            completedHabitsCount: completedHabitsCount,
            totalHabitsCount: totalHabitsCount,
          ),
        ],
      ),
    );
  }
}

class _HeroProgressBlock extends StatelessWidget {
  const _HeroProgressBlock({
    required this.habits,
    required this.completedHabitsCount,
    required this.totalHabitsCount,
  });

  final List<_HabitSnapshot> habits;
  final int completedHabitsCount;
  final int totalHabitsCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight = constraints.maxWidth < 340;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$completedHabitsCount',
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontSize: isTight ? 40 : 44,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(
                              text: '/$totalHabitsCount',
                              style:
                                  (isTight
                                          ? theme.textTheme.titleLarge
                                          : theme.textTheme.headlineSmall)
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.74,
                                        ),
                                      ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: isTight ? 6 : 8),
                        child: Text(
                          'ритуалов выполнено',
                          maxLines: 2,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.72),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: List.generate(habits.length, (index) {
                final habit = habits[index];

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == habits.length - 1 ? 0 : 8,
                    ),
                    child: _HabitLedgerSegment(
                      progress: habit.progress,
                      accent: habit.tone.accent,
                      gold: gold,
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _HabitLedgerSegment extends StatelessWidget {
  const _HabitLedgerSegment({
    required this.progress,
    required this.accent,
    required this.gold,
  });

  final double progress;
  final Color accent;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final hasProgress = clampedProgress > 0;

    return Container(
      height: 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: hasProgress
              ? accent.withValues(alpha: 0.26)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      accent.withValues(alpha: 0.12),
                      gold.withValues(alpha: 0.04),
                    ],
                  ),
                ),
              ),
            ),
            if (hasProgress)
              FractionallySizedBox(
                widthFactor: clampedProgress,
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(accent, gold, 0.28)!.withValues(alpha: 0.98),
                        accent.withValues(alpha: 0.84),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HabitCard extends StatefulWidget {
  const _HabitCard({
    required this.habit,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onDelete,
  });

  final _HabitSnapshot habit;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<_HabitCard> {
  static const Map<_HabitQuickAction, Offset> _actionOffsets = {
    _HabitQuickAction.delete: Offset(-96, 0),
    _HabitQuickAction.edit: Offset(96, 0),
  };

  OverlayEntry? _menuEntry;
  Offset? _menuCenter;
  _HabitQuickAction? _highlightedAction;

  @override
  void dispose() {
    _removeMenu();
    super.dispose();
  }

  void _showMenu(Offset globalPosition) {
    _removeMenu();
    _menuCenter = globalPosition;
    _highlightedAction = null;

    _menuEntry = OverlayEntry(
      builder: (context) => _RadialHabitMenuOverlay(
        center: _menuCenter!,
        highlightedAction: _highlightedAction,
        actionOffsets: _actionOffsets,
      ),
    );

    Overlay.of(context).insert(_menuEntry!);
  }

  void _updateMenu(Offset globalPosition) {
    if (_menuCenter == null || _menuEntry == null) {
      return;
    }

    _highlightedAction = _resolveAction(globalPosition - _menuCenter!);
    _menuEntry?.markNeedsBuild();
  }

  void _completeMenu() {
    final action = _highlightedAction;
    _removeMenu();

    switch (action) {
      case _HabitQuickAction.edit:
        widget.onEdit();
      case _HabitQuickAction.delete:
        widget.onDelete();
      case null:
        return;
    }
  }

  void _removeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
    _menuCenter = null;
    _highlightedAction = null;
  }

  _HabitQuickAction? _resolveAction(Offset delta) {
    if (delta.distance < 28) {
      return null;
    }

    _HabitQuickAction? selectedAction;
    var closestDistance = double.infinity;

    for (final entry in _actionOffsets.entries) {
      final distance = (delta - entry.value).distance;
      if (distance < closestDistance) {
        closestDistance = distance;
        selectedAction = entry.key;
      }
    }

    return closestDistance <= 70 ? selectedAction : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.habit.tone.accent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Dismissible(
        key: ValueKey('habit-card-${widget.habit.id}'),
        direction: DismissDirection.horizontal,
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.24,
          DismissDirection.endToStart: 0.24,
        },
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            widget.onIncrement();
          } else if (direction == DismissDirection.endToStart) {
            widget.onDecrement();
          }

          return false;
        },
        background: _SwipeActionBackground(
          alignment: Alignment.centerLeft,
          icon: Icons.add_task_rounded,
          label: widget.habit.canIncrement
              ? 'Выполнено +1'
              : 'Лимит на сегодня',
          colors: const [Color(0xFF8C6A3B), Color(0xFF3D2717)],
        ),
        secondaryBackground: _SwipeActionBackground(
          alignment: Alignment.centerRight,
          icon: Icons.undo_rounded,
          label: widget.habit.canDecrement
              ? 'Отменить шаг'
              : 'Пока нечего отменять',
          colors: const [Color(0xFF4A1E22), Color(0xFF1A0F10)],
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (details) => _showMenu(details.globalPosition),
          onLongPressMoveUpdate: (details) =>
              _updateMenu(details.globalPosition),
          onLongPressEnd: (_) => _completeMenu(),
          onLongPressCancel: _removeMenu,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [widget.habit.tone.surface, const Color(0xFFF8EFDE)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: accent.withValues(alpha: 0.24)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF180F0D).withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(accent, const Color(0xFF241513), 0.2)!,
                            const Color(0xFF241513),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Icon(widget.habit.icon, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                widget.habit.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 20,
                                ),
                              ),
                              _CountBadge(habit: widget.habit),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.habit.description,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.76,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetaChip(
                      icon: Icons.schedule_rounded,
                      label: widget.habit.timeLabel,
                    ),
                    _MetaChip(
                      icon: Icons.local_fire_department_rounded,
                      label:
                          '${widget.habit.streakDays} ${_pluralize(widget.habit.streakDays, 'день', 'дня', 'дней')}',
                    ),
                    _MetaChip(
                      icon: Icons.timer_outlined,
                      label:
                          '${widget.habit.focusMinutes} ${_pluralize(widget.habit.focusMinutes, 'минута', 'минуты', 'минут')}',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Триггер: ${widget.habit.cue}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: accent.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _buildSwipeHint(widget.habit),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.78,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      Icons.swipe_rounded,
                      size: 20,
                      color: accent.withValues(alpha: 0.78),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _HabitQuickAction { edit, delete }

class _RadialHabitMenuOverlay extends StatelessWidget {
  const _RadialHabitMenuOverlay({
    required this.center,
    required this.highlightedAction,
    required this.actionOffsets,
  });

  final Offset center;
  final _HabitQuickAction? highlightedAction;
  final Map<_HabitQuickAction, Offset> actionOffsets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.08)),
          ),
          Positioned(
            left: center.dx - 34,
            top: center.dy - 34,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2A1713), Color(0xFF120B0A)],
                ),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.26),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.pan_tool_alt_rounded,
                size: 28,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          for (final entry in actionOffsets.entries)
            Positioned(
              left: center.dx + entry.value.dx - 36,
              top: center.dy + entry.value.dy - 36,
              child: _RadialHabitActionBubble(
                action: entry.key,
                isHighlighted: highlightedAction == entry.key,
              ),
            ),
        ],
      ),
    );
  }
}

class _RadialHabitActionBubble extends StatelessWidget {
  const _RadialHabitActionBubble({
    required this.action,
    required this.isHighlighted,
  });

  final _HabitQuickAction action;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDelete = action == _HabitQuickAction.delete;
    final colors = isDelete
        ? const [Color(0xFF7B3137), Color(0xFF3A1618)]
        : const [Color(0xFFD5B277), Color(0xFF9C733D)];
    final foreground = isDelete ? Colors.white : const Color(0xFF1B120F);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: isHighlighted ? 96 : 90,
      height: isHighlighted ? 96 : 90,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(
            alpha: isHighlighted ? 0.38 : 0.18,
          ),
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isHighlighted ? 0.3 : 0.18),
            blurRadius: isHighlighted ? 20 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isDelete ? Icons.delete_outline_rounded : Icons.edit_rounded,
            size: isHighlighted ? 22 : 20,
            color: foreground,
          ),
          const SizedBox(height: 4),
          Text(
            isDelete ? 'Удалить' : 'Редактировать',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.colors,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final isLeftAligned = alignment == Alignment.centerLeft;

    return Container(
      padding: EdgeInsets.only(
        left: isLeftAligned ? 20 : 0,
        right: isLeftAligned ? 0 : 20,
      ),
      alignment: alignment,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isLeftAligned ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeftAligned ? Alignment.centerRight : Alignment.centerLeft,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isLeftAligned
            ? [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]
            : [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, color: Colors.white),
              ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.habit});

  final _HabitSnapshot habit;

  @override
  Widget build(BuildContext context) {
    final isComplete = habit.isCompleted;
    final isStarted = habit.completedCount > 0;
    final colors = isComplete
        ? const [Color(0xFFD3B176), Color(0xFF9E7640)]
        : isStarted
        ? const [Color(0xFFB57F43), Color(0xFF5B3417)]
        : const [Color(0xFF7B3137), Color(0xFF4B1B1E)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: habit.tone.accent.withValues(alpha: isComplete ? 0.24 : 0.16),
        ),
      ),
      child: Text(
        '${habit.completedCount}/${habit.targetCount}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isComplete ? const Color(0xFF1B120F) : Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.secondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddHabitCard extends StatelessWidget {
  const _AddHabitCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const ValueKey('add-habit-button'),
        onPressed: onAdd,
        icon: const _AddHabitIcon(),
        label: const _AddHabitText(),
      ),
    );
  }
}

class _AddHabitIcon extends StatelessWidget {
  const _AddHabitIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.add_rounded);
  }
}

class _AddHabitText extends StatelessWidget {
  const _AddHabitText();

  @override
  Widget build(BuildContext context) {
    return const Text('Новая привычка');
  }
}

class _HabitEditorSheet extends StatefulWidget {
  const _HabitEditorSheet({required this.habit, required this.isCreating});

  final _HabitSnapshot habit;
  final bool isCreating;

  @override
  State<_HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends State<_HabitEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _cueController;
  late final TextEditingController _timeController;
  late final TextEditingController _targetController;
  late final TextEditingController _focusController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.isCreating ? '' : widget.habit.title,
    );
    _descriptionController = TextEditingController(
      text: widget.isCreating ? '' : widget.habit.description,
    );
    _cueController = TextEditingController(
      text: widget.isCreating ? '' : widget.habit.cue,
    );
    _timeController = TextEditingController(
      text: widget.isCreating ? '' : widget.habit.timeLabel,
    );
    _targetController = TextEditingController(
      text: widget.isCreating ? '' : widget.habit.targetCount.toString(),
    );
    _focusController = TextEditingController(
      text: widget.isCreating ? '' : widget.habit.focusMinutes.toString(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cueController.dispose();
    _timeController.dispose();
    _targetController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  void _save() {
    final targetCount = math.max(
      int.tryParse(_targetController.text.trim()) ?? widget.habit.targetCount,
      1,
    );
    final focusMinutes = math.max(
      int.tryParse(_focusController.text.trim()) ?? widget.habit.focusMinutes,
      1,
    );
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final cue = _cueController.text.trim();
    final timeLabel = _timeController.text.trim();

    if (widget.isCreating && title.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Дай привычке короткое название.')),
        );
      return;
    }

    Navigator.of(context).pop(
      widget.habit.copyWith(
        title: title.isEmpty ? widget.habit.title : title,
        description: description.isEmpty
            ? widget.habit.description
            : description,
        cue: cue.isEmpty ? widget.habit.cue : cue,
        timeLabel: timeLabel.isEmpty ? widget.habit.timeLabel : timeLabel,
        targetCount: targetCount,
        focusMinutes: focusMinutes,
        completedCount: math.min(widget.habit.completedCount, targetCount),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = widget.isCreating
        ? 'Новая привычка'
        : 'Редактировать привычку';
    final subtitle = widget.isCreating
        ? 'Задай ритм, цель и простой триггер. Остальное потом подкрутим.'
        : 'Измени ритм, цель и описание без выхода с экрана.';
    final submitLabel = widget.isCreating ? 'Создать' : 'Сохранить';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Material(
        color: const Color(0xFF140D0C),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 18),
                _EditorField(
                  key: const ValueKey('habit-editor-title'),
                  controller: _titleController,
                  label: 'Название',
                ),
                const SizedBox(height: 12),
                _EditorField(
                  key: const ValueKey('habit-editor-description'),
                  controller: _descriptionController,
                  label: 'Описание',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _EditorField(
                  key: const ValueKey('habit-editor-cue'),
                  controller: _cueController,
                  label: 'Триггер',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _EditorField(
                        key: const ValueKey('habit-editor-time'),
                        controller: _timeController,
                        label: 'Время',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _EditorField(
                        key: const ValueKey('habit-editor-target'),
                        controller: _targetController,
                        label: 'Цель/день',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _EditorField(
                  key: const ValueKey('habit-editor-focus'),
                  controller: _focusController,
                  label: 'Минут на шаг',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.22,
                            ),
                          ),
                        ),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('habit-editor-save'),
                        onPressed: _save,
                        child: Text(submitLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _HabitSnapshot {
  const _HabitSnapshot({
    required this.id,
    required this.title,
    required this.description,
    required this.cue,
    required this.timeLabel,
    required this.streakDays,
    required this.focusMinutes,
    required this.icon,
    required this.tone,
    required this.targetCount,
    required this.completedCount,
  });

  final String id;
  final String title;
  final String description;
  final String cue;
  final String timeLabel;
  final int streakDays;
  final int focusMinutes;
  final IconData icon;
  final _HabitTone tone;
  final int targetCount;
  final int completedCount;

  bool get isCompleted => completedCount >= targetCount;
  bool get canIncrement => completedCount < targetCount;
  bool get canDecrement => completedCount > 0;
  int get remainingCount => math.max(targetCount - completedCount, 0);
  double get progress => targetCount == 0 ? 0 : completedCount / targetCount;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'cue': cue,
      'timeLabel': timeLabel,
      'streakDays': streakDays,
      'focusMinutes': focusMinutes,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
      'iconMatchTextDirection': icon.matchTextDirection,
      'tone': tone.name,
      'targetCount': targetCount,
      'completedCount': completedCount,
    };
  }

  factory _HabitSnapshot.fromMap(Map<String, Object?> map) {
    final targetCount = _readInt(map['targetCount'], fallback: 1);

    return _HabitSnapshot(
      id: _readString(
        map['id'],
        fallback: 'habit-${DateTime.now().microsecondsSinceEpoch}',
      ),
      title: _readString(map['title']),
      description: _readString(map['description']),
      cue: _readString(map['cue']),
      timeLabel: _readString(map['timeLabel']),
      streakDays: _readInt(map['streakDays']),
      focusMinutes: _readInt(map['focusMinutes'], fallback: 10),
      icon: IconData(
        _readInt(map['iconCodePoint'], fallback: Icons.flag_rounded.codePoint),
        fontFamily: _readString(
          map['iconFontFamily'],
          fallback: 'MaterialIcons',
        ),
        fontPackage: _nullableString(map['iconFontPackage']),
        matchTextDirection: _readBool(map['iconMatchTextDirection']),
      ),
      tone: _habitToneFromName(
        _readString(map['tone'], fallback: _HabitTone.mint.name),
      ),
      targetCount: math.max(targetCount, 1),
      completedCount: _readInt(
        map['completedCount'],
      ).clamp(0, targetCount).toInt(),
    );
  }

  _HabitSnapshot copyWith({
    String? title,
    String? description,
    String? cue,
    String? timeLabel,
    int? focusMinutes,
    int? targetCount,
    int? completedCount,
  }) {
    return _HabitSnapshot(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      cue: cue ?? this.cue,
      timeLabel: timeLabel ?? this.timeLabel,
      streakDays: streakDays,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      icon: icon,
      tone: tone,
      targetCount: targetCount ?? this.targetCount,
      completedCount: completedCount ?? this.completedCount,
    );
  }
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

bool _readBool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    if (value == 'true') {
      return true;
    }
    if (value == 'false') {
      return false;
    }
  }
  return fallback;
}

String _readString(Object? value, {String fallback = ''}) {
  if (value is String) {
    return value;
  }
  return fallback;
}

String? _nullableString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

_HabitTone _habitToneFromName(String name) {
  for (final tone in _HabitTone.values) {
    if (tone.name == name) {
      return tone;
    }
  }

  return _HabitTone.mint;
}

enum _HabitTone { mint, amber, coral, denim }

extension on _HabitTone {
  Color get accent {
    return switch (this) {
      _HabitTone.mint => const Color(0xFF5E6B44),
      _HabitTone.amber => const Color(0xFFBE8F49),
      _HabitTone.coral => const Color(0xFF8D4A49),
      _HabitTone.denim => const Color(0xFF4D5C70),
    };
  }

  Color get surface {
    return switch (this) {
      _HabitTone.mint => const Color(0xFFF0EAD9),
      _HabitTone.amber => const Color(0xFFF6E5C5),
      _HabitTone.coral => const Color(0xFFF1DDD8),
      _HabitTone.denim => const Color(0xFFE7E2DA),
    };
  }
}

const _draftHabitIcons = [
  Icons.flag_rounded,
  Icons.local_fire_department_rounded,
  Icons.bedtime_rounded,
  Icons.auto_awesome_rounded,
];

// ignore: unused_element
const _demoHabits = [
  _HabitSnapshot(
    id: 'stretch',
    title: 'Утренняя зарядка',
    description: 'Короткий запуск тела перед первым экраном и сообщениями.',
    cue: 'после стакана воды',
    timeLabel: '07:30',
    streakDays: 12,
    focusMinutes: 8,
    icon: Icons.self_improvement_rounded,
    tone: _HabitTone.mint,
    targetCount: 1,
    completedCount: 1,
  ),
  _HabitSnapshot(
    id: 'focus',
    title: 'Фокус-спринт',
    description: 'Один плотный блок без уведомлений и переключений.',
    cue: 'сразу после утреннего плана',
    timeLabel: '09:00',
    streakDays: 9,
    focusMinutes: 45,
    icon: Icons.bolt_rounded,
    tone: _HabitTone.denim,
    targetCount: 3,
    completedCount: 1,
  ),
  _HabitSnapshot(
    id: 'water',
    title: 'Вода и пауза',
    description: 'Небольшой reset для головы после встреч и задач.',
    cue: 'после каждого созвона',
    timeLabel: '14:00',
    streakDays: 6,
    focusMinutes: 5,
    icon: Icons.local_drink_rounded,
    tone: _HabitTone.amber,
    targetCount: 3,
    completedCount: 3,
  ),
  _HabitSnapshot(
    id: 'review',
    title: 'Вечерний обзор',
    description: 'Три строки о дне, чтобы не уносить всё в сон.',
    cue: 'перед тем как убрать телефон',
    timeLabel: '21:30',
    streakDays: 16,
    focusMinutes: 10,
    icon: Icons.nightlight_round,
    tone: _HabitTone.coral,
    targetCount: 1,
    completedCount: 0,
  ),
];

String _buildSwipeHint(_HabitSnapshot habit) {
  if (habit.isCompleted) {
    return 'Норма закрыта. Свайп влево отменит один шаг.';
  }

  if (habit.completedCount == 0) {
    return 'Свайп вправо отметит первый шаг. Влево откатывает счётчик.';
  }

  return 'Осталось ${habit.remainingCount}. Вправо +1, влево отмена.';
}

String _pluralize(int value, String one, String few, String many) {
  final mod10 = value % 10;
  final mod100 = value % 100;

  if (mod10 == 1 && mod100 != 11) {
    return one;
  }

  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return few;
  }

  return many;
}
