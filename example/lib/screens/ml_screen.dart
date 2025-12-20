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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchModels();
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _textResult = null;
        _labelResult = null;
        _predictionResult = null;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Machine Learning'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'OCR', icon: Icon(Icons.text_fields)),
            Tab(text: 'Labeling', icon: Icon(Icons.label)),
            Tab(text: 'Custom', icon: Icon(Icons.model_training)),
          ],
        ),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: InkWell(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
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
                Text(
                  'Confidence: ${((_textResult!.confidence ?? 0) * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall,
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
                      Text(
                        _textResult!.text,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Blocks: ${_textResult!.blocks.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Text(
                  'Select an image and tap "Recognize Text"',
                  style: TextStyle(color: Colors.grey.shade600),
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
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                      ),
                      title: Text(label.label),
                      subtitle: label.category != null
                          ? Text(label.category!)
                          : null,
                      trailing: Text(
                        '${(label.confidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Text(
                  'Select an image and tap "Label Image"',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),
        ],
      ),
    );
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
                  Text(
                    '${_predictionResult!.executionTime}ms',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _predictionResult!.predictions.length,
                itemBuilder: (context, index) {
                  final prediction = _predictionResult!.predictions[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                      ),
                      title: Text(prediction.label),
                      trailing: Text(
                        '${(prediction.confidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
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
              child: Center(
                child: Text(
                  'Select a model and tap "Run Prediction"',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
