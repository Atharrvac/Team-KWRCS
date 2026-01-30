import 'package:bridge_kshetra/analytics_screen.dart';
import 'package:bridge_kshetra/home_screen.dart';
import 'package:flutter/material.dart';

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  final _screens = [const HomeScreen(), const AnalyticsScreen()];
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        height: 78,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0F172A).withOpacity(0.78)
              : Color(0xFF0F172A).withOpacity(0.78),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.42 : 0.14),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: NavigationBar(
          height: 78,
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFF3B82F6).withOpacity(0.22),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          elevation: 0,
          destinations: [
            NavigationDestination(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: _currentIndex == 0
                    ? const Icon(
                        Icons.home_rounded,
                        color: Color(0xFF60A5FA),
                        size: 28,
                      )
                    : Icon(
                        Icons.home_outlined,
                        color: Colors.grey[400],
                        size: 26,
                      ),
              ),
              label: 'Home',
            ),
            NavigationDestination(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: _currentIndex == 1
                    ? const Icon(
                        Icons.analytics_rounded,
                        color: Color(0xFF60A5FA),
                        size: 28,
                      )
                    : Icon(
                        Icons.analytics_outlined,
                        color: Colors.grey[400],
                        size: 26,
                      ),
              ),
              label: 'Analytics',
            ),
          ],
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}
