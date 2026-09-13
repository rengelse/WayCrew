import 'dart:async';

import 'package:flutter/material.dart';

import 'place_search_service.dart';
import '../map/meeting_point_map.dart';

class PlaceSearchField extends StatefulWidget {
  final String label;
  final String hint;
  final bool requiredSelection;
  final ValueChanged<PlaceSearchResult?> onChanged;

  const PlaceSearchField({
    super.key,
    required this.label,
    required this.hint,
    required this.onChanged,
    this.requiredSelection = false,
  });

  @override
  State<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<PlaceSearchField> {
  final TextEditingController _controller = TextEditingController();
  final PlaceSearchService _service = PlaceSearchService();
  Timer? _debounce;
  List<PlaceSearchResult> _results = const [];
  PlaceSearchResult? _selected;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    if (_selected != null && query == _selected!.name) return;
    if (_selected != null) {
      _selected = null;
      widget.onChanged(null);
    }
    _debounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await _service.search(query);
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _results = results;
        _searching = false;
        _error = results.isEmpty ? 'Fant ingen steder. Prøv sted + kommune eller full adresse.' : null;
      });
    } catch (error) {
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _results = const [];
        _searching = false;
        _error = 'Stedsøk er ikke tilgjengelig akkurat nå.';
      });
    }
  }

  void _select(PlaceSearchResult result) {
    _debounce?.cancel();
    setState(() {
      _selected = result;
      _results = const [];
      _error = null;
      _controller.text = result.name;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    });
    widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: widget.requiredSelection ? '${widget.label} *' : widget.label,
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.place_outlined),
          suffixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : _selected != null
                  ? const Icon(Icons.check_circle_outline)
                  : null,
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 6),
        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
      if (_results.isNotEmpty) ...[
        const SizedBox(height: 6),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: _results
                .map((result) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(result.name),
                      subtitle: result.address.isEmpty
                          ? null
                          : Text(result.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _select(result),
                    ))
                .toList(),
          ),
        ),
      ],
      if (_selected != null) ...[
        const SizedBox(height: 10),
        MeetingPointMap(
          latitude: _selected!.latitude,
          longitude: _selected!.longitude,
          onPositionChanged: (point) {
            final updated = PlaceSearchResult(
              name: _selected!.name,
              address: _selected!.address,
              latitude: point.latitude,
              longitude: point.longitude,
            );
            setState(() => _selected = updated);
            widget.onChanged(updated);
          },
        ),
        const SizedBox(height: 6),
        Text(
          _selected!.address.isEmpty ? _selected!.name : _selected!.address,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ]);
  }
}
