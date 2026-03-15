import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/data/models/domain/trip_location.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/custom_info_window.dart';

/// Widget displaying the Google Maps view for a trip
class TripMapView extends StatefulWidget {
  final LatLng initialLocation;
  final double initialZoom;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Function(GoogleMapController) onMapCreated;

  /// Whether the current user is the owner of this trip.
  /// When false, the user's current location (blue dot) is hidden
  /// to protect the viewer's privacy.
  final bool isOwner;

  /// Whether map gestures (scroll, zoom, pan) are enabled.
  /// Set to false when overlays are open to prevent touch events
  /// from propagating to the map on mobile web.
  final bool gesturesEnabled;

  /// The currently selected location to show in the custom info window.
  final TripLocation? selectedLocation;

  /// Callback to close the custom info window.
  final VoidCallback? onInfoWindowClosed;

  /// Callback when the map background is tapped (not a marker).
  final VoidCallback? onMapTap;

  const TripMapView({
    super.key,
    required this.initialLocation,
    required this.initialZoom,
    required this.markers,
    required this.polylines,
    required this.onMapCreated,
    this.isOwner = false,
    this.gesturesEnabled = true,
    this.selectedLocation,
    this.onInfoWindowClosed,
    this.onMapTap,
  });

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView> {
  bool _hasError = false;
  String? _errorMessage;
  bool _isMapReady = false;
  GoogleMapController? _controller;

  /// Screen position of the selected marker (relative to the map widget).
  Offset? _markerScreenPosition;

  @override
  void didUpdateWidget(covariant TripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When a new location is selected, compute its screen position.
    if (widget.selectedLocation != null &&
        widget.selectedLocation != oldWidget.selectedLocation) {
      _updateMarkerScreenPosition();
    }
    // When selection is cleared, clear the cached position.
    if (widget.selectedLocation == null) {
      _markerScreenPosition = null;
    }
  }

  Future<void> _updateMarkerScreenPosition() async {
    final controller = _controller;
    final loc = widget.selectedLocation;
    if (controller == null || loc == null) return;

    try {
      final screenCoord = await controller.getScreenCoordinate(
        LatLng(loc.latitude, loc.longitude),
      );
      if (mounted && widget.selectedLocation == loc) {
        setState(() {
          // On native platforms, getScreenCoordinate returns physical pixels
          // so we must convert to logical pixels using devicePixelRatio.
          // On web, it already returns CSS (logical) pixels, so no conversion
          // is needed — dividing again would place the bubble incorrectly
          // (especially visible on mobile web with high DPR).
          if (kIsWeb) {
            _markerScreenPosition = Offset(
              screenCoord.x.toDouble(),
              screenCoord.y.toDouble(),
            );
          } else {
            final ratio = MediaQuery.of(context).devicePixelRatio;
            _markerScreenPosition = Offset(
              screenCoord.x / ratio,
              screenCoord.y / ratio,
            );
          }
        });
      }
    } catch (_) {
      // Silently fail — bubble won't be positioned.
    }
  }

  @override
  void initState() {
    super.initState();
    // Give the map a moment to initialize
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_isMapReady && !_hasError) {
        // Map should have initialized by now
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4)),
                const SizedBox(height: 16),
                Text(
                  'Map Loading Error',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Failed to load Google Maps',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Coordinates: ${widget.initialLocation.latitude.toStringAsFixed(4)}, ${widget.initialLocation.longitude.toStringAsFixed(4)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5)),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _errorMessage = null;
                      _isMapReady = false;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.initialLocation,
            zoom: widget.initialZoom,
          ),
          markers: widget.markers,
          polylines: widget.polylines,
          onMapCreated: (controller) {
            _controller = controller;
            try {
              setState(() {
                _isMapReady = true;
              });
              widget.onMapCreated(controller);
            } catch (e) {
              setState(() {
                _hasError = true;
                _errorMessage = 'Map initialization failed: ${e.toString()}';
              });
              debugPrint('Map creation error: $e');
            }
          },
          onTap: (_) {
            // Dismiss info window when tapping on the map background.
            widget.onMapTap?.call();
          },
          onCameraMove: (_) {
            // Update bubble position when the camera moves so it tracks.
            if (widget.selectedLocation != null) {
              _updateMarkerScreenPosition();
            }
          },
          myLocationButtonEnabled: widget.isOwner,
          myLocationEnabled: widget.isOwner,
          mapToolbarEnabled: false,
          zoomControlsEnabled: true,
          scrollGesturesEnabled: widget.gesturesEnabled,
          zoomGesturesEnabled: widget.gesturesEnabled,
          tiltGesturesEnabled: widget.gesturesEnabled,
          rotateGesturesEnabled: widget.gesturesEnabled,
        ),
        // Loading indicator while map initializes
        if (!_isMapReady && !_hasError)
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading map...',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Location: ${widget.initialLocation.latitude.toStringAsFixed(4)}, ${widget.initialLocation.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          ),
        // Custom info window bubble positioned above the marker
        if (widget.selectedLocation != null &&
            widget.onInfoWindowClosed != null &&
            _markerScreenPosition != null)
          Positioned(
            // Place the bubble so its bottom-center is above the marker pin.
            // Offset upward by ~48px to clear the marker icon.
            left: _markerScreenPosition!.dx - 130,
            top: _markerScreenPosition!.dy - 48,
            child: Transform.translate(
              offset: const Offset(0, -100),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomInfoWindow(
                    location: widget.selectedLocation!,
                    onClose: widget.onInfoWindowClosed!,
                  ),
                  // Small triangle/arrow pointing down
                  CustomPaint(
                    size: const Size(16, 8),
                    painter: _TrianglePainter(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Paints a small downward-pointing triangle used as the bubble arrow.
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
