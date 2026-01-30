import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  double? temperature;
  double? humidity;
  double? airQualityRaw;
  String? aqiStatus;
  Color? statusColor;
  IconData? statusIcon;

  List<WeightedLatLng> heatmapPoints = [];
  LatLng? currentLocation;
  Timer? _refreshTimer;
  bool isLoading = true;

  final Completer<GoogleMapController> _mapController = Completer();
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(21.1458, 79.0882),
    zoom: 12,
  );

  bool hasLocation = false;

  static const String _mapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#0a1929"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#8ec3ff"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#0a1929"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#1e3a5f"}]},
    {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#a8daff"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#001e3c"}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#0d2847"}]},
    {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#0a3d2a"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _init();
  }

  Future<void> _init() async {
    await _getCurrentLocation();
    await _fetchSensorData();

    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _fetchSensorData();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permission denied', Icons.location_off);
          setState(() => isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Please enable location in settings', Icons.settings);
        setState(() => isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        _initialPosition = CameraPosition(
          target: currentLocation!,
          zoom: 13,
        );
        hasLocation = true;
      });

      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(_initialPosition),
      );

      debugPrint('📍 Location: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('❌ Location error: $e');
      setState(() {
        isLoading = false;
        hasLocation = false;
      });
    }
  }

  Future<void> _fetchSensorData() async {
    try {
      final uri = Uri.parse('http://10.118.211.144/sensor');
      debugPrint('🔄 Fetching sensor data...');

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        final temp = (data['temperature'] as num?)?.toDouble();
        final hum = (data['humidity'] as num?)?.toDouble();
        final aqRaw = (data['air_quality_raw'] as num?)?.toDouble() ?? 0.0;

        setState(() {
          temperature = temp;
          humidity = hum;
          airQualityRaw = aqRaw;
          _updateAqiStatus(aqRaw);
          heatmapPoints = _generateHeatmapPoints(temp, hum, aqRaw);
          isLoading = false;
        });

        _animController.forward(from: 0.0);
        debugPrint('✅ Data: temp=$temp, hum=$hum, aqi=$aqRaw');
      } else {
        _showSnackBar('Server error ${response.statusCode}', Icons.error);
      }
    } on TimeoutException {
      _showSnackBar('ESP32 not responding', Icons.wifi_off);
    } catch (e) {
      debugPrint('❌ Fetch error: $e');
      _showSnackBar('Connection failed', Icons.cloud_off);
    }
  }

  void _updateAqiStatus(double rawValue) {
    if (rawValue < 100) {
      aqiStatus = 'Excellent';
      statusColor = const Color(0xFF00E676);
      statusIcon = Icons.sentiment_very_satisfied_rounded;
    } else if (rawValue < 200) {
      aqiStatus = 'Good';
      statusColor = const Color(0xFF76FF03);
      statusIcon = Icons.sentiment_satisfied_rounded;
    } else if (rawValue < 300) {
      aqiStatus = 'Moderate';
      statusColor = const Color(0xFFFFEA00);
      statusIcon = Icons.sentiment_neutral_rounded;
    } else if (rawValue < 400) {
      aqiStatus = 'Poor';
      statusColor = const Color(0xFFFF9100);
      statusIcon = Icons.masks_rounded;
    } else if (rawValue < 500) {
      aqiStatus = 'Unhealthy';
      statusColor = const Color(0xFFFF3D00);
      statusIcon = Icons.warning_rounded;
    } else {
      aqiStatus = 'Hazardous';
      statusColor = const Color(0xFFD500F9);
      statusIcon = Icons.dangerous_rounded;
    }
  }

  List<WeightedLatLng> _generateHeatmapPoints(
      double? temp,
      double? hum,
      double aqi,
      ) {
    final List<WeightedLatLng> points = [];

    if (currentLocation == null) return points;

    final double centerLat = currentLocation!.latitude;
    final double centerLng = currentLocation!.longitude;

    // Calculate composite weight from all factors
    double tempWeight = 0.33;
    double humWeight = 0.33;
    double aqiWeight = 0.34;

    if (temp != null) {
      // Higher temp = more intensity (normalize 0-50°C to 0-1)
      tempWeight = ((temp - 0) / 50).clamp(0.0, 1.0) * 0.33;
    }

    if (hum != null) {
      // Higher humidity = more intensity (normalize 0-100% to 0-1)
      humWeight = (hum / 100).clamp(0.0, 1.0) * 0.33;
    }

    // Higher AQI = more intensity (normalize 0-1000 to 0-1)
    aqiWeight = (aqi / 1000).clamp(0.0, 1.0) * 0.34;

    final double baseWeight = tempWeight + humWeight + aqiWeight;

    // Create multiple concentric circles for better spread
    final List<double> radii = [0.002, 0.004, 0.006, 0.008, 0.01, 0.012, 0.015];

    for (var radius in radii) {
      final int pointsInCircle = (radius * 10000).toInt();

      for (int i = 0; i < pointsInCircle; i++) {
        final double angle = (i * 2 * math.pi) / pointsInCircle;
        final double randomFactor = 0.8 + (math.Random().nextDouble() * 0.4);
        final double r = radius * randomFactor;

        final double lat = centerLat + r * math.cos(angle);
        final double lng = centerLng + r * math.sin(angle);

        // Distance-based falloff
        final double dist = math.sqrt(
          math.pow(lat - centerLat, 2) + math.pow(lng - centerLng, 2),
        ) / 0.015;

        final double falloff = math.exp(-dist * dist * 3);
        final double weight = (baseWeight * falloff).clamp(0.1, 1.0);

        if (weight > 0.15) {
          points.add(WeightedLatLng(LatLng(lat, lng), weight: weight));
        }
      }
    }

    debugPrint('🗺️ Generated ${points.length} heatmap points (weight: ${baseWeight.toStringAsFixed(2)})');
    return points;
  }

  Set<Heatmap> get _heatmaps {
    if (heatmapPoints.isEmpty) return {};

    // Determine gradient colors based on predominant factor
    List<HeatmapGradientColor> gradientColors;

    final aqiNorm = (airQualityRaw ?? 0) / 1000;
    final tempNorm = (temperature ?? 25) / 50;
    final humNorm = (humidity ?? 50) / 100;

    if (aqiNorm > tempNorm && aqiNorm > humNorm) {
      // Air quality dominant - red/purple gradient
      gradientColors = [
        HeatmapGradientColor(Colors.transparent, 0.0),
        HeatmapGradientColor(const Color(0xFF00E676).withValues(alpha: 0.4), 0.15),
        HeatmapGradientColor(const Color(0xFFFFEA00).withValues(alpha: 0.6), 0.35),
        HeatmapGradientColor(const Color(0xFFFF9100).withValues(alpha: 0.75), 0.55),
        HeatmapGradientColor(const Color(0xFFFF3D00).withValues(alpha: 0.85), 0.75),
        HeatmapGradientColor(const Color(0xFFD500F9).withValues(alpha: 0.95), 1.0),
      ];
    } else if (tempNorm > humNorm) {
      // Temperature dominant - warm gradient
      gradientColors = [
        HeatmapGradientColor(Colors.transparent, 0.0),
        HeatmapGradientColor(const Color(0xFF00BCD4).withValues(alpha: 0.4), 0.2),
        HeatmapGradientColor(const Color(0xFF4CAF50).withValues(alpha: 0.6), 0.4),
        HeatmapGradientColor(const Color(0xFFFFC107).withValues(alpha: 0.75), 0.6),
        HeatmapGradientColor(const Color(0xFFFF5722).withValues(alpha: 0.85), 0.8),
        HeatmapGradientColor(const Color(0xFFE91E63).withValues(alpha: 0.95), 1.0),
      ];
    } else {
      // Humidity dominant - blue/cyan gradient
      gradientColors = [
        HeatmapGradientColor(Colors.transparent, 0.0),
        HeatmapGradientColor(const Color(0xFF2196F3).withValues(alpha: 0.4), 0.2),
        HeatmapGradientColor(const Color(0xFF03A9F4).withValues(alpha: 0.6), 0.4),
        HeatmapGradientColor(const Color(0xFF00BCD4).withValues(alpha: 0.75), 0.6),
        HeatmapGradientColor(const Color(0xFF009688).withValues(alpha: 0.85), 0.8),
        HeatmapGradientColor(const Color(0xFF4CAF50).withValues(alpha: 0.95), 1.0),
      ];
    }

    return {
      Heatmap(
        heatmapId: const HeatmapId('environmental_data'),
        data: heatmapPoints,
        radius: HeatmapRadius.fromPixels(35),
        gradient: HeatmapGradient(gradientColors),
        opacity: 0.75,
        dissipating: true,
      ),
    };
  }

  void _showSnackBar(String message, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.eco_rounded, color: Color(0xFF00E676), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Breath Map',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (GoogleMapController controller) async {
              _mapController.complete(controller);
              try {
                await controller.setMapStyle(_mapStyle);
              } catch (e) {
                debugPrint('Map style error: $e');
              }
            },
            mapType: MapType.normal,
            heatmaps: _heatmaps,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            padding: const EdgeInsets.only(top: 120, bottom: 280),
          ),

          // Data Card
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Main Data Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: isLoading
                      ? _buildLoadingCard()
                      : hasLocation
                      ? _buildDataCard()
                      : _buildNoLocationCard(),
                ),

                const Spacer(),

                // Bottom Info Panel
                _buildBottomPanel(),
              ],
            ),
          ),

          // Floating Action Buttons
          Positioned(
            right: 16,
            bottom: 300,
            child: Column(
              children: [
                _buildFloatingButton(
                  icon: Icons.my_location_rounded,
                  onPressed: _getCurrentLocation,
                  color: const Color(0xFF2196F3),
                ),
                const SizedBox(height: 12),
                _buildFloatingButton(
                  icon: Icons.refresh_rounded,
                  onPressed: _fetchSensorData,
                  color: const Color(0xFF00E676),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Color(0xFF00E676),
                  strokeWidth: 3,
                ),
                SizedBox(height: 16),
                Text(
                  'Loading environmental data...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Temperature and Humidity Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.thermostat_rounded,
                          label: 'Temperature',
                          value: temperature != null
                              ? '${temperature!.toStringAsFixed(1)}°C'
                              : '–',
                          color: const Color(0xFFFF6B6B),
                          iconColor: const Color(0xFFFF8A80),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.water_drop_rounded,
                          label: 'Humidity',
                          value: humidity != null
                              ? '${humidity!.toStringAsFixed(0)}%'
                              : '–',
                          color: const Color(0xFF4FC3F7),
                          iconColor: const Color(0xFF81D4FA),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Air Quality Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (statusColor ?? Colors.grey).withValues(alpha: 0.15),
                          (statusColor ?? Colors.grey).withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: (statusColor ?? Colors.grey).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: (statusColor ?? Colors.grey)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            statusIcon ?? Icons.air_rounded,
                            color: statusColor ?? Colors.grey,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Air Quality Index',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                aqiStatus ?? 'Unknown',
                                style: TextStyle(
                                  color: statusColor ?? Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              if (airQualityRaw != null)
                                Text(
                                  'Raw: ${airQualityRaw!.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoLocationCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_disabled_rounded, color: Colors.orange, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Location unavailable',
                  style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Using fallback view.\nTap the location button to try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1E293B).withValues(alpha: 0.95),
                const Color(0xFF0F172A).withValues(alpha: 0.98),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoItem(
                    icon: Icons.location_on_rounded,
                    label: 'Live Location',
                    value: currentLocation != null ? 'Active' : 'Searching...',
                  ),
                  _buildInfoItem(
                    icon: Icons.update_rounded,
                    label: 'Auto Refresh',
                    value: '8 sec',
                  ),
                  _buildInfoItem(
                    icon: Icons.network_check_rounded,
                    label: 'ESP32 Status',
                    value: airQualityRaw != null ? 'Connected' : 'Offline',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF00E676), size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}