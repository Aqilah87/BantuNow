import 'package:flutter/material.dart';

class OfflineView extends StatelessWidget {
  final bool isMalay;
  final VoidCallback onRetry;
  const OfflineView({Key? key, required this.isMalay, required this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              isMalay ? 'Tiada sambungan ditemui' : 'No connection found',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isMalay
                  ? 'Sila semak tetapan rangkaian anda dan cuba lagi'
                  : 'Please check your network settings and try again',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(isMalay ? 'Cuba lagi' : 'Try again'),
            ),
          ],
        ),
      ),
    );
  }
}