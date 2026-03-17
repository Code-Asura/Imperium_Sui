import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/data/imperium_app_repository.dart';

class JournalHomeTab extends StatefulWidget {
  const JournalHomeTab({super.key, required this.repository});

  final ImperiumAppRepository repository;

  @override
  State<JournalHomeTab> createState() => _JournalHomeTabState();
}

class _JournalHomeTabState extends State<JournalHomeTab> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _hydrateJournal();
  }

  List<_JournalEntrySnapshot> get _pinnedEntries =>
      _journalEntriesState.where((entry) => entry.isPinned).toList();

  List<_JournalEntrySnapshot> get _todayEntries =>
      _journalEntriesState.where((entry) => entry.isToday).toList();

  int get _todayWordCount =>
      _todayEntries.fold(0, (sum, entry) => sum + entry.wordCount);

  void _hydrateJournal() {
    try {
      final document = widget.repository.readJournalSync();
      final loadedFolders = document.folders
          .map(_JournalFolderSnapshot.fromMap)
          .toList();
      final loadedEntries = document.entries
          .map(_JournalEntrySnapshot.fromMap)
          .toList();

      _journalFoldersState = loadedFolders.isEmpty
          ? [_buildDefaultJournalFolder()]
          : loadedFolders;
      _journalEntriesState = loadedEntries;
      _isLoading = false;

      if (loadedFolders.isEmpty) {
        unawaited(_saveJournal());
      }
    } catch (_) {
      _journalFoldersState = [_buildDefaultJournalFolder()];
      _journalEntriesState = const [];
      _isLoading = false;

      _showMessage('Не удалось загрузить дневник из базы.');
    }
  }

  Future<void> _saveJournal() async {
    try {
      await widget.repository.saveJournal(
        folders: _journalFoldersState
            .map((folder) => folder.toMap())
            .toList(growable: false),
        entries: _journalEntriesState
            .map((entry) => entry.toMap())
            .toList(growable: false),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Не удалось сохранить дневник.');
    }
  }

  Future<_JournalFolderSnapshot?> _showFolderComposer({
    _JournalFolderSnapshot? folder,
  }) {
    return showModalBottomSheet<_JournalFolderSnapshot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _JournalFolderComposerSheet(
        folder: folder,
        isCreating: folder == null,
        existingTitles: _journalFoldersState
            .map((folder) => folder.title)
            .toSet(),
      ),
    );
  }

  Future<_JournalEntrySnapshot?> _showEntryComposer({
    _JournalEntrySnapshot? entry,
    required bool isCreating,
  }) {
    return Navigator.of(context).push<_JournalEntrySnapshot>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            _JournalEntryComposerScreen(entry: entry, isCreating: isCreating),
      ),
    );
  }

  Future<void> _addEntry() async {
    final entry = await _showEntryComposer(isCreating: true);

    if (!mounted || entry == null) {
      return;
    }

    setState(() {
      _journalEntriesState = [entry, ..._journalEntriesState];
      _adjustFolderCount(entry.folder, 1);
    });
    await _saveJournal();

    _showMessage('Запись "${entry.title}" сохранена.');
  }

  Future<void> _addFolder() async {
    final folder = await _showFolderComposer();

    if (!mounted || folder == null) {
      return;
    }

    setState(() {
      _journalFoldersState = [folder, ..._journalFoldersState];
    });
    await _saveJournal();

    _showMessage('Папка "${folder.title}" создана.');
  }

  Future<_JournalEntrySnapshot?> _editEntry(String id) async {
    final index = _journalEntriesState.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      return null;
    }

    final currentEntry = _journalEntriesState[index];
    final updatedEntry = await _showEntryComposer(
      entry: currentEntry,
      isCreating: false,
    );

    if (!mounted || updatedEntry == null) {
      return null;
    }

    setState(() {
      _journalEntriesState[index] = updatedEntry;
      if (currentEntry.folder != updatedEntry.folder) {
        _adjustFolderCount(currentEntry.folder, -1);
        _adjustFolderCount(updatedEntry.folder, 1);
      }
    });
    await _saveJournal();

    _showMessage('Запись "${updatedEntry.title}" обновлена.');
    return updatedEntry;
  }

  _JournalEntrySnapshot? _hideEntry(String id) {
    final index = _journalEntriesState.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      return null;
    }

    final currentEntry = _journalEntriesState[index];
    if (!currentEntry.isPinned) {
      return currentEntry;
    }

    final updatedEntry = currentEntry.copyWith(isPinned: false);

    setState(() {
      _journalEntriesState[index] = updatedEntry;
    });
    unawaited(_saveJournal());

    _showMessage(
      'Запись "${currentEntry.title}" скрыта с главного экрана.',
      actionLabel: 'Отмена',
      onAction: () {
        if (!mounted) {
          return;
        }

        setState(() {
          _journalEntriesState[index] = currentEntry;
        });
        unawaited(_saveJournal());
      },
    );

    return updatedEntry;
  }

  _JournalEntrySnapshot? _pinEntry(String id) {
    final index = _journalEntriesState.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      return null;
    }

    final currentEntry = _journalEntriesState[index];
    if (currentEntry.isPinned) {
      return currentEntry;
    }

    final updatedEntry = currentEntry.copyWith(isPinned: true);

    setState(() {
      _journalEntriesState[index] = updatedEntry;
    });
    unawaited(_saveJournal());

    _showMessage(
      'Запись "${currentEntry.title}" закреплена на главном экране.',
      actionLabel: 'Отмена',
      onAction: () {
        if (!mounted) {
          return;
        }

        setState(() {
          _journalEntriesState[index] = currentEntry;
        });
        unawaited(_saveJournal());
      },
    );

    return updatedEntry;
  }

  void _deleteEntry(String id) {
    final index = _journalEntriesState.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      return;
    }

    final deletedEntry = _journalEntriesState[index];

    setState(() {
      _journalEntriesState.removeAt(index);
      _adjustFolderCount(deletedEntry.folder, -1);
    });
    unawaited(_saveJournal());

    _showMessage(
      'Запись "${deletedEntry.title}" удалена.',
      actionLabel: 'Отмена',
      onAction: () {
        if (!mounted) {
          return;
        }

        setState(() {
          final restoreIndex = math.min(index, _journalEntriesState.length);
          _journalEntriesState.insert(restoreIndex, deletedEntry);
          _adjustFolderCount(deletedEntry.folder, 1);
        });
        unawaited(_saveJournal());
      },
    );
  }

  Future<bool> _confirmDeleteEntry(String id) async {
    final entry = _journalEntriesState
        .cast<_JournalEntrySnapshot?>()
        .firstWhere((entry) => entry?.id == id, orElse: () => null);

    if (entry == null) {
      return false;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF181011),
          surfaceTintColor: Colors.transparent,
          title: const Text('Удалить запись?'),
          content: Text(
            'Запись "${entry.title}" будет удалена из дневника без возможности восстановления.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              key: const ValueKey('journal-entry-delete-confirm'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8A3B32),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return false;
    }

    _deleteEntry(id);
    return true;
  }

  void _adjustFolderCount(String folderTitle, int delta) {
    final index = _journalFoldersState.indexWhere(
      (folder) => folder.title == folderTitle,
    );

    if (index == -1) {
      return;
    }

    final folder = _journalFoldersState[index];
    _journalFoldersState[index] = folder.copyWith(
      entryCount: math.max(0, folder.entryCount + delta),
    );
  }

  void _showMessage(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: onAction),
        ),
      );
  }

  Widget _buildPinnedEntryTile(_JournalEntrySnapshot entry) {
    return _JournalEntryTile(
      entry: entry,
      onEdit: () => _editEntry(entry.id),
      onSecondaryAction: () async {
        _hideEntry(entry.id);
      },
      onDelete: () => _confirmDeleteEntry(entry.id),
      secondaryActionIcon: Icons.visibility_off_rounded,
      secondaryActionLabel: 'Скрыть',
      secondaryActionGradient: const [Color(0xFF40231E), Color(0xFF180D0C)],
    );
  }

  Future<void> _openFolder(_JournalFolderSnapshot folder) async {
    final shouldEdit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _JournalFolderDetailsSheet(
        folder: folder,
        entries: _journalEntriesState
            .where((entry) => entry.folder == folder.title)
            .toList(),
        onEditEntry: _editEntry,
        onPinEntry: _pinEntry,
        onDeleteEntry: _confirmDeleteEntry,
      ),
    );

    if (shouldEdit == true) {
      await _editFolder(folder.id);
    }
  }

  Future<void> _editFolder(String id) async {
    final index = _journalFoldersState.indexWhere((folder) => folder.id == id);
    if (index == -1) {
      return;
    }

    final currentFolder = _journalFoldersState[index];
    final updatedFolder = await _showFolderComposer(folder: currentFolder);

    if (!mounted || updatedFolder == null) {
      return;
    }

    setState(() {
      _journalFoldersState[index] = updatedFolder;
      _journalEntriesState = [
        for (final entry in _journalEntriesState)
          entry.folder == currentFolder.title
              ? entry.copyWith(folder: updatedFolder.title)
              : entry,
      ];
    });
    await _saveJournal();

    _showMessage('Папка "${updatedFolder.title}" обновлена.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      key: const ValueKey('journal-scroll'),
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
                    'Дневник',
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
                Icons.auto_stories_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _JournalHeroCard(
          wordCount: _todayWordCount,
          entryCount: _todayEntries.length,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('add-journal-entry-button'),
            onPressed: _addEntry,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Новая запись'),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Архив',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('add-journal-folder-button'),
              onPressed: _addFolder,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1.2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.create_new_folder_rounded, size: 18),
              label: const Text('Новая папка'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _JournalFolderCarousel(
          folders: _journalFoldersState,
          onOpenFolder: _openFolder,
        ),
        const SizedBox(height: 24),
        const _JournalSectionHeading(
          title: 'Закреплённые записи',
          subtitle: '',
        ),
        const SizedBox(height: 14),
        if (_pinnedEntries.isEmpty)
          const _EmptyJournalState(
            message: 'Закреплённые записи появятся здесь.',
          )
        else
          Column(
            key: const ValueKey('journal-entries'),
            children: [
              for (var index = 0; index < _pinnedEntries.length; index++) ...[
                _buildPinnedEntryTile(_pinnedEntries[index]),
                if (index != _pinnedEntries.length - 1)
                  const SizedBox(height: 14),
              ],
            ],
          ),
      ],
    );
  }
}

