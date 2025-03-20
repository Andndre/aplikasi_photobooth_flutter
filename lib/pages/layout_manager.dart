import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/layouts.dart';
import '../models/layouts.dart';

class LayoutManager extends StatelessWidget {
  const LayoutManager({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Layout Manager')),
      body: FutureBuilder(
        future:
            Provider.of<LayoutsProvider>(context, listen: false).loadLayouts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return Consumer<LayoutsProvider>(
              builder: (context, layoutsProvider, child) {
                if (layoutsProvider.layouts.isEmpty) {
                  return const Center(child: Text('No layouts available.'));
                } else {
                  return ListView.builder(
                    itemCount: layoutsProvider.layouts.length,
                    itemBuilder: (context, index) {
                      final layout = layoutsProvider.layouts[index];
                      return ListTile(
                        title: Text(layout.name),
                        subtitle: Text('ID: ${layout.id}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return EditLayoutDialog(
                                      layout: layout,
                                      index: index,
                                    );
                                  },
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Confirm Delete'),
                                      content: const Text(
                                        'Are you sure you want to delete this layout?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Provider.of<LayoutsProvider>(
                                              context,
                                              listen: false,
                                            ).removeLayout(index);
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return AddLayoutDialog();
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddLayoutDialog extends StatefulWidget {
  @override
  _AddLayoutDialogState createState() => _AddLayoutDialogState();
}

class _AddLayoutDialogState extends State<AddLayoutDialog> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _basePhoto = '';
  String _coordinatesText = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Layout'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Name'),
                onSaved: (value) {
                  _name = value!;
                },
              ),
              ElevatedButton(
                onPressed: () async {
                  // await FilePicker.platform
                  //     .clearTemporaryFiles(); // Ensure FilePicker is initialized
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['png'],
                      );
                  if (result != null && result.files.single.path != null) {
                    setState(() {
                      _basePhoto = result.files.single.path!;
                    });
                  }
                },
                child: const Text('Select Base Photo'),
              ),
              if (_basePhoto.isNotEmpty) Text('Selected: $_basePhoto'),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Coordinates'),
                maxLines: 5,
                onSaved: (value) {
                  _coordinatesText = value!;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              final coordinates =
                  _coordinatesText.split('\n').map((line) {
                    final parts =
                        line
                            .split(',')
                            .map((part) => int.parse(part.trim()))
                            .toList();
                    return parts;
                  }).toList();
              final newLayout = Layouts(
                name: _name,
                basePhoto: _basePhoto,
                id: 0, // ID will be set by the provider
                coordinates: coordinates,
              );
              Provider.of<LayoutsProvider>(
                context,
                listen: false,
              ).addLayout(newLayout);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class EditLayoutDialog extends StatefulWidget {
  final Layouts layout;
  final int index;

  const EditLayoutDialog({required this.layout, required this.index});

  @override
  _EditLayoutDialogState createState() => _EditLayoutDialogState();
}

class _EditLayoutDialogState extends State<EditLayoutDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _basePhoto;
  late String _coordinatesText;

  @override
  void initState() {
    super.initState();
    _name = widget.layout.name;
    _basePhoto = widget.layout.basePhoto;
    _coordinatesText = widget.layout.coordinates
        .map((coord) => coord.join(', '))
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Layout'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                onSaved: (value) {
                  _name = value!;
                },
              ),
              ElevatedButton(
                onPressed: () async {
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['png'],
                      );
                  if (result != null && result.files.single.path != null) {
                    setState(() {
                      _basePhoto = result.files.single.path!;
                    });
                  }
                },
                child: const Text('Select Base Photo'),
              ),
              if (_basePhoto.isNotEmpty) Text('Selected: $_basePhoto'),
              TextFormField(
                initialValue: _coordinatesText,
                decoration: const InputDecoration(labelText: 'Coordinates'),
                maxLines: 5,
                onSaved: (value) {
                  _coordinatesText = value!;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              final coordinates =
                  _coordinatesText.split('\n').map((line) {
                    final parts =
                        line
                            .split(',')
                            .map((part) => int.parse(part.trim()))
                            .toList();
                    return parts;
                  }).toList();
              final updatedLayout = Layouts(
                name: _name,
                basePhoto: _basePhoto,
                id: widget.layout.id,
                coordinates: coordinates,
              );
              Provider.of<LayoutsProvider>(
                context,
                listen: false,
              ).editLayout(widget.index, updatedLayout);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
