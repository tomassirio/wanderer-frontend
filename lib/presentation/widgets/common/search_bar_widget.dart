import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/domain/trip.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';

/// A self-contained search bar that fetches and displays trip results from
/// the API.  Designed to be placed directly as the AppBar [title] when the
/// user activates search.  The widget manages its own [TextEditingController],
/// overlay dropdown and API calls.
class SearchBarWidget extends StatefulWidget {
  /// Called when the search bar wants to close itself (e.g. the user tapped
  /// outside the results overlay, or navigated to a trip).
  final VoidCallback? onClose;

  const SearchBarWidget({super.key, this.onClose});

  @override
  State<SearchBarWidget> createState() => SearchBarWidgetState();
}

class SearchBarWidgetState extends State<SearchBarWidget> {
  final TripService _tripService = TripService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  List<Trip> _searchResults = [];
  bool _isSearching = false;
  bool _hasError = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
    // Auto-focus on the next frame so the keyboard opens immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Close handling
  // ---------------------------------------------------------------------------

  /// Tears down overlay state and tells the parent to hide this widget.
  void _handleClose() {
    _focusNode.unfocus();
    _removeOverlay();
    widget.onClose?.call();
  }

  // ---------------------------------------------------------------------------
  // Search logic
  // ---------------------------------------------------------------------------

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    final query = _controller.text.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _hasError = false;
      });
      _updateOverlay();
      return;
    }

    setState(() => _isSearching = true);
    _updateOverlay();

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final page = await _tripService.getPublicTrips(size: 50);
      final lowerQuery = query.toLowerCase();
      final filtered = page.content.where((trip) {
        return trip.name.toLowerCase().contains(lowerQuery) ||
            trip.username.toLowerCase().contains(lowerQuery);
      }).toList();

      if (mounted) {
        setState(() {
          _searchResults = filtered.take(8).toList();
          _isSearching = false;
          _hasError = false;
        });
        _updateOverlay();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _hasError = true;
        });
        _updateOverlay();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Overlay management
  // ---------------------------------------------------------------------------

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _updateOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    } else if (_controller.text.isNotEmpty) {
      _showOverlay();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        final renderBox = this.context.findRenderObject() as RenderBox?;
        final appBarWidth = renderBox?.size.width ?? 300;

        return Stack(
          children: [
            // Transparent barrier — tapping outside closes search
            Positioned.fill(
              child: GestureDetector(
                onTap: _handleClose,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),
            // Results dropdown
            Positioned(
              width: appBarWidth.clamp(280.0, 500.0),
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 48),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(this.context).cardColor,
                  child: _buildResultsContent(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultsContent() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: Colors.red[400]),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Could not load results. Try again.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && _controller.text.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.search_off, size: 18, color: Colors.grey[400]),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'No trips found',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 12,
          endIndent: 12,
          color: Colors.grey[200],
        ),
        itemBuilder: (context, index) =>
            _buildResultTile(_searchResults[index]),
      ),
    );
  }

  Widget _buildResultTile(Trip trip) {
    return InkWell(
      onTap: () => _navigateToTrip(trip),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Status colour dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _statusColor(trip.status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            // Trip info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${trip.username}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            // Status label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor(trip.status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                trip.status.displayLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _statusColor(trip.status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToTrip(Trip trip) {
    _removeOverlay();
    widget.onClose?.call();
    Navigator.push(
      context,
      PageTransitions.slideUp(TripDetailScreen(trip: trip)),
    );
  }

  Color _statusColor(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return Colors.grey;
      case TripStatus.inProgress:
        return Colors.blue;
      case TripStatus.paused:
        return Colors.orange;
      case TripStatus.finished:
        return Colors.green;
      case TripStatus.resting:
        return WandererTheme.statusResting;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Search\u2026',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  _controller.clear();
                } else {
                  _handleClose();
                }
              },
            ),
            filled: true,
            fillColor: Colors.transparent,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            isDense: true,
          ),
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            _debounceTimer?.cancel();
            final query = _controller.text.trim();
            if (query.isNotEmpty) _performSearch(query);
          },
        ),
      ),
    );
  }
}
