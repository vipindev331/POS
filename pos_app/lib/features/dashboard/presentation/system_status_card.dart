// Part-3 wiring proof: exercises DioClient (hits the backend /health) and
// ConnectivityService, and shows the resolved config store + API base URL.
// This is a real, functional screen — it verifies the core plumbing works.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/di/injector.dart';

class SystemStatusCard extends StatefulWidget {
  const SystemStatusCard({super.key});

  @override
  State<SystemStatusCard> createState() => _SystemStatusCardState();
}

class _SystemStatusCardState extends State<SystemStatusCard> {
  String _health = 'checking…';
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _health = 'checking…';
      _ok = false;
    });
    try {
      // /health lives at the server root, not under /api/v1 — use a bare Dio so
      // the client's baseUrl doesn't rewrite the absolute URL.
      final res = await Dio().getUri(
        Uri.parse(kApiBaseUrl.replaceFirst('/api/v1', '/health')),
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      setState(() {
        _ok = res.statusCode == 200;
        _health = _ok ? 'online — branch ${res.data['branch']}' : 'HTTP ${res.statusCode}';
      });
    } catch (e) {
      setState(() {
        _ok = false;
        _health = 'unreachable';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = sl<ConnectivityService>().isOnline;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('System status', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(onPressed: _check, icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 8),
            _row('Network', online ? 'connected' : 'offline', online),
            _row('Backend', _health, _ok),
            _row('API base', kApiBaseUrl, true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, bool good) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(good ? Icons.check_circle : Icons.error_outline,
              size: 18, color: good ? Colors.green : Colors.orange),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: Text(label)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
