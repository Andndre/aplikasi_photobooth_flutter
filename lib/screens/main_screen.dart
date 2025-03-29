import 'package:flutter/material.dart';
import 'package:photobooth/pages/event_page.dart';
import 'package:photobooth/pages/layout_manager_page.dart';
import 'package:photobooth/pages/settings_page.dart';

enum MenuSection { events, layouts, settings }

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final double _sidebarWidth = 250;
  final double _widthThreshold = 1100;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  MenuSection _currentSection = MenuSection.events;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool showSidebar = screenWidth >= _widthThreshold;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_sectionTitleCurrent()),
        automaticallyImplyLeading: !showSidebar,
      ),
      drawer: showSidebar ? _buildSidebar(context) : null,
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

  Widget _buildSectionContent() {
    switch (_currentSection) {
      case MenuSection.events:
        return EventPage();
      case MenuSection.layouts:
        return const LayoutManager();
      case MenuSection.settings:
        return const SettingsPage();
    }
  }

  _sectionTitleCurrent() {
    switch (_currentSection) {
      case MenuSection.events:
        return 'Events';
      case MenuSection.layouts:
        return 'Layouts';
      case MenuSection.settings:
        return 'Settings';
    }
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
              color: Colors.black.withValues(alpha: 0.1),
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
              ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.2)
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
