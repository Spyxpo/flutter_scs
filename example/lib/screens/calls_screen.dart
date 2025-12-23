import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_scs/flutter_scs.dart';

import '../main.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Call> _calls = [];
  bool _loading = false;
  bool _creatingCall = false;
  CallStats? _stats;

  // Active call state
  Call? _activeCall;
  bool _inCall = false;
  bool _videoEnabled = true;
  bool _audioEnabled = true;

  // Subscriptions
  StreamSubscription? _participantJoinedSub;
  StreamSubscription? _participantLeftSub;
  StreamSubscription? _callEndedSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCalls();
    _fetchStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _participantJoinedSub?.cancel();
    _participantLeftSub?.cancel();
    _callEndedSub?.cancel();
    if (_inCall) {
      ScsExampleApp.scs!.calls.leaveCall();
    }
    super.dispose();
  }

  Future<void> _fetchCalls() async {
    setState(() => _loading = true);
    try {
      final calls = await ScsExampleApp.scs!.calls.listCalls(limit: 20);
      setState(() => _calls = calls);
    } on ScsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await ScsExampleApp.scs!.calls.getStats();
      setState(() => _stats = stats);
    } catch (e) {
      // Ignore errors for stats
    }
  }

  Future<void> _createCall(CallType type) async {
    setState(() => _creatingCall = true);

    try {
      final user = ScsExampleApp.scs!.auth.currentUser;
      final call = await ScsExampleApp.scs!.calls.createCall(
        type: type,
        mode: CallMode.group,
        displayName: user?.displayName ?? user?.email ?? 'User',
        maxParticipants: 10,
      );

      await _fetchCalls();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${type == CallType.video ? 'Video' : 'Voice'} call created!'),
            backgroundColor: Colors.green,
          ),
        );
        _showJoinCallDialog(call);
      }
    } on ScsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingCall = false);
    }
  }

  void _showJoinCallDialog(Call call) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join ${call.type == CallType.video ? 'Video' : 'Voice'} Call'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Call ID: ${call.callId}'),
            const SizedBox(height: 8),
            Text('Room: ${call.roomId}'),
            const SizedBox(height: 8),
            Text('Status: ${call.status}'),
            const SizedBox(height: 8),
            Text('Max Participants: ${call.maxParticipants}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _joinCall(call);
            },
            icon: Icon(call.type == CallType.video ? Icons.videocam : Icons.call),
            label: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinCall(Call call) async {
    try {
      final user = ScsExampleApp.scs!.auth.currentUser;

      // Generate token
      final token = await ScsExampleApp.scs!.calls.generateToken(
        call.callId,
        displayName: user?.displayName ?? user?.email ?? 'User',
        role: ParticipantRole.participant,
        userId: user?.uid,
      );

      // Join the call
      await ScsExampleApp.scs!.calls.joinCall(call.callId, token.token);

      setState(() {
        _activeCall = call;
        _inCall = true;
        _videoEnabled = call.type == CallType.video;
        _audioEnabled = true;
      });

      // Subscribe to events
      _setupCallListeners();

      if (mounted) {
        _showActiveCallSheet();
      }
    } on ScsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _setupCallListeners() {
    _participantJoinedSub = ScsExampleApp.scs!.calls.onParticipantJoined.listen((participant) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${participant.displayName} joined'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    _participantLeftSub = ScsExampleApp.scs!.calls.onParticipantLeft.listen((participant) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${participant.displayName} left'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    _callEndedSub = ScsExampleApp.scs!.calls.onCallEnded.listen((data) {
      _leaveCall();
    });
  }

  void _showActiveCallSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _activeCall?.type == CallType.video
                          ? Icons.videocam
                          : Icons.call,
                      size: 32,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'In Call',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Room: ${_activeCall?.roomId ?? 'Unknown'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallControlButton(
                      icon: _audioEnabled ? Icons.mic : Icons.mic_off,
                      label: _audioEnabled ? 'Mute' : 'Unmute',
                      color: _audioEnabled ? Colors.grey : Colors.red,
                      onPressed: () async {
                        await ScsExampleApp.scs!.calls.updateMediaState(
                          audio: !_audioEnabled,
                        );
                        setState(() => _audioEnabled = !_audioEnabled);
                        setSheetState(() {});
                      },
                    ),
                    if (_activeCall?.type == CallType.video)
                      _CallControlButton(
                        icon: _videoEnabled ? Icons.videocam : Icons.videocam_off,
                        label: _videoEnabled ? 'Stop Video' : 'Start Video',
                        color: _videoEnabled ? Colors.grey : Colors.red,
                        onPressed: () async {
                          await ScsExampleApp.scs!.calls.updateMediaState(
                            video: !_videoEnabled,
                          );
                          setState(() => _videoEnabled = !_videoEnabled);
                          setSheetState(() {});
                        },
                      ),
                    _CallControlButton(
                      icon: Icons.call_end,
                      label: 'End',
                      color: Colors.red,
                      onPressed: () {
                        Navigator.of(context).pop();
                        _leaveCall();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _leaveCall() {
    ScsExampleApp.scs!.calls.leaveCall();
    _participantJoinedSub?.cancel();
    _participantLeftSub?.cancel();
    _callEndedSub?.cancel();

    setState(() {
      _activeCall = null;
      _inCall = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Left the call'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    _fetchCalls();
  }

  Future<void> _endCall(Call call) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Call'),
        content: const Text('Are you sure you want to end this call for everyone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End Call'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ScsExampleApp.scs!.calls.endCall(call.callId);
      await _fetchCalls();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call ended'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ScsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCreateCallOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Create New Call',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _CallTypeCard(
                    icon: Icons.videocam,
                    title: 'Video Call',
                    subtitle: 'Face-to-face meeting',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.of(context).pop();
                      _createCall(CallType.video);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CallTypeCard(
                    icon: Icons.call,
                    title: 'Voice Call',
                    subtitle: 'Audio only',
                    color: Colors.green,
                    onTap: () {
                      Navigator.of(context).pop();
                      _createCall(CallType.voice);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchCalls();
              _fetchStats();
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active Calls', icon: Icon(Icons.call)),
            Tab(text: 'Stats', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCallsTab(),
          _buildStatsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creatingCall ? null : _showCreateCallOptions,
        icon: _creatingCall
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_call),
        label: const Text('New Call'),
      ),
    );
  }

  Widget _buildCallsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.call_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No calls yet',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new call to get started',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCalls,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _calls.length,
        itemBuilder: (context, index) {
          final call = _calls[index];
          return _CallCard(
            call: call,
            onJoin: () => _showJoinCallDialog(call),
            onEnd: () => _endCall(call),
          );
        },
      ),
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Call Statistics',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _StatRow(
                    icon: Icons.call,
                    label: 'Total Calls',
                    value: '${_stats?.totalCalls ?? 0}',
                  ),
                  _StatRow(
                    icon: Icons.phone_in_talk,
                    label: 'Active Calls',
                    value: '${_stats?.activeCalls ?? 0}',
                    valueColor: Colors.green,
                  ),
                  _StatRow(
                    icon: Icons.timer,
                    label: 'Total Minutes',
                    value: '${_stats?.totalMinutes ?? 0}',
                  ),
                  _StatRow(
                    icon: Icons.fiber_manual_record,
                    label: 'Recordings',
                    value: '${_stats?.recordings ?? 0}',
                    valueColor: Colors.red,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Call Features',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _FeatureRow(
                    icon: Icons.videocam,
                    title: 'Video Calls',
                    subtitle: 'High-quality video conferencing',
                  ),
                  _FeatureRow(
                    icon: Icons.call,
                    title: 'Voice Calls',
                    subtitle: 'Crystal-clear audio calls',
                  ),
                  _FeatureRow(
                    icon: Icons.group,
                    title: 'Group Calls',
                    subtitle: 'Up to 50 participants',
                  ),
                  _FeatureRow(
                    icon: Icons.fiber_manual_record,
                    title: 'Recording',
                    subtitle: 'Record and save calls',
                  ),
                  _FeatureRow(
                    icon: Icons.closed_caption,
                    title: 'Transcription',
                    subtitle: 'Real-time speech-to-text',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallCard extends StatelessWidget {
  final Call call;
  final VoidCallback onJoin;
  final VoidCallback onEnd;

  const _CallCard({
    required this.call,
    required this.onJoin,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = call.status == 'active' || call.status == 'waiting';
    final isVideo = call.type == CallType.video;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isVideo ? Colors.blue : Colors.green,
          child: Icon(
            isVideo ? Icons.videocam : Icons.call,
            color: Colors.white,
          ),
        ),
        title: Text(
          '${isVideo ? 'Video' : 'Voice'} Call',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room: ${call.roomId}'),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    call.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Max: ${call.maxParticipants}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              IconButton(
                icon: const Icon(Icons.login, color: Colors.green),
                onPressed: onJoin,
                tooltip: 'Join',
              ),
            IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red),
              onPressed: onEnd,
              tooltip: 'End',
            ),
          ],
        ),
      ),
    );
  }
}

class _CallTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _CallTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: label,
          backgroundColor: color,
          onPressed: onPressed,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }
}
