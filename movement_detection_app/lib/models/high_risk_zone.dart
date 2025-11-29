import 'package:latlong2/latlong.dart';

class HighRiskZone {
  final String id;
  final String name;
  final String description;
  final LatLng center;
  final double radiusMeters;
  final RiskLevel riskLevel;
  final String? imageUrl;
  final DateTime? lastIncident;

  HighRiskZone({
    required this.id,
    required this.name,
    required this.description,
    required this.center,
    required this.radiusMeters,
    required this.riskLevel,
    this.imageUrl,
    this.lastIncident,
  });

  factory HighRiskZone.fromJson(Map<String, dynamic> json) {
    return HighRiskZone(
      id: json['id'].toString(),
      name: json['name'],
      description: json['description'],
      center: LatLng(json['latitude'], json['longitude']),
      radiusMeters: json['radius_meters'].toDouble(),
      riskLevel: RiskLevel.values.firstWhere(
            (e) => e.toString() == 'RiskLevel.${json['risk_level']}',
        orElse: () => RiskLevel.medium,
      ),
      imageUrl: json['image_url'],
      lastIncident: json['last_incident'] != null
          ? DateTime.parse(json['last_incident'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': center.latitude,
      'longitude': center.longitude,
      'radius_meters': radiusMeters,
      'risk_level': riskLevel.toString().split('.').last,
      'image_url': imageUrl,
      'last_incident': lastIncident?.toIso8601String(),
    };
  }
}

enum RiskLevel {
  low,      // Yellow - Be cautious
  medium,   // Orange - Stay alert
  high,     // Red - Dangerous area
  extreme,  // Dark red - Avoid at all costs
}