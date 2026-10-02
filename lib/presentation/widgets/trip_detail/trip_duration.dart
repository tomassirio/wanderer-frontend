import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';

/// When the trip started and (if it did) ended: the "Trip started" /
/// "Trip finished" updates first, then the trip's dates, then its first /
/// last update. `start` is null for a trip that hasn't started.
({DateTime? start, DateTime? end}) tripSpan(
    Trip trip, List<TripLocation> updates) {
  DateTime? at(TripUpdateType t) =>
      updates.where((u) => u.updateType == t).firstOrNull?.timestamp;
  final times = updates.map((u) => u.timestamp).toList()..sort();
  if (trip.status == TripStatus.created) return (start: null, end: null);
  final start =
      at(TripUpdateType.tripStarted) ?? trip.startDate ?? times.firstOrNull;
  final end = trip.status == TripStatus.finished
      ? at(TripUpdateType.tripEnded) ?? trip.endDate ?? times.lastOrNull
      : null;
  return (start: start, end: end);
}

/// "2h 05m 09s" for single-day trips, "3 days" for multi-day ones, "—"
/// before the start.
String tripDurationLabel(
    AppLocalizations l10n, Trip trip, List<TripLocation> updates,
    {DateTime? now}) {
  final span = tripSpan(trip, updates);
  final start = span.start;
  if (start == null) return '—';
  final end = span.end ?? now ?? DateTime.now();
  final d =
      end.difference(start).isNegative ? Duration.zero : end.difference(start);
  if (trip.tripModality == TripModality.multiDay) {
    return l10n.daysCount(d.inDays + 1);
  }
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.inHours}h ${two(d.inMinutes % 60)}m ${two(d.inSeconds % 60)}s';
}

/// [tripDurationLabel] that ticks every second while a single-day trip runs.
class TripDurationText extends StatefulWidget {
  final Trip trip;
  final List<TripLocation> updates;
  final TextStyle? style;
  const TripDurationText(
      {super.key, required this.trip, required this.updates, this.style});

  @override
  State<TripDurationText> createState() => _TripDurationTextState();
}

class _TripDurationTextState extends State<TripDurationText> {
  Timer? _timer;

  bool get _ticking {
    if (widget.trip.tripModality == TripModality.multiDay) return false;
    final span = tripSpan(widget.trip, widget.updates);
    return span.start != null && span.end == null;
  }

  void _sync() {
    if (_ticking) {
      _timer ??= Timer.periodic(
          const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(TripDurationText old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(tripDurationLabel(context.l10n, widget.trip, widget.updates),
          maxLines: 1, overflow: TextOverflow.ellipsis, style: widget.style);
}
