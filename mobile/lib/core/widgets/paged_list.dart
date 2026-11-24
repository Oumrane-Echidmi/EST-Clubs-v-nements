import 'package:flutter/material.dart';
import '../network/paged.dart';
import 'state_views.dart';

/// Reusable list with loading, error+retry, empty state, pull-to-refresh and
/// infinite scroll. Give it a new `key` to force a reload (e.g. new search).
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    required this.emptyMessage,
  });
  final Future<Paged<T>> Function(int page) fetch;
  final Widget Function(BuildContext, T) itemBuilder;
  final String emptyMessage;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final _items = <T>[];
  final _scroll = ScrollController();
  int _page = 0;
  bool _hasMore = true, _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _load();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await widget.fetch(_page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(p.items);
        _page = p.page;
        _hasMore = p.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    _items.clear();
    _page = 0;
    _hasMore = true;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading) return const LoadingView();
    if (_items.isEmpty && _error != null) {
      return ErrorView(message: '$_error', onRetry: _refresh);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(children: [
          SizedBox(height: 300, child: EmptyState(message: widget.emptyMessage))
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (c, i) => i < _items.length
            ? widget.itemBuilder(c, _items[i])
            : const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator())),
      ),
    );
  }
}
