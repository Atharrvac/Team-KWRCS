import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';

// ==================== DATA MODELS ====================

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

enum MetricType {
  temperature,
  humidity,
  airQuality,
}

enum ChartType {
  line,
  bar,
  radar,
  distribution,
}

// ==================== API SERVICE ====================

class AnalyticsApiService {
  static const String baseUrl = 'http://10.118.211.126:5000/api/sensor';

  // Get nearby sensors using POST /sensor/nearby endpoint
  static Future<List<NearbySensorData>> getNearbySensors({
    required double lat,
    required double lang,
  }) async {
    try {
      debugPrint('🔍 Fetching nearby sensors for: $lat, $lang with distance: 100m');

      final response = await http
          .post(
        Uri.parse('$baseUrl/nearby'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'lat': lat.toStringAsFixed(6),
          'lang': lang.toStringAsFixed(6),
          'distance': '100m',
        }),
      )
          .timeout(const Duration(seconds: 8));

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        // Check if 'data' field exists
        if (data.containsKey('data')) {
          final dataList = data['data'] as List;
          final sensors = dataList
              .map((item) => NearbySensorData.fromJson(item as Map<String, dynamic>))
              .toList();

          debugPrint('✅ Fetched ${sensors.length} nearby sensors');
          return sensors;
        } else {
          debugPrint('❌ No "data" field in response');
          return [];
        }
      }

      debugPrint('❌ Get nearby sensors failed: ${response.statusCode}');
      debugPrint('❌ Response: ${response.body}');
      return [];
    } catch (e) {
      debugPrint('❌ Get nearby sensors error: $e');
      return [];
    }
  }
}

