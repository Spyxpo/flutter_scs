import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_scs/flutter_scs.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';

class MlScreen extends StatefulWidget {
  const MlScreen({super.key});

  @override
  State<MlScreen> createState() => _MlScreenState();
}

class _MlScreenState extends State<MlScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  File? _selectedImage;
  bool _loading = false;
  TextRecognitionResult? _textResult;
  ImageLabelingResult? _labelResult;
  List<CustomModel> _models = [];
  PredictionResult? _predictionResult;
  String? _selectedModelId;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchModels();
    _fetchStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels() async {
    try {
      final models = await ScsExampleApp.scs!.ml.listModels();
      setState(() => _models = models);
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await ScsExampleApp.scs!.ml.getStats();
      setState(() => _stats = stats);
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _textResult = null;
        _labelResult = null;
        _predictionResult = null;
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(source: ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(source: ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recognizeText() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result =
          await ScsExampleApp.scs!.ml.recognizeTextFromFile(_selectedImage!);
      setState(() => _textResult = result);
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

  Future<void> _labelImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result =
          await ScsExampleApp.scs!.ml.labelImageFromFile(_selectedImage!);
      setState(() => _labelResult = result);
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

  Future<void> _runPrediction() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedModelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a model'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await ScsExampleApp.scs!.ml.predict(
        _selectedModelId!,
        _selectedImage!,
      );
      setState(() => _predictionResult = result);
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

  Future<void> _deleteModel(CustomModel model) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete "${model.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await ScsExampleApp.scs!.ml.deleteModel(model.id);
      await _fetchModels();
      if (_selectedModelId == model.id) {
        setState(() => _selectedModelId = null);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Model deleted'),
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
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showModelDetails(CustomModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(model.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('ID', model.id),
            if (model.description != null)
              _buildDetailRow('Description', model.description!),
            if (model.type != null) _buildDetailRow('Type', model.type!),
            if (model.createdAt != null)
              _buildDetailRow('Created', _formatDateTime(model.createdAt!)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _selectedModelId = model.id);
              _tabController.animateTo(2);
            },
            child: const Text('Use Model'),
          ),
        ],
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
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Machine Learning'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchModels();
              _fetchStats();
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'OCR', icon: Icon(Icons.text_fields)),
            Tab(text: 'Labeling', icon: Icon(Icons.label)),
            Tab(text: 'Custom', icon: Icon(Icons.model_training)),
            Tab(text: 'Stats', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: InkWell(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _selectedImage != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton.filled(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _selectedImage = null;
                                  _textResult = null;
                                  _labelResult = null;
                                  _predictionResult = null;
                                });
                              },
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 48,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to select an image',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gallery or Camera',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOcrTab(),
                _buildLabelingTab(),
                _buildCustomModelTab(),
                _buildStatsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOcrTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _loading ? null : _recognizeText,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.document_scanner),
            label: const Text('Recognize Text'),
          ),
          const SizedBox(height: 16),
          if (_textResult != null) ...[
            Row(
              children: [
                Text(
                  'Result',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_textResult!.confidence != null)
                  Chip(
                    label: Text(
                        '${((_textResult!.confidence ?? 0) * 100).toStringAsFixed(1)}%'),
                    labelStyle: const TextStyle(fontSize: 10),
                    avatar: const Icon(Icons.verified, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        _textResult!.text,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Text Blocks: ${_textResult!.blocks.length}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(
                        _textResult!.blocks.length,
                        (index) {
                          final block = _textResult!.blocks[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(
                                  block.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${block.lines.length} lines',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                trailing: block.confidence != null
                                    ? Text(
                                        '${(block.confidence! * 100).toStringAsFixed(0)}%')
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select an image and tap "Recognize Text"',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Supports printed and handwritten text',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLabelingTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _loading ? null : _labelImage,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.label),
            label: const Text('Label Image'),
          ),
          const SizedBox(height: 16),
          if (_labelResult != null) ...[
            Text(
              'Labels (${_labelResult!.labels.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _labelResult!.labels.length,
                itemBuilder: (context, index) {
                  final label = _labelResult!.labels[index];
                  final confidence = label.confidence * 100;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getConfidenceColor(confidence),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(label.label),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (label.category != null) Text(label.category!),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: label.confidence,
                            backgroundColor: Colors.grey.shade300,
                          ),
                        ],
                      ),
                      trailing: Text(
                        '${confidence.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: _getConfidenceColor(confidence),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.label_outline,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select an image and tap "Label Image"',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Detect objects, scenes, and activities',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildCustomModelTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_models.isNotEmpty) ...[
            DropdownMenu<String>(
              initialSelection: _selectedModelId,
              label: const Text('Select Model'),
              leadingIcon: const Icon(Icons.model_training),
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: _models.map((model) {
                return DropdownMenuEntry(
                  value: model.id,
                  label: model.name,
                );
              }).toList(),
              onSelected: (value) {
                setState(() => _selectedModelId = value);
              },
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: _loading ? null : _runPrediction,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: const Text('Run Prediction'),
          ),
          const SizedBox(height: 16),
          if (_predictionResult != null) ...[
            Row(
              children: [
                Text(
                  'Predictions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_predictionResult!.executionTime != null)
                  Chip(
                    label: Text('${_predictionResult!.executionTime}ms'),
                    labelStyle: const TextStyle(fontSize: 10),
                    avatar: const Icon(Icons.timer, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _predictionResult!.predictions.length,
                itemBuilder: (context, index) {
                  final prediction = _predictionResult!.predictions[index];
                  final confidence = prediction.confidence * 100;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getConfidenceColor(confidence),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(prediction.label),
                      subtitle: LinearProgressIndicator(
                        value: prediction.confidence,
                        backgroundColor: Colors.grey.shade300,
                      ),
                      trailing: Text(
                        '${confidence.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: _getConfidenceColor(confidence),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else if (_models.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.model_training,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No custom models available',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Deploy models from the SCS dashboard',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        'Select a model and tap "Run Prediction"',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                  const Divider(),
                  Text(
                    'Available Models',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _models.length,
                      itemBuilder: (context, index) {
                        final model = _models[index];
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.model_training),
                            ),
                            title: Text(model.name),
                            subtitle: Text(model.description ?? model.type ?? 'Custom Model'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.info_outline),
                                  onPressed: () => _showModelDetails(model),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteModel(model),
                                  color: Colors.red,
                                ),
                              ],
                            ),
                            onTap: () {
                              setState(() => _selectedModelId = model.id);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_stats.isNotEmpty) ...[
            Text(
              'ML Statistics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children:
                  _stats.entries.map((e) => _buildStatCard(e.key, e.value)).toList(),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No statistics available',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Custom Models',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.model_training),
                  const SizedBox(width: 8),
                  Text(
                    '${_models.length} models deployed',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Available Features',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            'Text Recognition (OCR)',
            'Extract text from images, supports printed and handwritten',
            Icons.document_scanner,
          ),
          _buildFeatureCard(
            'Image Labeling',
            'Detect objects, scenes, and activities in images',
            Icons.label,
          ),
          _buildFeatureCard(
            'Custom Models',
            'Run predictions using your own trained models',
            Icons.model_training,
          ),
          _buildFeatureCard(
            'Bounding Boxes',
            'Get location coordinates for detected elements',
            Icons.crop_square,
          ),
          _buildFeatureCard(
            'Confidence Scores',
            'Accuracy scores for all predictions',
            Icons.verified,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, dynamic value) {
    String displayLabel = label
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}')
        .trim()
        .replaceFirst(label[0], label[0].toUpperCase());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              displayLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(String title, String description, IconData icon) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(description),
      ),
    );
  }
}
