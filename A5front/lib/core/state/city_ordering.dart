import 'dart:math' as math;
import 'city_coordinates.dart';

/// The first city mentioned in the title is the anchor. Close distances share a
/// 10 km band and use Korean name order, so almost equal results stay stable.
String? itineraryAnchorCity(
  String title,
  Iterable<String> cities,
  List<String> selected,
) {
  final matches = cities.where((c) => title.contains(c)).toList()
    ..sort((a, b) => title.indexOf(a).compareTo(title.indexOf(b)));
  return matches.firstOrNull ?? selected.firstOrNull;
}

double cityDistance(String? anchor, String city) {
  final a = cityCoordinates[anchor], b = cityCoordinates[city];
  if (a == null || b == null) return double.infinity;
  double rad(double v) => v * math.pi / 180;
  final lat = rad(b[0] - a[0]), lng = rad(b[1] - a[1]);
  final h =
      math.pow(math.sin(lat / 2), 2) +
      math.cos(rad(a[0])) *
          math.cos(rad(b[0])) *
          math.pow(math.sin(lng / 2), 2);
  return 6371 * 2 * math.asin(math.sqrt(h.clamp(0, 1)));
}

int compareCities(String? anchor, String a, String b) {
  if (a == anchor) return b == anchor ? 0 : -1;
  if (b == anchor) return 1;
  final da = cityDistance(anchor, a), db = cityDistance(anchor, b);
  if (da.isFinite && db.isFinite) {
    final band = (da / 10).round().compareTo((db / 10).round());
    if (band != 0) return band;
  } else if (da.isFinite != db.isFinite) {
    return da.isFinite ? -1 : 1;
  }
  return a.compareTo(b);
}
