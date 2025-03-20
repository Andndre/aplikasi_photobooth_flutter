import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/event.dart';
import '../providers/events.dart';
import '../providers/layouts.dart';
import '../providers/start_event.dart';
import 'layout_manager.dart';
import 'event_detail.dart';
import 'start_event.dart';

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photobooth')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder(
              future:
                  Provider.of<EventsProvider>(
                    context,
                    listen: false,
                  ).loadEvents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  return Consumer<EventsProvider>(
                    builder: (context, eventsProvider, child) {
                      if (eventsProvider.events.isEmpty) {
                        return const Center(
                          child: Text('No events available.'),
                        );
                      } else {
                        return ListView.builder(
                          itemCount: eventsProvider.events.length,
                          itemBuilder: (context, index) {
                            final event = eventsProvider.events[index];
                            return ListTile(
                              title: Text(event.name),
                              subtitle: Text(event.description),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.visibility),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  EventDetail(event: event),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return EditEventDialog(
                                            event: event,
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
                                              'Are you sure you want to delete this event?',
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
                                                  Provider.of<EventsProvider>(
                                                    context,
                                                    listen: false,
                                                  ).removeEvent(index);
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
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (
                                                context,
                                              ) => ChangeNotifierProvider(
                                                create:
                                                    (_) => StartEventProvider(),
                                                child: StartEvent(event: event),
                                              ),
                                        ),
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
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LayoutManager()),
              );
            },
            child: const Text('Manage Layouts'),
          ),
          ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AddEventDialog();
                },
              );
            },
            child: const Text('Add Event'),
          ),
        ],
      ),
    );
  }
}

class AddEventDialog extends StatefulWidget {
  @override
  _AddEventDialogState createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _description = '';
  DateTime _selectedDate = DateTime.now();
  int _layoutId = 0;
  String _saveFolder = '';
  String _uploadFolder = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Event'),
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
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                onSaved: (value) {
                  _description = value!;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Date'),
                readOnly: true,
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null && picked != _selectedDate) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                controller: TextEditingController(
                  text: "${_selectedDate.toLocal()}".split(' ')[0],
                ),
              ),
              Consumer<LayoutsProvider>(
                builder: (context, layoutsProvider, child) {
                  return DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Layout'),
                    items:
                        layoutsProvider.layouts.map((layout) {
                          return DropdownMenuItem<int>(
                            value: layout.id,
                            child: Text(layout.name),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _layoutId = value!;
                      });
                    },
                    onSaved: (value) {
                      _layoutId = value!;
                    },
                  );
                },
              ),
              ElevatedButton(
                onPressed: () async {
                  String? selectedDirectory =
                      await FilePicker.platform.getDirectoryPath();
                  if (selectedDirectory != null) {
                    setState(() {
                      _saveFolder = selectedDirectory;
                    });
                  }
                },
                child: const Text('Select Save Folder'),
              ),
              if (_saveFolder.isNotEmpty) Text('Selected: $_saveFolder'),
              ElevatedButton(
                onPressed: () async {
                  String? selectedDirectory =
                      await FilePicker.platform.getDirectoryPath();
                  if (selectedDirectory != null) {
                    setState(() {
                      _uploadFolder = selectedDirectory;
                    });
                  }
                },
                child: const Text('Select Upload Folder'),
              ),
              if (_uploadFolder.isNotEmpty) Text('Selected: $_uploadFolder'),
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
              final newEvent = Event(
                name: _name,
                description: _description,
                date: _selectedDate.toIso8601String(),
                layoutId: _layoutId,
                saveFolder: _saveFolder,
                uploadFolder: _uploadFolder,
              );
              Provider.of<EventsProvider>(
                context,
                listen: false,
              ).addEvent(newEvent);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class EditEventDialog extends StatefulWidget {
  final Event event;
  final int index;

  const EditEventDialog({required this.event, required this.index});

  @override
  _EditEventDialogState createState() => _EditEventDialogState();
}

class _EditEventDialogState extends State<EditEventDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _description;
  late DateTime _selectedDate;
  late int _layoutId;
  late String _saveFolder;
  late String _uploadFolder;

  @override
  void initState() {
    super.initState();
    _name = widget.event.name;
    _description = widget.event.description;
    _selectedDate = DateTime.parse(widget.event.date);
    _layoutId = widget.event.layoutId;
    _saveFolder = widget.event.saveFolder;
    _uploadFolder = widget.event.uploadFolder;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Event'),
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
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                onSaved: (value) {
                  _description = value!;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Date'),
                readOnly: true,
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null && picked != _selectedDate) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                controller: TextEditingController(
                  text: "${_selectedDate.toLocal()}".split(' ')[0],
                ),
              ),
              Consumer<LayoutsProvider>(
                builder: (context, layoutsProvider, child) {
                  return DropdownButtonFormField<int>(
                    value: _layoutId,
                    decoration: const InputDecoration(labelText: 'Layout'),
                    items:
                        layoutsProvider.layouts.map((layout) {
                          return DropdownMenuItem<int>(
                            value: layout.id,
                            child: Text(layout.name),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _layoutId = value!;
                      });
                    },
                    onSaved: (value) {
                      _layoutId = value!;
                    },
                  );
                },
              ),
              ElevatedButton(
                onPressed: () async {
                  String? selectedDirectory =
                      await FilePicker.platform.getDirectoryPath();
                  if (selectedDirectory != null) {
                    setState(() {
                      _saveFolder = selectedDirectory;
                    });
                  }
                },
                child: const Text('Select Save Folder'),
              ),
              if (_saveFolder.isNotEmpty) Text('Selected: $_saveFolder'),
              ElevatedButton(
                onPressed: () async {
                  String? selectedDirectory =
                      await FilePicker.platform.getDirectoryPath();
                  if (selectedDirectory != null) {
                    setState(() {
                      _uploadFolder = selectedDirectory;
                    });
                  }
                },
                child: const Text('Select Upload Folder'),
              ),
              if (_uploadFolder.isNotEmpty) Text('Selected: $_uploadFolder'),
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
              final updatedEvent = Event(
                name: _name,
                description: _description,
                date: _selectedDate.toIso8601String(),
                layoutId: _layoutId,
                saveFolder: _saveFolder,
                uploadFolder: _uploadFolder,
              );
              Provider.of<EventsProvider>(
                context,
                listen: false,
              ).editEvent(widget.index, updatedEvent);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
