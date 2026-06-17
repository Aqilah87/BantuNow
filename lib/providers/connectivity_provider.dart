import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  ConnectivityProvider() {
    _checkInitial();
    Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.contains(ConnectivityResult.none) || results.isEmpty;
      if (offline != _isOffline) {
        _isOffline = offline;
        notifyListeners();
      }
    });
  }

  Future<void> _checkInitial() async {
    final result = await Connectivity().checkConnectivity();
    final offline = result.contains(ConnectivityResult.none) || result.isEmpty;
    if (offline != _isOffline) {
      _isOffline = offline;
      notifyListeners();
    }
  }

  Future<void> recheck() async => _checkInitial();
}