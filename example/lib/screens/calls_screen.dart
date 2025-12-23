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
  bool _isRecording = false;
  bool _isTranscribing = false;
  List<Participant> _participants = [];
  List<Map<String, dynamic>> _recordings = [];
  Map<String, dynamic>? _transcription;
  List<Map<String, dynamic>> _chatMessages = [];
  final _chatController = TextEditingController();

  // Subscriptions
  StreamSubscription? _participantJoinedSub;
  StreamSubscription? _participantLeftSub;
  StreamSubscription? _callEndedSub;
  StreamSubscription? _chatMessageSub;
  StreamSubscription? _transcriptionSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchCalls();
    _fetchStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _participantJoinedSub?.cancel();
    _participantLeftSub?.cancel();
    _callEndedSub?.cancel();
    _chatMessageSub?.cancel();
    _transcriptionSub?.cancel();
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

  Future<void> _fetchParticipants(String callId) async {
    try {
      final participants = await ScsExampleApp.scs!.calls.getParticipants(callId);
      setState(() => _participants = participants);
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _fetchRecordings(String callId) async {
    try {
      final recordings = await ScsExampleApp.scs!.calls.listRecordings(callId);
      setState(() => _recordings = recordings);
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _fetchTranscription(String callId) async {
    try {
      final transcription = await ScsExampleApp.scs!.calls.getTranscription(callId);
      setState(() => _transcription = transcription);
    } catch (e) {
      // Ignore
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
        _chatMessages = [];
      });

      // Fetch participants and recordings
      await _fetchParticipants(call.callId);
      await _fetchRecordings(call.callId);
      await _fetchTranscription(call.callId);

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
      setState(() => _participants.add(participant));
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
      setState(() {
        _participants.removeWhere((p) => p.participantId == participant.participantId);
      });
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

    _chatMessageSub = ScsExampleApp.scs!.calls.onChatMessage.listen((data) {
      setState(() => _chatMessages.add(data));
    });

    _transcriptionSub = ScsExampleApp.scs!.calls.onTranscriptionSegment.listen((data) {
      // Handle live transcription
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transcription: ${data['text'] ?? ''}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _showActiveCallSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
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
                  Center(
                    child: Text(
                      'Room: ${_activeCall?.roomId ?? 'Unknown'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recording/Transcription status
                  if (_isRecording || _isTranscribing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isRecording)
                          Chip(
                            label: const Text('Recording'),
                            avatar: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                            backgroundColor: Colors.red.shade100,
                          ),
                        if (_isRecording && _isTranscribing) const SizedBox(width: 8),
                        if (_isTranscribing)
                          Chip(
                            label: const Text('Transcribing'),
                            avatar: const Icon(Icons.closed_caption, size: 12),
                            backgroundColor: Colors.blue.shade100,
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Call controls
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

                  // Recording & Transcription controls
                  Text(
                    'Controls',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              if (_isRecording) {
                                await ScsExampleApp.scs!.calls.stopRecording(_activeCall!.callId);
                                setState(() => _isRecording = false);
                              } else {
                                await ScsExampleApp.scs!.calls.startRecording(_activeCall!.callId);
                                setState(() => _isRecording = true);
                              }
                              setSheetState(() {});
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          icon: Icon(
                            _isRecording ? Icons.stop : Icons.fiber_manual_record,
                            color: _isRecording ? Colors.grey : Colors.red,
                          ),
                          label: Text(_isRecording ? 'Stop Rec' : 'Record'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              if (_isTranscribing) {
                                await ScsExampleApp.scs!.calls.stopTranscription(_activeCall!.callId);
                                setState(() => _isTranscribing = false);
                              } else {
                                await ScsExampleApp.scs!.calls.startTranscription(_activeCall!.callId);
                                setState(() => _isTranscribing = true);
                              }
                              setSheetState(() {});
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          icon: Icon(
                            _isTranscribing ? Icons.closed_caption_disabled : Icons.closed_caption,
                            color: _isTranscribing ? Colors.blue : Colors.grey,
                          ),
                          label: Text(_isTranscribing ? 'Stop CC' : 'Transcribe'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScsExampleApp.scs!.calls.raiseHand(true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Hand raised!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          icon: const Icon(Icons.pan_tool),
                          label: const Text('Raise Hand'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _showReactionPicker(setSheetState);
                          },
                          icon: const Icon(Icons.emoji_emotions),
                          label: const Text('React'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Participants
                  Text(
                    'Participants (${_participants.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_participants.isEmpty)
                    const Text('No participants yet')
                  else
                    ...List.generate(_participants.length, (index) {
                      final participant = _participants[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(participant.displayName[0].toUpperCase()),
                        ),
                        title: Text(participant.displayName),
                        subtitle: Text(participant.role.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              participant.mediaState['audio'] == true
                                  ? Icons.mic
                                  : Icons.mic_off,
                              size: 18,
                              color: participant.mediaState['audio'] == true
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              participant.mediaState['video'] == true
                                  ? Icons.videocam
                                  : Icons.videocam_off,
                              size: 18,
                              color: participant.mediaState['video'] == true
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 16),

                  // Chat
                  Text(
                    'Chat',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: _chatMessages.isEmpty
                              ? const Center(child: Text('No messages yet'))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _chatMessages.length,
                                  itemBuilder: (context, index) {
                                    final msg = _chatMessages[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Text(
                                        '${msg['displayName']}: ${msg['message']}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    );
                                  },
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _chatController,
                                  decoration: const InputDecoration(
                                    hintText: 'Type a message...',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onSubmitted: (_) => _sendChatMessage(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: _sendChatMessage,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReactionPicker(StateSetter setSheetState) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: ['👍', '❤️', '😂', '😮', '😢', '👏', '🎉', '🔥'].map((emoji) {
            return InkWell(
              onTap: () {
                ScsExampleApp.scs!.calls.sendReaction(emoji);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sent $emoji'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _sendChatMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    try {
      await ScsExampleApp.scs!.calls.sendChatMessage(message);
      _chatController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _leaveCall() {
    ScsExampleApp.scs!.calls.leaveCall();
    _participantJoinedSub?.cancel();
    _participantLeftSub?.cancel();
    _callEndedSub?.cancel();
    _chatMessageSub?.cancel();
    _transcriptionSub?.cancel();

    setState(() {
      _activeCall = null;
      _inCall = false;
      _isRecording = false;
      _isTranscribing = false;
      _participants = [];
      _chatMessages = [];
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

  Future<void> _showCallRecordings(Call call) async {
    await _fetchRecordings(call.callId);
    await _fetchTranscription(call.callId);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Call ${call.roomId}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recordings (${_recordings.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (_recordings.isEmpty)
                  const Text('No recordings')
                else
                  ...List.generate(_recordings.length, (index) {
                    final recording = _recordings[index];
                    return ListTile(
                      leading: const Icon(Icons.video_file),
                      title: Text(recording['format'] ?? 'Recording'),
                      subtitle: Text('${recording['duration'] ?? 0} seconds'),
                      trailing: IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () {
                          // Handle download
                        },
                      ),
                    );
                  }),
                const Divider(),
                Text(
                  'Transcription',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (_transcription == null)
                  const Text('No transcription')
                else
                  Text(_transcription!['text'] ?? 'No text'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
            Tab(text: 'Recordings', icon: Icon(Icons.video_library)),
            Tab(text: 'Stats', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCallsTab(),
          _buildRecordingsTab(),
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
            onViewRecordings: () => _showCallRecordings(call),
          );
        },
      ),
    );
  }

  Widget _buildRecordingsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Call Recordings',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a call to view its recordings',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          if (_calls.isNotEmpty)
            ...List.generate(_calls.take(5).length, (index) {
              final call = _calls[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    call.type == CallType.video ? Icons.videocam : Icons.call,
                    color: call.type == CallType.video ? Colors.blue : Colors.green,
                  ),
                  title: Text('Call ${call.roomId}'),
                  subtitle: Text('Duration: ${call.duration}s'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showCallRecordings(call),
                ),
              );
            }),
        ],
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
                  const _FeatureRow(
                    icon: Icons.videocam,
                    title: 'Video Calls',
                    subtitle: 'High-quality video conferencing',
                  ),
                  const _FeatureRow(
                    icon: Icons.call,
                    title: 'Voice Calls',
                    subtitle: 'Crystal-clear audio calls',
                  ),
                  const _FeatureRow(
                    icon: Icons.group,
                    title: 'Group Calls',
                    subtitle: 'Up to 50 participants',
                  ),
                  const _FeatureRow(
                    icon: Icons.fiber_manual_record,
                    title: 'Recording',
                    subtitle: 'Record and save calls',
                  ),
                  const _FeatureRow(
                    icon: Icons.closed_caption,
                    title: 'Transcription',
                    subtitle: 'Real-time speech-to-text',
                  ),
                  const _FeatureRow(
                    icon: Icons.chat,
                    title: 'In-call Chat',
                    subtitle: 'Send messages during calls',
                  ),
                  const _FeatureRow(
                    icon: Icons.emoji_emotions,
                    title: 'Reactions',
                    subtitle: 'Express yourself with emoji reactions',
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
  final VoidCallback onViewRecordings;

  const _CallCard({
    required this.call,
    required this.onJoin,
    required this.onEnd,
    required this.onViewRecordings,
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
                if (call.duration > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${call.duration}s',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.video_library, color: Colors.blue),
              onPressed: onViewRecordings,
              tooltip: 'View Recordings',
            ),
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
