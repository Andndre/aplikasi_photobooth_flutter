import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../providers/events.dart';
import '../providers/layouts.dart';
import '../providers/start_event.dart';
import '../components/folder_selector.dart';
import '../components/date_picker_field.dart';
import '../components/layout_dropdown.dart';
import '../components/dialog_buttons.dart';
import '../components/dialog_header.dart';
import 'layout_manager.dart';
import 'event_detail.dart';
import 'start_event.dart';
import 'settings.dart';

enum MenuSection { events, layouts, settings }

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  // Drawer controller
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Width threshold for showing sidebar permanently
  final double _sidebarWidth = 250;
  final double _widthThreshold = 1100;

  // Current active section
  MenuSection _currentSection = MenuSection.events;

  @override
  Widget build(BuildContext context) {
    // Check if screen is wide enough for permanent sidebar
    final screenWidth = MediaQuery.of(context).size.width;
    final bool showSidebar = screenWidth >= _widthThreshold;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_getTitleForCurrentSection()),
        // Only show hamburger menu on small screens
        automaticallyImplyLeading: !showSidebar,
      ),
      // Drawer for small screens
      drawer: !showSidebar ? _buildSidebar(context) : null,
      // Add floating action button for creating new event
      floatingActionButton:
          _currentSection == MenuSection.events
              ? FloatingActionButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AddEventDialog(),
                  );
                },
                child: const Icon(Icons.add),
              )
              : null,
      body: Row(
        children: [
          // Left sidebar for large screens
          if (showSidebar)
            SizedBox(width: _sidebarWidth, child: _buildSidebar(context)),

          // Main content area based on current section
          Expanded(flex: 3, child: _buildSectionContent()),
        ],
      ),
    );
  }

  String _getTitleForCurrentSection() {
    switch (_currentSection) {
      case MenuSection.events:
        return 'Events';
      case MenuSection.layouts:
        return 'Layout Manager';
      case MenuSection.settings:
        return 'Settings';
    }
  }

  // Build content based on current section
  Widget _buildSectionContent() {
    switch (_currentSection) {
      case MenuSection.events:
        return _buildEventsContent();
      case MenuSection.layouts:
        return const LayoutManagerContent();
      case MenuSection.settings:
        return const SettingsPage();
    }
  }

  // Events section content
  Widget _buildEventsContent() {
    return ListView(
      children: [
        // Events list
        Container(
          height: MediaQuery.of(context).size.height - 100,
          child: FutureBuilder(
            future: Future.wait([
              Provider.of<EventsProvider>(context, listen: false).loadEvents(),
              Provider.of<LayoutsProvider>(
                context,
                listen: false,
              ).loadLayouts(),
            ]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else {
                return Consumer2<EventsProvider, LayoutsProvider>(
                  builder: (context, eventsProvider, layoutsProvider, child) {
                    if (eventsProvider.events.isEmpty) {
                      return const Center(
                        child: Text(
                          'No events available. Create one with the + button.',
                        ),
                      );
                    } else {
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: eventsProvider.events.length,
                        itemBuilder: (context, index) {
                          final event = eventsProvider.events[index];
                          final layoutExists = layoutsProvider.layoutExists(
                            event.layoutId,
                          );

                          // Determine the appropriate error color based on theme
                          final errorColor =
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.red.shade900.withOpacity(0.4)
                                  : Colors.red.shade100;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            color: layoutExists ? null : errorColor,
                            child: ListTile(
                              title: Text(event.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(event.description),
                                  if (!layoutExists)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        'Layout missing! Please edit this event.',
                                        style: TextStyle(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.error,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
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
                                      // ...existing code for delete dialog...
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    onPressed:
                                        layoutExists
                                            ? () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder:
                                                      (
                                                        context,
                                                      ) => ChangeNotifierProvider(
                                                        create:
                                                            (_) =>
                                                                StartEventProvider(),
                                                        child: StartEvent(
                                                          event: event,
                                                        ),
                                                      ),
                                                ),
                                              );
                                            }
                                            : null,
                                  ),
                                ],
                              ),
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
      ],
    );
  }

  // Sidebar with navigation
  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(3, 0),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hide close button in permanent sidebar
              if (MediaQuery.of(context).size.width < _widthThreshold)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Text(
                  'Photobooth App',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(),
              _buildNavigationItem(
                context,
                icon: Icons.event,
                title: 'Events',
                section: MenuSection.events,
              ),
              _buildNavigationItem(
                context,
                icon: Icons.photo_library,
                title: 'Layouts',
                section: MenuSection.layouts,
              ),
              _buildNavigationItem(
                context,
                icon: Icons.settings,
                title: 'Settings',
                section: MenuSection.settings,
              ),
              const Spacer(),
              const Divider(),
              // App info section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Version 1.0.0',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required MenuSection section,
  }) {
    final isSelected = _currentSection == section;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      tileColor:
          isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2)
              : null,
      onTap: () {
        // Close drawer on small screens
        if (MediaQuery.of(context).size.width < _widthThreshold) {
          Navigator.of(context).pop();
        }

        setState(() {
          _currentSection = section;
        });
      },
    );
  }
}

// Layout manager content embedded in main app
class LayoutManagerContent extends StatelessWidget {
  const LayoutManagerContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
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
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: ListTile(
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
                      ),
                    );
                  },
                );
              }
            },
          );
        }
      },
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
  int? _layoutId;
  String _saveFolder = '';
  String _uploadFolder = '';

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
                title: 'Add Event',
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
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
                          setState(() {
                            _layoutId = value;
                          });
                        },
                        onSaved: (value) {
                          _layoutId = value;
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
                confirmText: 'Create Event',
                onCancel: () => Navigator.of(context).pop(),
                onConfirm: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    final newEvent = Event(
                      name: _name,
                      description: _description,
                      date: _selectedDate.toIso8601String(),
                      layoutId: _layoutId!,
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
              ),
            ],
          ),
        ),
      ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
