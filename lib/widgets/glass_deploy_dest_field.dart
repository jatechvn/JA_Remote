import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../data/repositories/file_deploy_history_repository.dart';
import '../theme/app_colors.dart';
import '../theme/language_provider.dart';

/// Bento Glassmorphism Destination Path TextField with live history suggestions.
/// Persists destination paths and suggests previously used paths as the user types or clicks.
class GlassDeployDestField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final AppColors colors;
  final LanguageProvider language;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onSelected;
  final FileDeployHistoryRepository historyRepo;
  final bool openOverlayOnFocus;

  GlassDeployDestField({
    super.key,
    required this.controller,
    required this.colors,
    required this.language,
    this.focusNode,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.onSelected,
    this.openOverlayOnFocus = false,
    FileDeployHistoryRepository? historyRepo,
  }) : historyRepo = historyRepo ?? FileDeployHistoryRepository();

  @override
  State<GlassDeployDestField> createState() => _GlassDeployDestFieldState();
}

class _GlassDeployDestFieldState extends State<GlassDeployDestField> {
  final LayerLink _layerLink = LayerLink();
  late final FocusNode _internalFocusNode;

  OverlayEntry? _overlayEntry;
  List<String> _cachedHistory = [];
  bool _isOpen = false;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    _effectiveFocusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    widget.controller.removeListener(_handleTextChange);
    _removeOverlay();
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (_effectiveFocusNode.hasFocus && widget.enabled) {
      if (widget.openOverlayOnFocus) {
        _showOverlay();
      }
    } else {
      _removeOverlay();
    }
  }

  void _handleTextChange() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
    if (_isOpen) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  Future<void> _loadHistory() async {
    final list = await widget.historyRepo.getDestHistory();
    if (!mounted) return;
    _cachedHistory = list;
    if (_isOpen) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  List<String> _getFilteredHistory() {
    final query = widget.controller.text.trim().toLowerCase();
    if (query.isEmpty) return _cachedHistory;
    return _cachedHistory
        .where((item) => item.toLowerCase().contains(query))
        .toList();
  }

  void _showOverlay() async {
    await _loadHistory();
    if (!mounted || !_effectiveFocusNode.hasFocus) return;

    _removeOverlay();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        final colors = widget.colors;
        final language = widget.language;
        final filtered = _getFilteredHistory();
        final overlayWidth = math.max(size.width, 320.0);

        return Stack(
          children: [
            // Dismiss barrier
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
              ),
            ),
            Positioned(
              width: overlayWidth,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, size.height + 4),
                child: TextFieldTapRegion(
                  child: Material(
                    color: Colors.transparent,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 260),
                          decoration: BoxDecoration(
                            color: colors.cardBg.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colors.accentCyan.withValues(alpha: 0.35),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accentCyan.withValues(
                                    alpha: 0.08,
                                  ),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: colors.cardBorder.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.history_rounded,
                                      size: 13,
                                      color: colors.accentCyan,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        language.t('deploy_dest_history_title'),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (_cachedHistory.isNotEmpty)
                                      InkWell(
                                        onTap: () async {
                                          await widget.historyRepo
                                              .clearDestHistory();
                                          await _loadHistory();
                                        },
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          child: Text(
                                            language.t('deploy_history_clear'),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: colors.accentRose,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Items List
                              if (filtered.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    language.t('deploy_history_empty'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.textMuted,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else
                                Flexible(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (ctx, index) {
                                      final path = filtered[index];
                                      return Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _selectItem(path),
                                          hoverColor: colors.accentCyan
                                              .withValues(alpha: 0.12),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.folder_shared_rounded,
                                                  size: 13,
                                                  color: colors.accentCyan,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    path,
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontFamily: 'monospace',
                                                      color: colors.textPrimary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                InkWell(
                                                  onTap: () async {
                                                    await widget.historyRepo
                                                        .removeDestHistory(
                                                          path,
                                                        );
                                                    await _loadHistory();
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(3),
                                                    child: Icon(
                                                      Icons.close_rounded,
                                                      size: 12,
                                                      color: colors.textMuted,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    if (mounted) {
      final scheduler = SchedulerBinding.instance;
      if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        scheduler.addPostFrameCallback((_) {
          if (mounted) setState(() => _isOpen = true);
        });
      } else {
        setState(() => _isOpen = true);
      }
    } else {
      _isOpen = true;
    }
  }

  void _removeOverlay() {
    if (!_isOpen && _overlayEntry == null) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      final scheduler = SchedulerBinding.instance;
      if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        scheduler.addPostFrameCallback((_) {
          if (mounted) setState(() => _isOpen = false);
        });
      } else {
        setState(() => _isOpen = false);
      }
    } else {
      _isOpen = false;
    }
  }

  void _selectItem(String path) {
    widget.controller.text = path;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: path.length),
    );
    widget.historyRepo.saveLastState(destPath: path);
    widget.historyRepo.addDestHistory(path);
    _removeOverlay();
    widget.onChanged?.call(path);
    widget.onSelected?.call(path);
    widget.onSubmitted?.call(path);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final language = widget.language;
    final hasText = widget.controller.text.isNotEmpty;

    return TextFieldTapRegion(
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                if (_isOpen) {
                  _removeOverlay();
                  return KeyEventResult.handled;
                }
              } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                if (!_isOpen && widget.enabled) {
                  _showOverlay();
                  return KeyEventResult.handled;
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: widget.controller,
            focusNode: _effectiveFocusNode,
            enabled: widget.enabled,
            onTap: () {
              if (!_isOpen && widget.enabled) {
                _showOverlay();
              }
            },
            onChanged: (val) {
              widget.historyRepo.saveLastState(destPath: val);
              widget.onChanged?.call(val);
              if (!_isOpen && _effectiveFocusNode.hasFocus) {
                _showOverlay();
              } else {
                _overlayEntry?.markNeedsBuild();
              }
            },
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                widget.historyRepo.addDestHistory(val.trim());
              }
              _removeOverlay();
              widget.onSubmitted?.call(val);
            },
            style: TextStyle(
              fontSize: 12.5,
              fontFamily: 'monospace',
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: language.t('deploy_dest_hint'),
              hintStyle: TextStyle(fontSize: 11.5, color: colors.textMuted),
              filled: true,
              fillColor: colors.cardBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (hasText)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 14),
                      color: colors.textMuted,
                      splashRadius: 14,
                      tooltip: language.t('cmd_script_clear'),
                      onPressed: () {
                        widget.controller.clear();
                        widget.historyRepo.saveLastState(destPath: '');
                        widget.onChanged?.call('');
                        if (_isOpen) {
                          _overlayEntry?.markNeedsBuild();
                        }
                      },
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.history_rounded,
                      size: 15,
                      color: _isOpen ? colors.accentCyan : colors.textMuted,
                    ),
                    splashRadius: 14,
                    tooltip: language.t('deploy_dest_history_title'),
                    onPressed: widget.enabled
                        ? () {
                            if (_isOpen) {
                              _removeOverlay();
                            } else {
                              _effectiveFocusNode.requestFocus();
                              _showOverlay();
                            }
                          }
                        : null,
                  ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.accentCyan, width: 1.1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