class _JournalFolderCarousel extends StatefulWidget {
  const _JournalFolderCarousel({
    required this.folders,
    required this.onOpenFolder,
  });

  final List<_JournalFolderSnapshot> folders;
  final ValueChanged<_JournalFolderSnapshot> onOpenFolder;

  @override
  State<_JournalFolderCarousel> createState() => _JournalFolderCarouselState();
}

class _JournalFolderCarouselState extends State<_JournalFolderCarousel> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.78);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeIndex = widget.folders.isEmpty
        ? 0
        : _currentIndex.clamp(0, widget.folders.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 108,
          child: PageView.builder(
            key: const ValueKey('journal-folders'),
            controller: _controller,
            padEnds: false,
            clipBehavior: Clip.none,
            itemCount: widget.folders.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final folder = widget.folders[index];
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _JournalFolderCard(
                  folder: folder,
                  entryCount: folder.entryCount,
                  onTap: () => widget.onOpenFolder(folder),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              widget.folders.isEmpty
                  ? '0/0'
                  : '${safeIndex + 1}/${widget.folders.length}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: List.generate(widget.folders.length, (index) {
                  final isActive = index == safeIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: isActive ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.primary
                            : Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _JournalSectionHeading extends StatelessWidget {
  const _JournalSectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

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
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.76),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _JournalHeroCard extends StatelessWidget {
  const _JournalHeroCard({required this.wordCount, required this.entryCount});

  final int wordCount;
  final int entryCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;

    return Container(
      key: const ValueKey('journal-hero-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF241513), Color(0xFF5B2427), Color(0xFF1A1110)],
          stops: [0, 0.66, 1],
        ),
        border: Border.all(color: gold.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF170E0D).withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'СЕГОДНЯ В ДНЕВНИКЕ',
            style: theme.textTheme.labelLarge?.copyWith(
              color: gold,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '$wordCount',
                        key: const ValueKey('journal-hero-words'),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontSize: 42,
                          height: 0.94,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'слов записано сегодня',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 88,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: Colors.white.withValues(alpha: 0.12),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '$entryCount',
                        key: const ValueKey('journal-hero-entries'),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontSize: 42,
                          height: 0.94,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_pluralizeEntries(entryCount)} создано сегодня',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JournalFolderCard extends StatelessWidget {
  const _JournalFolderCard({
    required this.folder,
    required this.entryCount,
    required this.onTap,
  });

  final _JournalFolderSnapshot folder;
  final int entryCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      key: ValueKey('journal-folder-card-${folder.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 190,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [folder.accent, const Color(0xFF161010)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Icon(folder.icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$entryCount ${_pluralizeEntries(entryCount)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalEntryTile extends StatelessWidget {
  const _JournalEntryTile({
    required this.entry,
    required this.onEdit,
    required this.onSecondaryAction,
    required this.onDelete,
    required this.secondaryActionIcon,
    required this.secondaryActionLabel,
    required this.secondaryActionGradient,
  });

  final _JournalEntrySnapshot entry;
  final Future<void> Function() onEdit;
  final Future<void> Function() onSecondaryAction;
  final Future<bool> Function() onDelete;
  final IconData secondaryActionIcon;
  final String secondaryActionLabel;
  final List<Color> secondaryActionGradient;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('journal-entry-${entry.id}'),
      direction: DismissDirection.horizontal,
      background: const _JournalEntryActionBackground(
        icon: Icons.edit_rounded,
        label: 'Изменить',
        alignment: Alignment.centerLeft,
        gradient: [Color(0xFF72502C), Color(0xFF23130F)],
      ),
      secondaryBackground: _JournalEntryActionBackground(
        icon: secondaryActionIcon,
        label: secondaryActionLabel,
        alignment: Alignment.centerRight,
        gradient: secondaryActionGradient,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await onEdit();
        } else if (direction == DismissDirection.endToStart) {
          await onSecondaryAction();
        }
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () {
          onDelete();
        },
        child: _JournalEntryCard(entry: entry),
      ),
    );
  }
}

class _JournalEntryActionBackground extends StatelessWidget {
  const _JournalEntryActionBackground({
    required this.icon,
    required this.label,
    required this.alignment,
    required this.gradient,
  });

  final IconData icon;
  final String label;
  final Alignment alignment;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    final isLeading = alignment == Alignment.centerLeft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isLeading ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeading ? Alignment.centerRight : Alignment.centerLeft,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLeading) ...[
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Icon(icon, color: Colors.white),
          if (isLeading) ...[
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  const _JournalEntryCard({required this.entry});

  final _JournalEntrySnapshot entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF201313), Color(0xFF120B0C)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.folder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.74),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (entry.isPinned)
                Icon(
                  Icons.push_pin_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            entry.title,
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          if (entry.body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.64),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.64),
              ),
              const SizedBox(width: 6),
              Text(
                entry.durationLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JournalFolderDetailsSheet extends StatefulWidget {
  const _JournalFolderDetailsSheet({
    required this.folder,
    required this.entries,
    required this.onEditEntry,
    required this.onPinEntry,
    required this.onDeleteEntry,
  });

  final _JournalFolderSnapshot folder;
  final List<_JournalEntrySnapshot> entries;
  final Future<_JournalEntrySnapshot?> Function(String id) onEditEntry;
  final _JournalEntrySnapshot? Function(String id) onPinEntry;
  final Future<bool> Function(String id) onDeleteEntry;

  @override
  State<_JournalFolderDetailsSheet> createState() =>
      _JournalFolderDetailsSheetState();
}

class _JournalFolderDetailsSheetState
    extends State<_JournalFolderDetailsSheet> {
  late List<_JournalEntrySnapshot> _entriesState;

  @override
  void initState() {
    super.initState();
    _entriesState = List.of(widget.entries);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSheetHeight = math.min(
      MediaQuery.sizeOf(context).height * 0.84,
      720.0,
    );
    final listHeight = math.min(
      _entriesState.length * 152.0,
      math.max(220.0, maxSheetHeight - 180.0),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Material(
          key: ValueKey('journal-folder-sheet-${widget.folder.id}'),
          color: const Color(0xFF140D0C),
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.folder.accent.withValues(alpha: 0.26),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(widget.folder.icon, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.folder.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${_entriesState.length} ${_pluralizeEntries(_entriesState.length)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      key: const ValueKey('edit-journal-folder-button'),
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Записи',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: _entriesState.isEmpty ? null : listHeight,
                  child: _entriesState.isEmpty
                      ? const _EmptyJournalState(message: 'Пока нет записей.')
                      : ListView.separated(
                          key: ValueKey(
                            'journal-folder-details-${widget.folder.id}',
                          ),
                          itemCount: _entriesState.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final entry = _entriesState[index];

                            return _JournalEntryTile(
                              entry: entry,
                              onEdit: () async {
                                final updatedEntry = await widget.onEditEntry(
                                  entry.id,
                                );

                                if (!mounted || updatedEntry == null) {
                                  return;
                                }

                                final entryIndex = _entriesState.indexWhere(
                                  (candidate) => candidate.id == entry.id,
                                );
                                if (entryIndex == -1) {
                                  return;
                                }

                                setState(() {
                                  if (updatedEntry.folder !=
                                      widget.folder.title) {
                                    _entriesState.removeAt(entryIndex);
                                  } else {
                                    _entriesState[entryIndex] = updatedEntry;
                                  }
                                });
                              },
                              onSecondaryAction: () async {
                                final updatedEntry = widget.onPinEntry(
                                  entry.id,
                                );
                                if (!mounted || updatedEntry == null) {
                                  return;
                                }

                                final entryIndex = _entriesState.indexWhere(
                                  (candidate) => candidate.id == entry.id,
                                );
                                if (entryIndex == -1) {
                                  return;
                                }

                                setState(() {
                                  _entriesState[entryIndex] = updatedEntry;
                                });
                              },
                              onDelete: () async {
                                final shouldDelete = await widget.onDeleteEntry(
                                  entry.id,
                                );
                                if (!mounted || !shouldDelete) {
                                  return false;
                                }

                                final entryIndex = _entriesState.indexWhere(
                                  (candidate) => candidate.id == entry.id,
                                );
                                if (entryIndex == -1) {
                                  return true;
                                }

                                setState(() {
                                  _entriesState.removeAt(entryIndex);
                                });

                                return true;
                              },
                              secondaryActionIcon: Icons.push_pin_rounded,
                              secondaryActionLabel: 'Закрепить',
                              secondaryActionGradient: const [
                                Color(0xFF72502C),
                                Color(0xFF21120D),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JournalFolderComposerSheet extends StatefulWidget {
  const _JournalFolderComposerSheet({
    required this.isCreating,
    required this.existingTitles,
    this.folder,
  });

  final bool isCreating;
  final Set<String> existingTitles;
  final _JournalFolderSnapshot? folder;

  @override
  State<_JournalFolderComposerSheet> createState() =>
      _JournalFolderComposerSheetState();
}

class _JournalFolderComposerSheetState
    extends State<_JournalFolderComposerSheet> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.folder?.title ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    final normalizedTitles = widget.existingTitles
        .where((existing) => existing != widget.folder?.title)
        .map((existing) => existing.toLowerCase())
        .toSet();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Нужно указать название папки.')),
        );
      return;
    }

    if (normalizedTitles.contains(title.toLowerCase())) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Название папки должно быть уникальным.'),
          ),
        );
      return;
    }

    final draftIndex = _journalFoldersState.length;
    final accent =
        widget.folder?.accent ??
        _draftFolderAccents[draftIndex % _draftFolderAccents.length];
    final icon =
        widget.folder?.icon ??
        _draftFolderIcons[draftIndex % _draftFolderIcons.length];

    Navigator.of(context).pop(
      _JournalFolderSnapshot(
        id:
            widget.folder?.id ??
            'folder-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        entryCount: widget.folder?.entryCount ?? 0,
        icon: icon,
        accent: accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  widget.isCreating ? 'Новая папка' : 'Изменить папку',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Собирай заметки по датам и ручным блокам в отдельные папки.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 18),
                _JournalEditorField(
                  key: const ValueKey('journal-folder-title'),
                  controller: _titleController,
                  label: 'Название папки',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('journal-folder-save'),
                    onPressed: _save,
                    child: Text(
                      widget.isCreating ? 'Создать папку' : 'Сохранить',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JournalEntryComposerScreen extends StatefulWidget {
  const _JournalEntryComposerScreen({required this.isCreating, this.entry});

  final bool isCreating;
  final _JournalEntrySnapshot? entry;

  @override
  State<_JournalEntryComposerScreen> createState() =>
      _JournalEntryComposerScreenState();
}

class _JournalEntryComposerScreenState
    extends State<_JournalEntryComposerScreen> {
  late final TextEditingController _contentController;
  late String _selectedFolder;
  late bool _isPinned;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.entry?.content ?? '',
    );
    _selectedFolder =
        widget.entry?.folder ??
        (_journalFoldersState.isEmpty ? '' : _journalFoldersState.first.title);
    _isPinned = widget.entry?.isPinned ?? false;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _save() {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Напиши что-нибудь перед сохранением.')),
        );
      return;
    }

    final folderTitle =
        _selectedFolder.isEmpty && _journalFoldersState.isNotEmpty
        ? _journalFoldersState.first.title
        : _selectedFolder;

    Navigator.of(context).pop(
      _JournalEntrySnapshot(
        id:
            widget.entry?.id ??
            'journal-entry-${DateTime.now().microsecondsSinceEpoch}',
        folder: folderTitle,
        content: content,
        dateLabel: widget.entry?.dateLabel ?? _formatCurrentMoment(),
        durationLabel: _estimateDuration(content),
        isPinned: _isPinned,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0E0909),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.isCreating ? 'Новая запись' : 'Изменить запись'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Пиши заметку свободно и собирай внутри любые блоки вручную.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _JournalEditorField(
                  key: const ValueKey('journal-entry-content'),
                  controller: _contentController,
                  label: 'Запись',
                  maxLines: 16,
                  expands: true,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const ValueKey('journal-entry-folder'),
                initialValue: _selectedFolder.isEmpty ? null : _selectedFolder,
                isExpanded: true,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                iconEnabledColor: Colors.white,
                decoration: InputDecoration(
                  labelText: 'Папка',
                  labelStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                  floatingLabelStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF171011),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                dropdownColor: const Color(0xFF1A1212),
                items: [
                  for (final folder in _journalFoldersState)
                    DropdownMenuItem<String>(
                      value: folder.title,
                      child: Text(
                        folder.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedFolder = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF171011),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Показывать на главном экране',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Закреплённые записи остаются видны вне папки.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.68),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _isPinned,
                      onChanged: (value) {
                        setState(() {
                          _isPinned = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: FilledButton(
          key: const ValueKey('journal-entry-save'),
          onPressed: _save,
          child: Text(
            widget.isCreating ? 'Создать запись' : 'Сохранить изменения',
          ),
        ),
      ),
    );
  }
}

class _JournalEditorField extends StatelessWidget {
  const _JournalEditorField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines,
    this.expands = false,
  });

  final TextEditingController controller;
  final String label;
  final int? maxLines;
  final bool expands;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      maxLines: expands ? null : maxLines,
      expands: expands,
      minLines: expands ? null : maxLines,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: Colors.white,
        height: 1.45,
      ),
      textCapitalization: TextCapitalization.sentences,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.72),
        ),
        floatingLabelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
        filled: true,
        fillColor: const Color(0xFF171011),
        contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _EmptyJournalState extends StatelessWidget {
  const _EmptyJournalState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151010),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notes_rounded,
            color: Colors.white.withValues(alpha: 0.64),
            size: 22,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalFolderSnapshot {
  const _JournalFolderSnapshot({
    required this.id,
    required this.title,
    required this.entryCount,
    required this.icon,
    required this.accent,
  });

  final String id;
  final String title;
  final int entryCount;
  final IconData icon;
  final Color accent;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'entryCount': entryCount,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
      'iconMatchTextDirection': icon.matchTextDirection,
      'accentValue': accent.toARGB32(),
    };
  }

  factory _JournalFolderSnapshot.fromMap(Map<String, Object?> map) {
    return _JournalFolderSnapshot(
      id: _journalReadString(
        map['id'],
        fallback: 'folder-${DateTime.now().microsecondsSinceEpoch}',
      ),
      title: _journalReadString(map['title'], fallback: 'Личный архив'),
      entryCount: _journalReadInt(map['entryCount']),
      icon: IconData(
        _journalReadInt(
          map['iconCodePoint'],
          fallback: Icons.inventory_2_rounded.codePoint,
        ),
        fontFamily: _journalReadString(
          map['iconFontFamily'],
          fallback: 'MaterialIcons',
        ),
        fontPackage: _journalNullableString(map['iconFontPackage']),
        matchTextDirection: _journalReadBool(map['iconMatchTextDirection']),
      ),
      accent: Color(
        _journalReadInt(
          map['accentValue'],
          fallback: const Color(0xFF5A3126).toARGB32(),
        ),
      ),
    );
  }

  _JournalFolderSnapshot copyWith({
    String? id,
    String? title,
    int? entryCount,
    IconData? icon,
    Color? accent,
  }) {
    return _JournalFolderSnapshot(
      id: id ?? this.id,
      title: title ?? this.title,
      entryCount: entryCount ?? this.entryCount,
      icon: icon ?? this.icon,
      accent: accent ?? this.accent,
    );
  }
}

class _JournalEntrySnapshot {
  const _JournalEntrySnapshot({
    required this.id,
    required this.folder,
    required this.content,
    required this.dateLabel,
    required this.durationLabel,
    required this.isPinned,
  });

  final String id;
  final String folder;
  final String content;
  final String dateLabel;
  final String durationLabel;
  final bool isPinned;

  String get title => _firstLine(content);
  String get body => _remainingLines(content);
  int get wordCount => RegExp(r'\S+').allMatches(content).length;
  DateTime? get createdAt {
    if (!id.startsWith('journal-entry-')) {
      return null;
    }

    final rawTimestamp = id.substring('journal-entry-'.length);
    final microseconds = int.tryParse(rawTimestamp);
    if (microseconds == null) {
      return null;
    }

    return DateTime.fromMicrosecondsSinceEpoch(microseconds);
  }

  bool get isToday {
    final createdAt = this.createdAt;
    if (createdAt != null) {
      return _isSameCalendarDay(createdAt, DateTime.now());
    }

    return dateLabel.trimLeft().startsWith('Сегодня');
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'folder': folder,
      'content': content,
      'dateLabel': dateLabel,
      'durationLabel': durationLabel,
      'isPinned': isPinned,
    };
  }

  factory _JournalEntrySnapshot.fromMap(Map<String, Object?> map) {
    return _JournalEntrySnapshot(
      id: _journalReadString(
        map['id'],
        fallback: 'journal-entry-${DateTime.now().microsecondsSinceEpoch}',
      ),
      folder: _journalReadString(map['folder'], fallback: 'Личный архив'),
      content: _journalReadString(map['content']),
      dateLabel: _journalReadString(
        map['dateLabel'],
        fallback: _formatCurrentMoment(),
      ),
      durationLabel: _journalReadString(
        map['durationLabel'],
        fallback: '1 мин',
      ),
      isPinned: _journalReadBool(map['isPinned']),
    );
  }

  _JournalEntrySnapshot copyWith({
    String? id,
    String? folder,
    String? content,
    String? dateLabel,
    String? durationLabel,
    bool? isPinned,
  }) {
    return _JournalEntrySnapshot(
      id: id ?? this.id,
      folder: folder ?? this.folder,
      content: content ?? this.content,
      dateLabel: dateLabel ?? this.dateLabel,
      durationLabel: durationLabel ?? this.durationLabel,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

const List<Color> _draftFolderAccents = [
  Color(0xFF5A3126),
  Color(0xFF3A4B67),
  Color(0xFF395437),
  Color(0xFF604B2F),
];

const List<IconData> _draftFolderIcons = [
  Icons.inventory_2_rounded,
  Icons.folder_special_rounded,
  Icons.library_books_rounded,
  Icons.archive_rounded,
];

_JournalFolderSnapshot _buildDefaultJournalFolder() {
  return const _JournalFolderSnapshot(
    id: 'folder-archive',
    title: 'Личный архив',
    entryCount: 0,
    icon: Icons.inventory_2_rounded,
    accent: Color(0xFF5A3126),
  );
}

List<_JournalFolderSnapshot> _journalFoldersState = const [];
List<_JournalEntrySnapshot> _journalEntriesState = const [];

int _journalReadInt(Object? value, {int fallback = 0}) {
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

bool _journalReadBool(Object? value, {bool fallback = false}) {
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

String _journalReadString(Object? value, {String fallback = ''}) {
  if (value is String) {
    return value;
  }
  return fallback;
}

String? _journalNullableString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

// ignore: unused_element
final List<_JournalFolderSnapshot> _demoJournalFolders = [
  const _JournalFolderSnapshot(
    id: 'folder-archive',
    title: 'Личный архив',
    entryCount: 3,
    icon: Icons.inventory_2_rounded,
    accent: Color(0xFF5A3126),
  ),
];

// ignore: unused_element
final List<_JournalEntrySnapshot> _demoJournalEntries = [
  const _JournalEntrySnapshot(
    id: 'journal-entry-1',
    folder: 'Личный архив',
    content:
        'Утренние заметки\nФокус перед первым спринтом. Дыхание, вода, движение.',
    dateLabel: 'Сегодня, 07:40',
    durationLabel: '3 мин',
    isPinned: true,
  ),
  const _JournalEntrySnapshot(
    id: 'journal-entry-2',
    folder: 'Личный архив',
    content:
        'Дневной обзор\nБлок медитации и короткая перезагрузка после обеда.',
    dateLabel: 'Сегодня, 13:10',
    durationLabel: '4 мин',
    isPinned: false,
  ),
  const _JournalEntrySnapshot(
    id: 'journal-entry-3',
    folder: 'Личный архив',
    content:
        'Вечернее завершение\nПара строк о дне и о следующем сигнале, который стоит удержать.',
    dateLabel: 'Вчера, 21:15',
    durationLabel: '3 мин',
    isPinned: true,
  ),
];

String _pluralizeEntries(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;

  if (mod10 == 1 && mod100 != 11) {
    return 'запись';
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'записи';
  }
  return 'записей';
}

String _firstLine(String content) {
  final lines = content
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  if (lines.isEmpty) {
    return 'Без заголовка';
  }

  return lines.first;
}

String _remainingLines(String content) {
  final lines = content.split('\n');
  if (lines.length <= 1) {
    return '';
  }

  return lines.skip(1).join('\n').trim();
}

String _estimateDuration(String content) {
  final wordCount = content
      .split(RegExp(r'\s+'))
      .where((word) => word.trim().isNotEmpty)
      .length;
  final minutes = math.max(1, (wordCount / 80).ceil());
  return '$minutes мин';
}

bool _isSameCalendarDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _formatCurrentMoment() {
  final now = DateTime.now();
  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');
  return 'Сегодня, $hour:$minute';
}
