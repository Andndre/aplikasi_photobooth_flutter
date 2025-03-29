import 'package:flutter/material.dart';
import 'package:photobooth/components/common/date_picker_field.dart';
import 'package:photobooth/components/common/dialog_buttons.dart';
import 'package:photobooth/components/common/dialog_header.dart';
import 'package:photobooth/components/common/folder_selector.dart';
import 'package:photobooth/components/common/layout_dropdown.dart';
import 'package:photobooth/models/event_model.dart';
import 'package:photobooth/providers/event_provider.dart';
import 'package:provider/provider.dart';

class EditEventDialog extends StatefulWidget {
  final EventModel event;
  final int index;

  const EditEventDialog({super.key, required this.event, required this.index});

  @override
  EditEventDialogState createState() => EditEventDialogState();
}

class EditEventDialogState extends State<EditEventDialog> {
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DialogHeader(
                title: 'Edit Event',
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        initialValue: _name,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'Enter event name',
                          border: OutlineInputBorder(),
                          filled: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an event name';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          _name = value!;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _description,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Enter event description',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                          filled: true,
                        ),
                        maxLines: 5,
                        onSaved: (value) {
                          _description = value!;
                        },
                      ),
                      const SizedBox(height: 16),
                      DatePickerField(
                        selectedDate: _selectedDate,
                        onDateChanged: (date) {
                          setState(() {
                            _selectedDate = date;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      LayoutDropdown(
                        value: _layoutId,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _layoutId = value;
                            });
                          }
                        },
                        onSaved: (value) {
                          if (value != null) {
                            _layoutId = value;
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Folders',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      FolderSelector(
                        label: 'Save Folder',
                        hint: 'Select folder where photos will be saved',
                        icon: Icons.save,
                        selectedPath: _saveFolder,
                        onSelectFolder: (path) {
                          setState(() {
                            _saveFolder = path;
                          });
                        },
                        required: true,
                      ),
                      const SizedBox(height: 16),
                      FolderSelector(
                        label: 'Upload Folder',
                        hint: 'Select folder where composites will be saved',
                        icon: Icons.upload_file,
                        selectedPath: _uploadFolder,
                        onSelectFolder: (path) {
                          setState(() {
                            _uploadFolder = path;
                          });
                        },
                        required: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              DialogButtons(
                cancelText: 'Cancel',
                confirmText: 'Save Changes',
                onCancel: () => Navigator.of(context).pop(),
                onConfirm: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    final updatedEvent = EventModel(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
