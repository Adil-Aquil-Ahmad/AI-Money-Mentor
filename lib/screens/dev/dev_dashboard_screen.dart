import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../config/api_config.dart';

class DevDashboardScreen extends StatefulWidget {
  const DevDashboardScreen({super.key});

  @override
  State<DevDashboardScreen> createState() => _DevDashboardScreenState();
}

class _DevDashboardScreenState extends State<DevDashboardScreen> {
  late WebSocketChannel _channel;
  Map<String, dynamic> _systemState = {
    "active_users": 0,
    "queue_length": 0,
    "active_jobs": [],
    "recent_logs": [],
    "queued_jobs": []
  };

  Timer? _mockTimer;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _fetchInitialState();
  }

  Future<void> _fetchInitialState() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/dev/state'));
      if (response.statusCode == 200) {
        setState(() {
          _systemState = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch initial state: $e");
    }
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(ApiConfig.wsUrl));
      _channel.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            setState(() {
              _systemState = data;
            });
          } catch (e) {
            debugPrint("Parse error: $e");
          }
        },
        onError: (error) => debugPrint("WS Error: $error"),
        onDone: () {
          debugPrint("WS Done");
          // Reconnect after delay
          Future.delayed(const Duration(seconds: 3), _connectWebSocket);
        },
      );
    } catch (e) {
      debugPrint("WS Init error: $e");
    }
  }

  void _simulateJob() {
    try {
      http.post(
        Uri.parse('${ApiConfig.baseUrl}/dev/simulate?target=AutoSim&req_type=intelligence&user_id=Tester'),
      );
    } catch (e) {
      debugPrint("Simulation dispatch error: $e");
    }
  }

  void _toggleAutoSim() {
    if (_mockTimer != null && _mockTimer!.isActive) {
      _mockTimer!.cancel();
      setState(() => _mockTimer = null);
    } else {
      _simulateJob();
      _mockTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        _simulateJob();
      });
      setState(() {});
    }
  }

  @override
  void dispose() {
    _mockTimer?.cancel();
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeJobs = _systemState['active_jobs'] as List? ?? [];
    final queuedJobs = _systemState['queued_jobs'] as List? ?? [];
    final logs = _systemState['recent_logs'] as List? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: AppBar(
        title: Text(
          'System Supervisor',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF111A2E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _mockTimer?.isActive ?? false ? Icons.stop_circle : Icons.play_circle_fill,
              color: _mockTimer?.isActive ?? false ? Colors.redAccent : Colors.greenAccent,
            ),
            tooltip: 'Toggle Mock Traffic',
            onPressed: _toggleAutoSim,
          ),
          IconButton(
            icon: const Icon(Icons.add_task, color: Colors.blueAccent),
            tooltip: 'Simulate Single Fast Request',
            onPressed: _simulateJob,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // TOP METRICS
            Row(
              children: [
                _buildMetricCard(
                  'Active Jobs Limit',
                  '${activeJobs.length} / 2',
                  Icons.memory,
                  Colors.blueAccent,
                ),
                const SizedBox(width: 16),
                _buildMetricCard(
                  'Queue Depth',
                  '${_systemState["queue_length"]}',
                  Icons.layers,
                  Colors.orangeAccent,
                ),
                const SizedBox(width: 16),
                _buildMetricCard(
                  'Connected Users',
                  '${_systemState["active_users"]}',
                  Icons.people_alt,
                  Colors.greenAccent,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // MID SECTION
            Expanded(
              flex: 5,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ACTIVE JOBS PANEL
                  Expanded(
                    child: _buildPanel(
                      title: 'Concurrent Processing (Active)',
                      color: Colors.blueAccent,
                      child: activeJobs.isEmpty
                          ? const Center(child: Text("Idle", style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              itemCount: activeJobs.length,
                              itemBuilder: (context, i) {
                                final job = activeJobs[i];
                                return _buildJobCard(job, Colors.blue.withOpacity(0.1), Colors.blueAccent);
                              },
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // QUEUED JOBS PANEL
                  Expanded(
                    child: _buildPanel(
                      title: 'Pending Queue',
                      color: Colors.orangeAccent,
                      child: queuedJobs.isEmpty
                          ? const Center(child: Text("Empty", style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              itemCount: queuedJobs.length,
                              itemBuilder: (context, i) {
                                final job = queuedJobs[i];
                                return _buildJobCard(job, Colors.white10, Colors.grey);
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // BLACK TERMINAL LOGS
            Expanded(
              flex: 4,
              child: _buildPanel(
                title: 'System Firehose',
                color: Colors.greenAccent,
                child: Container(
                  width: double.infinity,
                  color: Colors.black,
                  padding: const EdgeInsets.all(12),
                  child: ListView.builder(
                    reverse: true, // Auto-scroll to bottom behavior
                    itemCount: logs.length,
                    itemBuilder: (context, i) {
                      // Reverse index to show newest at bottom correctly based on server append order
                      final log = logs[logs.length - 1 - i];
                      
                      final dt = DateTime.fromMillisecondsSinceEpoch((log['time'] * 1000).toInt());
                      final timeStr = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
                      
                      Color levelColor = Colors.white;
                      if (log['status'] == 'info') levelColor = Colors.blueAccent;
                      if (log['status'] == 'warning') levelColor = Colors.orangeAccent;
                      if (log['status'] == 'error') levelColor = Colors.redAccent;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.firaCode(fontSize: 13, color: Colors.white70),
                            children: [
                              TextSpan(text: '[$timeStr] ', style: const TextStyle(color: Colors.green)),
                              TextSpan(text: '[${log['user_id']}] ', style: const TextStyle(color: Colors.white30)),
                              TextSpan(text: '${log['event']}', style: TextStyle(color: levelColor)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel({required String title, required Color color, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: child,
          )),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<dynamic, dynamic> job, Color bgColor, Color badgeColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              job['status'] == 'processing' ? Icons.sync : Icons.hourglass_empty,
               color: badgeColor, 
               size: 20
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job['stock'] ?? job['query'] ?? 'Job',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  '${job['type'].toString().toUpperCase()} • User ${job['user_id']}',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          if (job['status'] == 'processing')
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
            ),
        ],
      ),
    );
  }
}
