import 'package:flutter/material.dart';

import '../main.dart';
import 'auth/profile_screen.dart';
import 'database_screen.dart';
import 'realtime_screen.dart';
import 'storage_screen.dart';
import 'messaging_screen.dart';
import 'remote_config_screen.dart';
import 'functions_screen.dart';
import 'ml_screen.dart';
import 'ai_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _getInitial(dynamic user) {
    final displayName = user?.displayName as String?;
    if (displayName != null && displayName.isNotEmpty) {
      return displayName[0];
    }
    final email = user?.email as String?;
    if (email != null && email.isNotEmpty) {
      return email[0];
    }
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    final user = ScsExampleApp.scs!.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SCS Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      _getInitial(user).toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Welcome',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          user?.email ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Services',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _FeatureCard(
                icon: Icons.storage,
                title: 'Database',
                subtitle: 'NoSQL documents',
                color: Colors.blue,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DatabaseScreen()),
                ),
              ),
              _FeatureCard(
                icon: Icons.sync,
                title: 'Realtime',
                subtitle: 'Live sync',
                color: Colors.green,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RealtimeScreen()),
                ),
              ),
              _FeatureCard(
                icon: Icons.cloud_upload,
                title: 'Storage',
                subtitle: 'File uploads',
                color: Colors.orange,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StorageScreen()),
                ),
              ),
              _FeatureCard(
                icon: Icons.notifications,
                title: 'Messaging',
                subtitle: 'Push notifications',
                color: Colors.purple,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MessagingScreen()),
                ),
              ),
              _FeatureCard(
                icon: Icons.settings_remote,
                title: 'Remote Config',
                subtitle: 'Dynamic settings',
                color: Colors.teal,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RemoteConfigScreen()),
                ),
              ),
              _FeatureCard(
                icon: Icons.functions,
                title: 'Functions',
                subtitle: 'Cloud functions',
                color: Colors.indigo,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FunctionsScreen()),
                ),
              ),
              _FeatureCard(
                icon: Icons.psychology,
                title: 'ML',
                subtitle: 'OCR & Labeling',
                color: Colors.pink,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MlScreen()),
                ),
              ),
              _FeatureCard(
                icon: Icons.auto_awesome,
                title: 'AI',
                subtitle: 'Chat & Generate',
                color: Colors.amber,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
