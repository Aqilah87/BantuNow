// lib/widgets/connectivity_banner.dart

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({Key? key, required this.child}) : super(key: key);

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkInitial();
    Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.contains(ConnectivityResult.none) ||
          results.isEmpty;
      if (mounted) setState(() => _isOffline = offline);
    });
  }

  Future<void> _checkInitial() async {
    final result = await Connectivity().checkConnectivity();
    final offline = result.contains(ConnectivityResult.none) ||
        result.isEmpty;
    if (mounted) setState(() => _isOffline = offline);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isOffline)
          Container(
            width: double.infinity,
            color: Colors.red.shade600,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: const SafeArea(
              bottom: false,
              child: Center(
                child: Text(
                  '📡 Tiada sambungan internet',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}