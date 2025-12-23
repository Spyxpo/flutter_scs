import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_scs/flutter_scs.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _folderController = TextEditingController();
  List<ScsFileMetadata> _files = [];
  bool _loading = false;
  bool _uploading = false;
  String _currentFolder = '';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _folderController.dispose();
    super.dispose();
  }

  Future<void> _fetchFiles() async {
    setState(() => _loading = true);
    try {
      final result = await ScsExampleApp.scs!.storage.list(
        folder: _currentFolder.isNotEmpty ? _currentFolder : null,
        limit: 50,
      );
      setState(() => _files = result.files);
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

  Future<void> _pickAndUploadFile() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
        ],
      ),
    );

    if (source == null) return;

    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() => _uploading = true);
    try {
      final file = File(pickedFile.path);
      await ScsExampleApp.scs!.storage.upload(
        file,
        folder: _currentFolder.isNotEmpty ? _currentFolder : null,
      );
      await _fetchFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File uploaded successfully!'),
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
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _uploadTextFile() async {
    final nameController = TextEditingController();
    final contentController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Text File'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'File Name',
                  hintText: 'e.g., notes.txt',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  hintText: 'Enter text content...',
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop({
              'name': nameController.text.trim(),
              'content': contentController.text,
            }),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (result == null || result['name']!.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final bytes = Uint8List.fromList(result['content']!.codeUnits);
      await ScsExampleApp.scs!.storage.uploadBytes(
        bytes,
        filename: result['name']!,
        folder: _currentFolder.isNotEmpty ? _currentFolder : null,
        mimeType: 'text/plain',
      );
      await _fetchFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text file created!'),
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
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _createFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Create Folder'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Folder Name',
              hintText: 'e.g., images, documents',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;

    try {
      final path = _currentFolder.isNotEmpty ? '$_currentFolder/$name' : name;
      await ScsExampleApp.scs!.storage.createFolder(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Folder "$name" created!'),
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

  Future<void> _deleteFile(ScsFileMetadata file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ScsExampleApp.scs!.storage.delete(file.id);
      await _fetchFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File deleted!'),
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

  Future<void> _downloadFile(ScsFileMetadata file) async {
    try {
      final bytes = await ScsExampleApp.scs!.storage.download(file.id);
      if (mounted) {
        _showFilePreview(file, bytes);
      }
    } on ScsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showFilePreview(ScsFileMetadata file, Uint8List bytes) {
    final isImage = file.mimeType.startsWith('image/');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(file.name),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isImage)
                Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  height: 300,
                )
              else
                Column(
                  children: [
                    const Icon(Icons.insert_drive_file, size: 64),
                    const SizedBox(height: 16),
                    Text('Size: ${file.readableSize}'),
                    Text('Type: ${file.mimeType}'),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                'Downloaded ${bytes.length} bytes',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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

  void _showFileDetails(ScsFileMetadata file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _getFileIcon(file.mimeType, size: 48),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      file.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow('ID', file.id),
              _buildDetailRow('Path', file.path),
              _buildDetailRow('Folder', file.folder ?? 'Root'),
              _buildDetailRow('MIME Type', file.mimeType),
              _buildDetailRow('Size', file.readableSize),
              _buildDetailRow('Extension', file.extension),
              if (file.createdAt != null)
                _buildDetailRow('Created', file.createdAt!.toLocal().toString()),
              if (file.updatedAt != null)
                _buildDetailRow('Updated', file.updatedAt!.toLocal().toString()),
              const Divider(height: 32),
              if (file.url != null) ...[
                Text(
                  'Download URL',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    file.url!,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _downloadFile(file);
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Download'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _deleteFile(file);
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getFileIcon(String? mimeType, {double size = 24}) {
    IconData icon;
    Color color;

    if (mimeType == null) {
      icon = Icons.insert_drive_file;
      color = Colors.grey;
    } else if (mimeType.startsWith('image/')) {
      icon = Icons.image;
      color = Colors.blue;
    } else if (mimeType.startsWith('video/')) {
      icon = Icons.video_file;
      color = Colors.purple;
    } else if (mimeType.startsWith('audio/')) {
      icon = Icons.audio_file;
      color = Colors.orange;
    } else if (mimeType.startsWith('text/')) {
      icon = Icons.article;
      color = Colors.green;
    } else if (mimeType.contains('pdf')) {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else if (mimeType.contains('zip') || mimeType.contains('archive')) {
      icon = Icons.folder_zip;
      color = Colors.amber;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.grey;
    }

    return Icon(icon, size: size, color: color);
  }

  void _navigateToFolder(String folder) {
    setState(() => _currentFolder = folder);
    _fetchFiles();
  }

  void _navigateUp() {
    if (_currentFolder.isEmpty) return;
    final parts = _currentFolder.split('/');
    parts.removeLast();
    setState(() => _currentFolder = parts.join('/'));
    _fetchFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: _createFolder,
            tooltip: 'Create Folder',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchFiles,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Files', icon: Icon(Icons.folder)),
            Tab(text: 'Upload', icon: Icon(Icons.cloud_upload)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFilesTab(),
          _buildUploadTab(),
        ],
      ),
    );
  }

  Widget _buildFilesTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.home),
                onPressed: () => _navigateToFolder(''),
                tooltip: 'Root',
              ),
              if (_currentFolder.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: _navigateUp,
                  tooltip: 'Up',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '/ $_currentFolder',
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Expanded(
                  child: Text('/ (Root)'),
                ),
              Text(
                '${_files.length} files',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _files.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No files found',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _tabController.animateTo(1),
                            icon: const Icon(Icons.upload),
                            label: const Text('Upload a file'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchFiles,
                      child: ListView.builder(
                        itemCount: _files.length,
                        itemBuilder: (context, index) {
                          final file = _files[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: _getFileIcon(file.mimeType),
                              title: Text(
                                file.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Row(
                                children: [
                                  Text(file.readableSize),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      file.extension.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'download':
                                      _downloadFile(file);
                                      break;
                                    case 'delete':
                                      _deleteFile(file);
                                      break;
                                    case 'details':
                                      _showFileDetails(file);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'download',
                                    child: ListTile(
                                      leading: Icon(Icons.download),
                                      title: Text('Download'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'details',
                                    child: ListTile(
                                      leading: Icon(Icons.info),
                                      title: Text('Details'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(Icons.delete, color: Colors.red),
                                      title: Text('Delete', style: TextStyle(color: Colors.red)),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => _showFileDetails(file),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload Options',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _folderController,
                    decoration: InputDecoration(
                      labelText: 'Target Folder (optional)',
                      hintText: 'e.g., images/profile',
                      prefixIcon: const Icon(Icons.folder),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _folderController.clear(),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _currentFolder = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _UploadOptionCard(
            icon: Icons.image,
            title: 'Upload Image',
            subtitle: 'Pick from gallery or take a photo',
            color: Colors.blue,
            loading: _uploading,
            onTap: _uploading ? null : _pickAndUploadFile,
          ),
          const SizedBox(height: 12),
          _UploadOptionCard(
            icon: Icons.article,
            title: 'Create Text File',
            subtitle: 'Create and upload a text file',
            color: Colors.green,
            loading: _uploading,
            onTap: _uploading ? null : _uploadTextFile,
          ),
          const SizedBox(height: 12),
          _UploadOptionCard(
            icon: Icons.create_new_folder,
            title: 'Create Folder',
            subtitle: 'Create a new folder for organization',
            color: Colors.orange,
            loading: false,
            onTap: _createFolder,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Storage Features',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  const _FeatureItem(
                    icon: Icons.cloud_upload,
                    title: 'File Upload',
                    subtitle: 'Upload files and images',
                  ),
                  const _FeatureItem(
                    icon: Icons.cloud_download,
                    title: 'File Download',
                    subtitle: 'Download files as bytes',
                  ),
                  const _FeatureItem(
                    icon: Icons.folder,
                    title: 'Folder Organization',
                    subtitle: 'Organize files in folders',
                  ),
                  const _FeatureItem(
                    icon: Icons.link,
                    title: 'Public URLs',
                    subtitle: 'Get shareable download URLs',
                  ),
                  const _FeatureItem(
                    icon: Icons.info,
                    title: 'File Metadata',
                    subtitle: 'Size, type, timestamps',
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

class _UploadOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;

  const _UploadOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.1),
                child: loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    : Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureItem({
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
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
        ],
      ),
    );
  }
}
