import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import 'dart:async';

class BatterySaverService extends ChangeNotifier {
  static final BatterySaverService instance = BatterySaverService._internal();
  
  BatterySaverService._internal();

  bool _isEnabled = false;
  bool _autoEnableOnLowBattery = true;
  int _batteryLevel = 100;
  bool _isCharging = false;
  StreamSubscription<BatteryState>? _batterySubscription;

  bool get isEnabled => _isEnabled;
  bool get autoEnableOnLowBattery => _autoEnableOnLowBattery;
  int get batteryLevel => _batteryLevel;
  bool get isCharging => _isCharging;

  // Feature flags
  bool get shouldLoadAlbumArt => !_isEnabled;
  bool get shouldTrackStats => !_isEnabled;
  bool get shouldUseAnimations => !_isEnabled;
  Duration get animationDuration => _isEnabled 
      ? const Duration(milliseconds: 0) 
      : const Duration(milliseconds: 300);

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('battery_saver_enabled') ?? false;
      _autoEnableOnLowBattery = prefs.getBool('battery_saver_auto') ?? true;

      await _startBatteryMonitoring();
      
      debugPrint('✅ Battery Saver initialized (enabled: $_isEnabled, auto: $_autoEnableOnLowBattery)');
    } catch (e) {
      debugPrint('⚠️ Battery Saver init failed: $e');
    }
  }

  Future<void> _startBatteryMonitoring() async {
    try {
      final battery = Battery();
      
      // Get initial battery level
      _batteryLevel = await battery.batteryLevel;
      _isCharging = await battery.batteryState == BatteryState.charging;
      
      // Listen to battery state changes
      _batterySubscription = battery.onBatteryStateChanged.listen((state) async {
        _isCharging = state == BatteryState.charging;
        _batteryLevel = await battery.batteryLevel;
        
        debugPrint('🔋 Battery: $_batteryLevel% (charging: $_isCharging)');
        
        _checkAutoEnableBatterySaver();
        notifyListeners();
      });

      // Periodic battery level check (every 5 minutes)
      Timer.periodic(const Duration(minutes: 5), (timer) async {
        _batteryLevel = await battery.batteryLevel;
        _checkAutoEnableBatterySaver();
      });

    } catch (e) {
      debugPrint('⚠️ Battery monitoring failed: $e');
    }
  }

  void _checkAutoEnableBatterySaver() {
    if (!_autoEnableOnLowBattery) return;
    
    // Auto-enable when battery drops below 20% and not charging
    if (_batteryLevel <= 20 && !_isCharging && !_isEnabled) {
      _isEnabled = true;
      _savePreference();
      notifyListeners();
      debugPrint('⚡ Battery Saver auto-enabled (battery: $_batteryLevel%)');
    }
    
    // Auto-disable when charging and battery > 50%
    if (_isCharging && _batteryLevel > 50 && _isEnabled) {
      _isEnabled = false;
      _savePreference();
      notifyListeners();
      debugPrint('🔌 Battery Saver auto-disabled (charging, battery: $_batteryLevel%)');
    }
  }

  Future<void> toggle(bool enabled) async {
    _isEnabled = enabled;
    await _savePreference();
    notifyListeners();
    debugPrint('🔋 Battery Saver ${enabled ? 'enabled' : 'disabled'}');
  }

  Future<void> setAutoEnable(bool enabled) async {
    _autoEnableOnLowBattery = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('battery_saver_auto', enabled);
    notifyListeners();
  }

  Future<void> _savePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('battery_saver_enabled', _isEnabled);
    } catch (e) {
      debugPrint('⚠️ Failed to save battery saver preference: $e');
    }
  }

  @override
  void dispose() {
    _batterySubscription?.cancel();
    super.dispose();
  }
}
