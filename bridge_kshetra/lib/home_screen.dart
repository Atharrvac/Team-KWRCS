import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

// ==================== DATA MODELS ====================

class SensorData {
  final double temperature;
  final double humidity;
  final double airQualityRaw;
  final DateTime timestamp;

  SensorData({
    required this.temperature,
    required this.humidity,
    required this.airQualityRaw,
    required this.timestamp,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      airQualityRaw: (json['air_quality_raw'] as num).toDouble(),
      timestamp: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SensorData &&
              runtimeType == other.runtimeType &&
              temperature == other.temperature &&
              humidity == other.humidity &&
              airQualityRaw == other.airQualityRaw;

  @override
  int get hashCode => Object.hash(temperature, humidity, airQualityRaw);
}

class NearbySensorData {
  final String id;
  final double temp;
  final double humidity;
  final double airQuality;
  final double lat;
  final double lang;
  final DateTime timestamp;
  final double distanceKm;

  NearbySensorData({
    required this.id,
    required this.temp,
    required this.humidity,
    required this.airQuality,
    required this.lat,
    required this.lang,
    required this.timestamp,
    required this.distanceKm,
  });

  factory NearbySensorData.fromJson(Map<String, dynamic> json) {
    return NearbySensorData(
      id: json['id'] as String,
      temp: (json['temp'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      airQuality: (json['air_quality'] as num).toDouble(),
      lat: (json['lat'] as num).toDouble(),
      lang: (json['lang'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      distanceKm: (json['distance_km'] as num).toDouble(),
    );
  }
}

class AQIStatus {
  final String status;
  final Color color;
  final IconData icon;

  const AQIStatus({
    required this.status,
    required this.color,
    required this.icon,
  });
}

// ==================== API SERVICE ====================

class SensorApiService {
  static const String baseUrl = 'http://10.118.211.126:5000/api/sensor';

  // Post sensor data to queue (using current mobile location)
  static Future<Map<String, dynamic>?> postSensorData({
    required double temp,
    required double humidity,
    required double airQuality,
    required double lat,
    required double lang,
  }) async {
    try {
      debugPrint('📤 Attempting to post sensor data...');
      debugPrint('   Temp: $temp, Humidity: $humidity, AQI: $airQuality');
      debugPrint('   Location: $lat, $lang');

      final requestBody = {
        'temp': temp.toString(),
        'humidity': humidity.toString(),
        'air_quality': airQuality.toStringAsFixed(0),
        'lat': lat.toStringAsFixed(6),
        'lang': lang.toStringAsFixed(6),
      };

      debugPrint('📤 Request body: ${json.encode(requestBody)}');

      final response = await http
          .post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      )
          .timeout(const Duration(seconds: 8));

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("✅ Data Uploaded Successfully!");
        debugPrint("   Location: ${lat.toStringAsFixed(6)}, ${lang.toStringAsFixed(6)}");
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        debugPrint("   Response: $responseData");
        return responseData;
      }
      debugPrint('❌ Post sensor data failed: ${response.statusCode}');
      debugPrint('❌ Response: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('❌ Post sensor data error: $e');
      return null;
    }
  }

  // Get nearby sensors (using map camera center)
  static Future<List<NearbySensorData>> getNearbySensors({
    required double lat,
    required double lang,
    required String distance,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/nearby'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'lat': lat.toStringAsFixed(6),
          'lang': lang.toStringAsFixed(6),
          'distance': distance,
        }),
      )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final dataList = data['data'] as List;
        return dataList
            .map((item) => NearbySensorData.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      debugPrint('❌ Get nearby sensors failed: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('❌ Get nearby sensors error: $e');
      return [];
    }
  }
}

// ==================== HOME SCREEN ====================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // State variables
  SensorData? _sensorData;
  AQIStatus? _aqiStatus;
  LatLng? _userLocation; // Mobile location = Sensor location
  LatLng? _currentMapCenter; // Map camera center for nearby API
  double _currentZoomLevel = 15.0;
  List<NearbySensorData> _nearbySensors = [];

  bool _isLoadingLocation = true;
  bool _isLoadingSensorData = true;
  bool _hasLocationPermission = false;

  Timer? _refreshTimer;
  Timer? _debounceTimer;
  final Completer<GoogleMapController> _mapController = Completer();
  late AnimationController _animController;

  // Track last posted data to avoid duplicate posts
  DateTime? _lastPostTime;
  SensorData? _lastPostedData;

  // Constants
  static const String _espSensorUrl = 'http://10.118.211.144/sensor';
  static const int _refreshIntervalSeconds = 3;

  CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(21.1458, 79.0882),
    zoom: 15,
  );

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
    _initAnimations();
    _initializeApp();
  }

  void _initAnimations() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  Future<void> _initializeApp() async {
    await _getCurrentLocation();
    await _fetchESP32SensorData();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: _refreshIntervalSeconds),
          (_) => _fetchESP32SensorData(),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _refreshTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ==================== LOCATION ====================

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
            _hasLocationPermission = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;

      final userLoc = LatLng(position.latitude, position.longitude);
      debugPrint("📍 User Location Updated: ${userLoc.latitude}, ${userLoc.longitude}");

      setState(() {
        _userLocation = userLoc;
        _currentMapCenter = userLoc;
        _hasLocationPermission = true;
        _isLoadingLocation = false;
      });

      // Update initial position
      _initialPosition = CameraPosition(
        target: userLoc,
        zoom: 15,
      );

      // Move camera to user location if map is ready
      if (_mapController.isCompleted) {
        final controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newCameraPosition(_initialPosition));
      }