// ==================== ANALYTICS SCREEN ====================

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with TickerProviderStateMixin {
  List<NearbySensorData> _sensors = [];
  bool _isLoading = true;
  bool _isLoadingLocation = true;
  MetricType _selectedMetric = MetricType.airQuality;
  ChartType _selectedChart = ChartType.line;

  // Location variables
  double? _userLat;
  double? _userLng;
  bool _hasLocationPermission = false;
  String? _locationError;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeLocation();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _scaleController.forward();
    _slideController.forward();
  }

  Future<void> _initializeLocation() async {
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
            _locationError = 'Location permission denied';
            _isLoading = false;
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

      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
        _hasLocationPermission = true;
        _isLoadingLocation = false;
      });

      debugPrint('📍 Analytics Location: ${position.latitude}, ${position.longitude}');

      // Now fetch data with location
      await _fetchData();
      _startAutoRefresh();

    } catch (e) {
      debugPrint('❌ Location error: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _hasLocationPermission = false;
          _locationError = 'Failed to get location';
          _isLoading = false;
        });
      }
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_userLat != null && _userLng != null) {
        _fetchData();
      }
    });
  }

  Future<void> _fetchData() async {
    if (_userLat == null || _userLng == null) {
      debugPrint('❌ Cannot fetch data: Location not available');
      return;
    }

    final sensors = await AnalyticsApiService.getNearbySensors(
      lat: _userLat!,
      lang: _userLng!,
    );

    if (mounted) {
      setState(() {
        _sensors = sensors;
        _isLoading = false;
      });

      // Restart animations
      _fadeController.forward(from: 0.0);
      _scaleController.forward(from: 0.0);
      _slideController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ==================== ANALYTICS CALCULATIONS ====================

  Map<String, dynamic> _getStatistics(MetricType type) {
    if (_sensors.isEmpty) {
      return {
        'min': 0.0,
        'max': 0.0,
        'avg': 0.0,
        'median': 0.0,
        'stdDev': 0.0,
      };
    }

    List<double> values = _sensors.map((s) {
      switch (type) {
        case MetricType.temperature:
          return s.temp;
        case MetricType.humidity:
          return s.humidity;
        case MetricType.airQuality:
          return s.airQuality;
      }
    }).toList();

    values.sort();

    final min = values.first;
    final max = values.last;
    final avg = values.reduce((a, b) => a + b) / values.length;
    final median = values.length.isOdd
        ? values[values.length ~/ 2]
        : (values[values.length ~/ 2 - 1] + values[values.length ~/ 2]) / 2;

    // Calculate standard deviation
    final variance = values.map((v) => math.pow(v - avg, 2)).reduce((a, b) => a + b) / values.length;
    final stdDev = math.sqrt(variance);

    return {
      'min': min,
      'max': max,
      'avg': avg,
      'median': median,
      'stdDev': stdDev,
    };
  }

  Color _getMetricColor(MetricType type) {
    switch (type) {
      case MetricType.temperature:
        return const Color(0xFFFF6B6B);
      case MetricType.humidity:
        return const Color(0xFF4FC3F7);
      case MetricType.airQuality:
        return const Color(0xFF00E676);
    }
  }

  String _getMetricLabel(MetricType type) {
    switch (type) {
      case MetricType.temperature:
        return 'Temperature';
      case MetricType.humidity:
        return 'Humidity';
      case MetricType.airQuality:
        return 'Air Quality';
    }
  }

  String _getMetricUnit(MetricType type) {
    switch (type) {
      case MetricType.temperature:
        return '°C';
      case MetricType.humidity:
        return '%';
      case MetricType.airQuality:
        return 'AQI';
    }
  }

  IconData _getMetricIcon(MetricType type) {
    switch (type) {
      case MetricType.temperature:
        return Icons.thermostat_rounded;
      case MetricType.humidity:
        return Icons.water_drop_rounded;
      case MetricType.airQuality:
        return Icons.air_rounded;
    }
  }

  // ==================== UI BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Show location loading state
    if (_isLoadingLocation) {
      return _buildLocationLoadingState();
    }

    // Show location error state
    if (!_hasLocationPermission || _locationError != null) {
      return _buildLocationErrorState();
    }

    // Show data loading state
    if (_isLoading) {
      return _buildLoadingState();
    }

    // Show content
    return _buildContent();
  }

  Widget _buildLocationLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2196F3).withValues(alpha: 0.3),
                  const Color(0xFF00BCD4).withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2196F3),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Getting your location...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This is required to find nearby sensors',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                    const Color(0xFFFF3D00).withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.location_off_rounded,
                color: Color(0xFFFF6B6B),
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Location Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _locationError ?? 'Location permission is required to analyze nearby sensors',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _initializeLocation,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Go Back',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00E676).withValues(alpha: 0.3),
                  const Color(0xFF00BCD4).withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.analytics_rounded, color: Color(0xFF00E676), size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Analytics',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _fetchData,
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00E676).withValues(alpha: 0.3),
                  const Color(0xFF00BCD4).withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00E676),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Analyzing nearby sensors...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: const SizedBox(height: 20)),

          // Summary Cards
          SliverToBoxAdapter(child: _buildSummarySection()),

          // Only show analytics if we have sensor data
          if (_sensors.isNotEmpty) ...[
            SliverToBoxAdapter(child: const SizedBox(height: 24)),

            // Metric Selector
            SliverToBoxAdapter(child: _buildMetricSelector()),

            SliverToBoxAdapter(child: const SizedBox(height: 24)),

            // Chart Type Selector
            SliverToBoxAdapter(child: _buildChartTypeSelector()),

            SliverToBoxAdapter(child: const SizedBox(height: 24)),

            // Main Chart
            SliverToBoxAdapter(child: _buildMainChart()),

            SliverToBoxAdapter(child: const SizedBox(height: 24)),

            // Statistics Cards
            SliverToBoxAdapter(child: _buildStatisticsSection()),

            SliverToBoxAdapter(child: const SizedBox(height: 24)),

            // Distribution Chart
            SliverToBoxAdapter(child: _buildDistributionChart()),
          ] else ...[
            // Empty state with helpful message
            SliverToBoxAdapter(child: const SizedBox(height: 40)),
            SliverToBoxAdapter(child: _buildEmptyState()),
          ],

          SliverToBoxAdapter(child: const SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00E676).withValues(alpha: 0.2),
                    const Color(0xFF00BCD4).withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.analytics_outlined,
                color: Color(0xFF00E676),
                size: 80,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Analytics Available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'There are no sensors within 100m of your location.\nTry moving closer to sensor locations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.tips_and_updates_rounded,
                    color: Color(0xFFFFEA00),
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tip',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Analytics will automatically appear once sensors are detected nearby. The data refreshes every 10 seconds.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (_sensors.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFF9100).withValues(alpha: 0.2),
                              const Color(0xFFFF9100).withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF9100).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9100).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFFFF9100),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No Nearby Sensors',
                                    style: TextStyle(
                                      color: Color(0xFFFF9100),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'No sensors found within 100m radius',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      icon: Icons.sensors_rounded,
                      label: 'Sensors Found',
                      value: '${_sensors.length}',
                      color: const Color(0xFF00E676),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      icon: Icons.radar_rounded,
                      label: 'Search Radius',
                      value: '100m',
                      color: const Color(0xFF2196F3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      icon: Icons.my_location_rounded,
                      label: 'Location',
                      value: _userLat != null ? '${_userLat!.toStringAsFixed(4)}°' : 'N/A',
                      color: const Color(0xFFFF6B6B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricSelector() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Metric',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricButton(MetricType.temperature),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricButton(MetricType.humidity),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricButton(MetricType.airQuality),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricButton(MetricType type) {
    final isSelected = _selectedMetric == type;
    final color = _getMetricColor(type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedMetric = type;
            });
            _fadeController.forward(from: 0.5);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.1),
                ],
              )
                  : null,
              color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _getMetricIcon(type),
                  color: isSelected ? color : Colors.white60,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  _getMetricLabel(type),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? color : Colors.white60,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartTypeSelector() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chart Type',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildChartTypeChip(ChartType.line, Icons.show_chart_rounded, 'Line'),
                  const SizedBox(width: 12),
                  _buildChartTypeChip(ChartType.bar, Icons.bar_chart_rounded, 'Bar'),
                  const SizedBox(width: 12),
                  _buildChartTypeChip(ChartType.radar, Icons.radar_rounded, 'Radar'),
                  const SizedBox(width: 12),
                  _buildChartTypeChip(ChartType.distribution, Icons.pie_chart_rounded, 'Distribution'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartTypeChip(ChartType type, IconData icon, String label) {
    final isSelected = _selectedChart == type;
    final color = _getMetricColor(_selectedMetric);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedChart = type;
            });
            _scaleController.forward(from: 0.5);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.1),
                ],
              )
                  : null,
              color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? color : Colors.white60,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? color : Colors.white60,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainChart() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getMetricColor(_selectedMetric).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getMetricIcon(_selectedMetric),
                            color: _getMetricColor(_selectedMetric),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_getMetricLabel(_selectedMetric)} Analysis',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 250,
                      child: _buildSelectedChart(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedChart() {
    if (_sensors.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    switch (_selectedChart) {
      case ChartType.line:
        return _buildLineChart();
      case ChartType.bar:
        return _buildBarChart();
      case ChartType.radar:
        return _buildRadarChart();
      case ChartType.distribution:
        return _buildPieChart();
    }
  }

  Widget _buildLineChart() {
    final color = _getMetricColor(_selectedMetric);
    final sortedSensors = List<NearbySensorData>.from(_sensors)
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final spots = sortedSensors.asMap().entries.map((entry) {
      final index = entry.key;
      final sensor = entry.value;

      double value;
      switch (_selectedMetric) {
        case MetricType.temperature:
          value = sensor.temp;
          break;
        case MetricType.humidity:
          value = sensor.humidity;
          break;
        case MetricType.airQuality:
          value = sensor.airQuality;
          break;
      }

      return FlSpot(index.toDouble(), value);
    }).toList();

    final maxY = spots.map((s) => s.y).reduce(math.max) * 1.2;
    final minY = spots.map((s) => s.y).reduce(math.min) * 0.8;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= sortedSensors.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${sortedSensors[value.toInt()].distanceKm.toStringAsFixed(2)}km',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: (maxY - minY) / 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (sortedSensors.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.5)],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: color,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => color.withValues(alpha: 0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} ${_getMetricUnit(_selectedMetric)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildBarChart() {
    final color = _getMetricColor(_selectedMetric);
    final sortedSensors = List<NearbySensorData>.from(_sensors)
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final barGroups = sortedSensors.asMap().entries.map((entry) {
      final index = entry.key;
      final sensor = entry.value;

      double value;
      switch (_selectedMetric) {
        case MetricType.temperature:
          value = sensor.temp;
          break;
        case MetricType.humidity:
          value = sensor.humidity;
          break;
        case MetricType.airQuality:
          value = sensor.airQuality;
          break;
      }

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.6)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ],
      );
    }).toList();

    final maxY = sortedSensors.map((s) {
      switch (_selectedMetric) {
        case MetricType.temperature:
          return s.temp;
        case MetricType.humidity:
          return s.humidity;
        case MetricType.airQuality:
          return s.airQuality;
      }
    }).reduce(math.max) * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => color.withValues(alpha: 0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)} ${_getMetricUnit(_selectedMetric)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= sortedSensors.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'S${value.toInt() + 1}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
      ),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildRadarChart() {
    final color = _getMetricColor(_selectedMetric);

    if (_sensors.length < 3) {
      return Center(
        child: Text(
          'Need at least 3 sensors for radar chart',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    // Take up to 8 sensors for radar chart
    final radarSensors = _sensors.take(8).toList();

    return CustomPaint(
      painter: RadarChartPainter(
        sensors: radarSensors,
        metricType: _selectedMetric,
        color: color,
      ),
      child: Container(),
    );
  }

  Widget _buildPieChart() {
    final color = _getMetricColor(_selectedMetric);

    // Group sensors into ranges
    final stats = _getStatistics(_selectedMetric);
    final min = stats['min'] as double;
    final max = stats['max'] as double;
    final range = max - min;

    if (range == 0) {
      return Center(
        child: Text(
          'All values are the same',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    // Create 4 ranges
    final rangeSize = range / 4;
    final ranges = List.generate(4, (i) {
      final rangeMin = min + (i * rangeSize);
      final rangeMax = min + ((i + 1) * rangeSize);
      final count = _sensors.where((s) {
        double value;
        switch (_selectedMetric) {
          case MetricType.temperature:
            value = s.temp;
            break;
          case MetricType.humidity:
            value = s.humidity;
            break;
          case MetricType.airQuality:
            value = s.airQuality;
            break;
        }
        return value >= rangeMin && (i == 3 ? value <= rangeMax : value < rangeMax);
      }).length;

      return {'min': rangeMin, 'max': rangeMax, 'count': count};
    });

    final total = _sensors.length;
    final colors = [
      color,
      color.withValues(alpha: 0.8),
      color.withValues(alpha: 0.6),
      color.withValues(alpha: 0.4),
    ];

    final sections = ranges.asMap().entries.map((entry) {
      final index = entry.key;
      final range = entry.value;
      final count = range['count'] as int;
      final percentage = (count / total * 100);

      return PieChartSectionData(
        color: colors[index],
        value: count.toDouble(),
        title: count > 0 ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {},
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: ranges.asMap().entries.map((entry) {
              final index = entry.key;
              final range = entry.value;
              final rangeMin = range['min'] as double;
              final rangeMax = range['max'] as double;
              final count = range['count'] as int;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[index],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${rangeMin.toStringAsFixed(0)}-${rangeMax.toStringAsFixed(0)}: $count',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsSection() {
    final stats = _getStatistics(_selectedMetric);
    final color = _getMetricColor(_selectedMetric);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8,
              children: [
                _buildStatCard('Minimum', stats['min'], color.withValues(alpha: 0.8)),
                _buildStatCard('Maximum', stats['max'], color),
                _buildStatCard('Average', stats['avg'], color.withValues(alpha: 0.6)),
                _buildStatCard('Median', stats['median'], color.withValues(alpha: 0.4)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, double value, Color color) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${value.toStringAsFixed(1)} ${_getMetricUnit(_selectedMetric)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDistributionChart() {
    final color = _getMetricColor(_selectedMetric);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.analytics_outlined,
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Distribution Histogram',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: _buildHistogram(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistogram() {
    if (_sensors.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    final color = _getMetricColor(_selectedMetric);
    final stats = _getStatistics(_selectedMetric);
    final min = stats['min'] as double;
    final max = stats['max'] as double;
    final range = max - min;

    if (range == 0) {
      return Center(
        child: Text(
          'All values are the same',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    // Create 10 bins
    final binCount = 10;
    final binSize = range / binCount;

    final bins = List.generate(binCount, (i) {
      final binMin = min + (i * binSize);
      final binMax = min + ((i + 1) * binSize);
      final count = _sensors.where((s) {
        double value;
        switch (_selectedMetric) {
          case MetricType.temperature:
            value = s.temp;
            break;
          case MetricType.humidity:
            value = s.humidity;
            break;
          case MetricType.airQuality:
            value = s.airQuality;
            break;
        }
        return value >= binMin && (i == binCount - 1 ? value <= binMax : value < binMax);
      }).length;

      return count;
    });

    final maxCount = bins.reduce(math.max).toDouble();

    final barGroups = bins.asMap().entries.map((entry) {
      final index = entry.key;
      final count = entry.value;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.6)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxCount * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => color.withValues(alpha: 0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final binMin = min + (groupIndex * binSize);
              final binMax = min + ((groupIndex + 1) * binSize);
              return BarTooltipItem(
                'Range: ${binMin.toStringAsFixed(1)}-${binMax.toStringAsFixed(1)}\nCount: ${rod.toY.toInt()}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() % 2 != 0) return const SizedBox();
                final binMin = min + (value.toInt() * binSize);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    binMin.toStringAsFixed(0),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 9,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxCount / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
      ),
    );
  }
}

// ==================== RADAR CHART PAINTER ====================

class RadarChartPainter extends CustomPainter {
  final List<NearbySensorData> sensors;
  final MetricType metricType;
  final Color color;

  RadarChartPainter({
    required this.sensors,
    required this.metricType,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;

    // Draw background circles
    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center, radius * i / 5, backgroundPaint);
    }

    // Draw axes
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    final count = sensors.length;
    for (int i = 0; i < count; i++) {
      final angle = (i * 2 * math.pi / count) - math.pi / 2;
      final end = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, end, axisPaint);
    }

    // Get values and normalize
    final values = sensors.map((s) {
      switch (metricType) {
        case MetricType.temperature:
          return s.temp;
        case MetricType.humidity:
          return s.humidity;
        case MetricType.airQuality:
          return s.airQuality;
      }
    }).toList();

    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    final range = maxValue - minValue;

    // Draw data polygon
    final dataPath = Path();
    final dataPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < count; i++) {
      final normalizedValue = range > 0 ? (values[i] - minValue) / range : 0.5;
      final angle = (i * 2 * math.pi / count) - math.pi / 2;
      final r = radius * normalizedValue;

      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );

      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }

      // Draw data points
      canvas.drawCircle(
        point,
        4,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        point,
        4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    dataPath.close();
    canvas.drawPath(dataPath, dataPaint);
    canvas.drawPath(dataPath, borderPaint);

    // Draw labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < count; i++) {
      final angle = (i * 2 * math.pi / count) - math.pi / 2;
      final labelRadius = radius + 15;
      final labelOffset = Offset(
        center.dx + labelRadius * math.cos(angle),
        center.dy + labelRadius * math.sin(angle),
      );

      textPainter.text = TextSpan(
        text: 'S${i + 1}',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          labelOffset.dx - textPainter.width / 2,
          labelOffset.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}