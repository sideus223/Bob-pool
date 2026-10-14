import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/board_page_result.dart';
import '../../services/board_latency_probe.dart';

/// Requests one fixed-size page only after scrolling; no growing limit query.
class BoardPagedList<T> extends StatefulWidget {
  final Future<BoardPageResult<T>> Function(
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  )
  load;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget empty;
  final Widget? header;
  final Object refreshKey;
  final EdgeInsets padding;
  final Decoration? itemsDecoration;
  final EdgeInsets itemsPadding;
  final Widget? separator;
  const BoardPagedList({
    super.key,
    required this.load,
    required this.itemBuilder,
    required this.empty,
    this.header,
    this.refreshKey = 0,
    this.padding = const EdgeInsets.all(16),
    this.itemsDecoration,
    this.itemsPadding = EdgeInsets.zero,
    this.separator,
  });

  @override
  State<BoardPagedList<T>> createState() => _BoardPagedListState<T>();
}

class _BoardPagedListState<T> extends State<BoardPagedList<T>> {
  final _scroll = ScrollController();
  final _items = <T>[];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _busy = false, _more = true;
  Object? _error;
  int _generation = 0;
  int _probeSample = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _next();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 160 && _error == null) _next();
  }

  @override
  void didUpdateWidget(covariant BoardPagedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _refresh();
  }

  Future<void> _refresh() async {
    _generation++;
    _items.clear();
    _cursor = null;
    _more = true;
    _busy = false;
    _error = null;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    await _next();
  }

  Future<void> _next() async {
    if (_busy || !_more) return;
    final generation = _generation;
    final firstPage = _cursor == null;
    final probeSample = BoardLatencyProbe.enabled ? ++_probeSample : 0;
    final probeWatch = BoardLatencyProbe.enabled
        ? (Stopwatch()..start())
        : null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await widget.load(_cursor);
      final loadUs = probeWatch?.elapsedMicroseconds;
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.cursor;
        _more = page.hasMore;
      });
      if (BoardLatencyProbe.enabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || generation != _generation) return;
          BoardLatencyProbe.emit('frame', {
            'sample': probeSample,
            'load_us': loadUs,
            'first_frame_us': probeWatch!.elapsedMicroseconds,
            'documents': page.items.length,
            'first_page': firstPage,
          });
          if (firstPage && probeSample < BoardLatencyProbe.sampleLimit) {
            Future<void>.delayed(const Duration(seconds: 1), () async {
              if (mounted && generation == _generation && !_busy) {
                await _refresh();
              }
            });
          }
        });
      }
    } catch (error) {
      BoardLatencyProbe.emit('error', {
        'sample': probeSample,
        'error_type': error.runtimeType.toString(),
      });
      if (mounted && generation == _generation) setState(() => _error = error);
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && widget.header == null) {
      if (_busy) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFD5D69)),
        );
      }
      if (_error != null) {
        return Center(
          child: TextButton(
            onPressed: _next,
            child: const Text('불러오지 못했어요. 다시 시도'),
          ),
        );
      }
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: widget.padding,
            sliver: SliverMainAxisGroup(
              slivers: [
                if (widget.header != null)
                  SliverToBoxAdapter(child: widget.header),
                if (_items.isEmpty && !_busy && _error == null)
                  if (widget.header == null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: widget.empty,
                    )
                  else
                    SliverToBoxAdapter(child: widget.empty),
                DecoratedSliver(
                  decoration: widget.itemsDecoration ?? const BoxDecoration(),
                  sliver: SliverPadding(
                    padding: widget.itemsPadding,
                    sliver: SliverList.separated(
                      itemCount: _items.length,
                      itemBuilder: (context, index) =>
                          widget.itemBuilder(context, _items[index]),
                      separatorBuilder: (context, index) =>
                          widget.separator ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFD5D69),
                            ),
                          ),
                        )
                      : _error != null
                      ? TextButton(
                          onPressed: _next,
                          child: const Text('불러오지 못했어요. 다시 시도'),
                        )
                      : _more
                      ? TextButton(
                          onPressed: _next,
                          child: const Text('더 불러오기'),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