      // Fetch nearby sensors at user's location
      _fetchNearbySensors(userLoc, _currentZoomLevel);

    } catch (e) {
      debugPrint('❌ Location error: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _hasLocationPermission = false;
        });
      }
    }
  }

  // ==================== ESP32 SENSOR DATA ====================

  Future<void> _fetchESP32SensorData() async {
    try {
      debugPrint('🔄 Fetching ESP32 sensor data...');

      final response = await http
          .get(Uri.parse(_espSensorUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      debugPrint('📥 ESP32 Response: $data');

      final newSensorData = SensorData.fromJson(data);
      debugPrint('✅ ESP32 Data Parsed: Temp=${newSensorData.temperature}°C, Humidity=${newSensorData.humidity}%, AQI=${newSensorData.airQualityRaw}');

      // CRITICAL FIX: Always post to API when we have valid location and sensor data
      // Don't skip posting even if data hasn't changed
      if (_userLocation != null) {
        final now = DateTime.now();

        // Post to API - allow posting every refresh cycle
        // This ensures data is continuously saved to the database
        debugPrint('🚀 Posting to API with current location...');

        final result = await SensorApiService.postSensorData(
          temp: newSensorData.temperature,
          humidity: newSensorData.humidity,
          airQuality: newSensorData.airQualityRaw,
          lat: _userLocation!.latitude,
          lang: _userLocation!.longitude,
        );

        if (result != null) {
          debugPrint('✅ Successfully posted to API!');
          if (result.containsKey('queueSize')) {
            debugPrint('   Queue size: ${result['queueSize']}');
          }
          if (result.containsKey('id')) {
            debugPrint('   Record ID: ${result['id']}');
          }
          _lastPostTime = now;
          _lastPostedData = newSensorData;
        } else {
          debugPrint('❌ Failed to post to API');
        }
      } else {
        debugPrint('⚠️ Cannot post to API: User location not available');
      }

      if (!mounted) return;

      // Update UI state
      final aqiStatus = _calculateAQIStatus(newSensorData.airQualityRaw);

      setState(() {
        _sensorData = newSensorData;
        _aqiStatus = aqiStatus;
        _isLoadingSensorData = false;
      });

      _animController.forward(from: 0.0);

    } on TimeoutException {
      debugPrint('⏱️ ESP32 timeout - sensor might be offline');
      if (mounted) {
        setState(() {
          _isLoadingSensorData = false;
        });
      }
    } catch (e) {
      debugPrint('❌ ESP32 error: $e');
      if (mounted) {
        setState(() {
          _isLoadingSensorData = false;
        });
      }
    }
  }

  // ==================== NEARBY SENSORS ====================

  // Calculate distance based on zoom level
  String _getDistanceFromZoom(double zoom) {
    // Zoom level to approximate visible radius mapping
    if (zoom >= 16) {
      return '200m';
    } else if (zoom >= 15) {
      return '500m';
    } else if (zoom >= 14) {
      return '1000m';
    } else if (zoom >= 13) {
      return '2000m';
    } else if (zoom >= 12) {
      return '5000m';
    } else {
      return '10000m';
    }
  }

  Future<void> _fetchNearbySensors(LatLng center, double zoom) async {
    try {
      final distance = _getDistanceFromZoom(zoom);

      final sensors = await SensorApiService.getNearbySensors(
        lat: center.latitude,
        lang: center.longitude,
        distance: distance,
      );

      if (!mounted) return;

      setState(() {
        _nearbySensors = sensors;
      });

      debugPrint('📍 Fetched ${sensors.length} nearby sensors (${distance} radius)');
    } catch (e) {
      debugPrint('❌ Nearby sensors error: $e');
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentMapCenter = position.target;
    _currentZoomLevel = position.zoom;

    // Debounce camera move to avoid too many API calls
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (_currentMapCenter != null) {
        _fetchNearbySensors(_currentMapCenter!, _currentZoomLevel);
      }
    });
  }

  // ==================== CALCULATIONS ====================

  AQIStatus _calculateAQIStatus(double rawValue) {
    if (rawValue < 100) {
      return const AQIStatus(
        status: 'Excellent',
        color: Color(0xFF00E676),
        icon: Icons.sentiment_very_satisfied_rounded,
      );
    } else if (rawValue < 200) {
      return const AQIStatus(
        status: 'Good',
        color: Color(0xFF76FF03),
        icon: Icons.sentiment_satisfied_rounded,
      );
    } else if (rawValue < 300) {
      return const AQIStatus(
        status: 'Moderate',
        color: Color(0xFFFFEA00),
        icon: Icons.sentiment_neutral_rounded,
      );
    } else if (rawValue < 400) {
      return const AQIStatus(
        status: 'Poor',
        color: Color(0xFFFF9100),
        icon: Icons.masks_rounded,
      );
    } else if (rawValue < 500) {
      return const AQIStatus(
        status: 'Unhealthy',
        color: Color(0xFFFF3D00),
        icon: Icons.warning_rounded,
      );
    } else {
      return const AQIStatus(
        status: 'Hazardous',
        color: Color(0xFFD500F9),
        icon: Icons.dangerous_rounded,
      );
    }
  }

  List<WeightedLatLng> _generateHeatmapForSensor(NearbySensorData sensor) {
    final List<WeightedLatLng> points = [];

    // Calculate weight
    final tempNorm = (sensor.temp / 50.0).clamp(0.0, 1.0);
    final humNorm = (sensor.humidity / 100.0).clamp(0.0, 1.0);
    final aqiNorm = (sensor.airQuality / 1000.0).clamp(0.0, 1.0);
    final baseWeight = (tempNorm * 0.2 + humNorm * 0.2 + aqiNorm * 0.6).clamp(0.3, 1.0);

    // 50m radius ≈ 0.00045 degrees
    const radiusInDegrees = 0.00045;
    final circles = [0.3, 0.5, 0.7, 0.9, 1.0];

    for (var factor in circles) {
      final radius = radiusInDegrees * factor;
      final pointsInCircle = (factor * 20).toInt().clamp(8, 25);

      for (int i = 0; i < pointsInCircle; i++) {
        final angle = (i * 2 * math.pi) / pointsInCircle;
        final lat = sensor.lat + radius * math.cos(angle);
        final lng = sensor.lang + radius * math.sin(angle);

        final falloff = math.exp(-factor * factor * 2);
        final weight = (baseWeight * falloff).clamp(0.2, 1.0);

        points.add(WeightedLatLng(LatLng(lat, lng), weight: weight));
      }
    }

    // Center point
    points.add(WeightedLatLng(LatLng(sensor.lat, sensor.lang), weight: baseWeight));

    return points;
  }

  // Generate heatmap for MY sensor (current location)
  List<WeightedLatLng> _generateHeatmapForMySensor() {
    if (_userLocation == null || _sensorData == null) return [];

    final List<WeightedLatLng> points = [];

    // Calculate weight based on current sensor data
    final tempNorm = (_sensorData!.temperature / 50.0).clamp(0.0, 1.0);
    final humNorm = (_sensorData!.humidity / 100.0).clamp(0.0, 1.0);
    final aqiNorm = (_sensorData!.airQualityRaw / 1000.0).clamp(0.0, 1.0);
    final baseWeight = (tempNorm * 0.2 + humNorm * 0.2 + aqiNorm * 0.6).clamp(0.3, 1.0);

    // 50m radius ≈ 0.00045 degrees
    const radiusInDegrees = 0.00045;
    final circles = [0.3, 0.5, 0.7, 0.9, 1.0];

    for (var factor in circles) {
      final radius = radiusInDegrees * factor;
      final pointsInCircle = (factor * 20).toInt().clamp(8, 25);

      for (int i = 0; i < pointsInCircle; i++) {
        final angle = (i * 2 * math.pi) / pointsInCircle;
        final lat = _userLocation!.latitude + radius * math.cos(angle);
        final lng = _userLocation!.longitude + radius * math.sin(angle);

        final falloff = math.exp(-factor * factor * 2);
        final weight = (baseWeight * falloff).clamp(0.2, 1.0);

        points.add(WeightedLatLng(LatLng(lat, lng), weight: weight));
      }
    }

    // Center point
    points.add(WeightedLatLng(_userLocation!, weight: baseWeight));

    return points;
  }

  // Get gradient colors based on normalized value
  List<HeatmapGradientColor> _getGradientColors(double tempNorm, double humNorm, double aqiNorm) {
    if (aqiNorm > tempNorm && aqiNorm > humNorm) {
      // AQI dominant - use air quality gradient
      return [
        HeatmapGradientColor(Colors.transparent, 0.0),
        HeatmapGradientColor(const Color(0xFF00E676).withValues(alpha: 0.4), 0.2),
        HeatmapGradientColor(const Color(0xFFFFEA00).withValues(alpha: 0.6), 0.4),
        HeatmapGradientColor(const Color(0xFFFF9100).withValues(alpha: 0.75), 0.6),
        HeatmapGradientColor(const Color(0xFFFF3D00).withValues(alpha: 0.85), 0.8),
        HeatmapGradientColor(const Color(0xFFD500F9).withValues(alpha: 0.95), 1.0),
      ];
    } else if (tempNorm > humNorm) {
      // Temperature dominant
      return [
        HeatmapGradientColor(Colors.transparent, 0.0),
        HeatmapGradientColor(const Color(0xFF4CAF50).withValues(alpha: 0.4), 0.2),
        HeatmapGradientColor(const Color(0xFFFFEB3B).withValues(alpha: 0.6), 0.4),
        HeatmapGradientColor(const Color(0xFFFF9800).withValues(alpha: 0.75), 0.6),
        HeatmapGradientColor(const Color(0xFFFF5722).withValues(alpha: 0.85), 0.8),
        HeatmapGradientColor(const Color(0xFFE91E63).withValues(alpha: 0.95), 1.0),
      ];
    } else {
      // Humidity dominant
      return [
        HeatmapGradientColor(Colors.transparent, 0.0),
        HeatmapGradientColor(const Color(0xFF81D4FA).withValues(alpha: 0.4), 0.2),
        HeatmapGradientColor(const Color(0xFF4FC3F7).withValues(alpha: 0.6), 0.4),
        HeatmapGradientColor(const Color(0xFF29B6F6).withValues(alpha: 0.75), 0.6),
        HeatmapGradientColor(const Color(0xFF039BE5).withValues(alpha: 0.85), 0.8),
        HeatmapGradientColor(const Color(0xFF0277BD).withValues(alpha: 0.95), 1.0),
      ];
    }
  }

  Set<Heatmap> get _heatmaps {
    final Set<Heatmap> heatmaps = {};

    // FIRST: Add MY sensor heatmap (current location)
    if (_userLocation != null && _sensorData != null) {
      final myPoints = _generateHeatmapForMySensor();

      if (myPoints.isNotEmpty) {
        final tempNorm = _sensorData!.temperature / 50;
        final humNorm = _sensorData!.humidity / 100;
        final aqiNorm = _sensorData!.airQualityRaw / 1000;

        final gradient = _getGradientColors(tempNorm, humNorm, aqiNorm);

        heatmaps.add(
          Heatmap(
            heatmapId: const HeatmapId('my_sensor'),
            data: myPoints,
            radius: HeatmapRadius.fromPixels(38),
            gradient: HeatmapGradient(gradient),
            opacity: 0.75,
            dissipating: true,
          ),
        );
        debugPrint('🔥 Added MY sensor heatmap at ${_userLocation!.latitude}, ${_userLocation!.longitude}');
      }
    }

    // SECOND: Add nearby sensors heatmaps
    for (var sensor in _nearbySensors) {
      final points = _generateHeatmapForSensor(sensor);

      // Determine gradient
      final tempNorm = sensor.temp / 50;
      final humNorm = sensor.humidity / 100;
      final aqiNorm = sensor.airQuality / 1000;

      final gradient = _getGradientColors(tempNorm, humNorm, aqiNorm);

      heatmaps.add(
        Heatmap(
          heatmapId: HeatmapId('sensor_${sensor.id}'),
          data: points,
          radius: HeatmapRadius.fromPixels(38),
          gradient: HeatmapGradient(gradient),
          opacity: 0.75,
          dissipating: true,
        ),
      );
    }

    debugPrint('🗺️ Generated ${heatmaps.length} heatmaps (1 mine + ${_nearbySensors.length} nearby)');
    return heatmaps;
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};

    // Your mobile sensor marker (green)
    if (_userLocation != null && _sensorData != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('my_sensor'),
          position: _userLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Your Sensor',
            snippet: 'AQI: ${_sensorData!.airQualityRaw.toStringAsFixed(0)}',
          ),
        ),
      );
    }

    // Nearby sensors markers (blue)
    for (var sensor in _nearbySensors) {
      markers.add(
        Marker(
          markerId: MarkerId(sensor.id),
          position: LatLng(sensor.lat, sensor.lang),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: 'Nearby Sensor',
            snippet: 'AQI: ${sensor.airQuality.toStringAsFixed(0)} | ${sensor.distanceKm.toStringAsFixed(2)}km',
          ),
        ),
      );
    }

    return markers;
  }

  // ==================== UI BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildMap(),
          _buildDataOverlay(),
          _buildFloatingButtons(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
            'Air Quality Monitor',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      centerTitle: true,
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: _initialPosition,
      onMapCreated: (controller) async {
        _mapController.complete(controller);
        try {
          await controller.setMapStyle(_mapStyle);

          // If location already fetched, move camera to user location
          if (_userLocation != null) {
            controller.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: _userLocation!, zoom: 15),
              ),
            );
            debugPrint('📍 Camera moved to user location on map creation');
          }
        } catch (e) {
          debugPrint('Map style error: $e');
        }
      },
      onCameraMove: _onCameraMove,
      mapType: MapType.normal,
      heatmaps: _heatmaps,
      markers: _markers,
      myLocationEnabled: _hasLocationPermission,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      padding: const EdgeInsets.only(top: 120, bottom: 280),
    );
  }

  Widget _buildDataOverlay() {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildDataCard(),
          ),
          const Spacer(),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildDataCard() {
    if (_isLoadingSensorData && _sensorData == null) {
      return _buildLoadingCard();
    }

    if (_sensorData == null) {
      return _buildErrorCard();
    }

    return ClipRRect(
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
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.thermostat_rounded,
                      label: 'Temperature',
                      value: '${_sensorData!.temperature.toStringAsFixed(1)}°C',
                      color: const Color(0xFFFF6B6B),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.water_drop_rounded,
                      label: 'Humidity',
                      value: '${_sensorData!.humidity.toStringAsFixed(0)}%',
                      color: const Color(0xFF4FC3F7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildAQISection(),
            ],
          ),
        ),
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF00E676), strokeWidth: 3),
                SizedBox(height: 16),
                Text(
                  'Connecting to sensor...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
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
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sensors_off_rounded, color: Colors.orange, size: 48),
                SizedBox(height: 16),
                Text(
                  'Sensor offline',
                  style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap refresh to try again',
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              value,
              key: ValueKey(value),
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAQISection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (_aqiStatus?.color ?? Colors.grey).withValues(alpha: 0.15),
            (_aqiStatus?.color ?? Colors.grey).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (_aqiStatus?.color ?? Colors.grey).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (_aqiStatus?.color ?? Colors.grey).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _aqiStatus?.icon ?? Icons.air_rounded,
              color: _aqiStatus?.color ?? Colors.grey,
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _aqiStatus?.status ?? 'Unknown',
                    key: ValueKey(_aqiStatus?.status),
                    style: TextStyle(
                      color: _aqiStatus?.color ?? Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    'Raw: ${_sensorData?.airQualityRaw.toStringAsFixed(0) ?? "N/A"}',
                    key: ValueKey(_sensorData?.airQualityRaw),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    final distance = _getDistanceFromZoom(_currentZoomLevel);

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
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
                    icon: Icons.sensors_rounded,
                    label: 'Nearby Sensors',
                    value: '${_nearbySensors.length}',
                  ),
                  _buildInfoItem(
                    icon: Icons.radar_rounded,
                    label: 'Search Radius',
                    value: distance,
                  ),
                  _buildInfoItem(
                    icon: Icons.network_check_rounded,
                    label: 'ESP32',
                    value: _sensorData != null ? 'Online' : 'Offline',
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
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildFloatingButtons() {
    return Positioned(
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
            onPressed: _fetchESP32SensorData,
            color: const Color(0xFF00E676),
          ),
        ],
      ),
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
              colors: [color, color.withValues(alpha: 0.7)],
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