import 'package:flutter/material.dart';
import 'package:photobooth/components/dialogs/add_event_dialog.dart';
import 'package:photobooth/components/dialogs/delete_event_dialog.dart';
import 'package:photobooth/components/dialogs/edit_event_dialog.dart';
import 'package:photobooth/components/dialogs/event_detail_dialog.dart';
import 'package:photobooth/providers/event_provider.dart';
import 'package:photobooth/providers/layout_provider.dart';
import 'package:provider/provider.dart';

class EventPage extends StatelessWidget {
  const EventPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Events')),
      body: ListView(
        children: [
          // Events list
          SizedBox(
            height: MediaQuery.of(context).size.height - 100,
            child: FutureBuilder(
              future: Future.wait([
                Provider.of<EventsProvider>(
                  context,
                  listen: false,
                ).loadEvents(),
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
                                    ? Colors.red.shade900.withAlpha(102)
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
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
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
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return EventDetailDialog(
                                              event: event,
                                            );
                                          },
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
                                            return DeleteEventDialog(
                                              event: event,
                                              index: index,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.play_arrow),
                                      onPressed:
                                          layoutExists
                                              ? () {
                                                // Navigator.of(context).push(
                                                //   MaterialPageRoute(
                                                //     builder:
                                                //         (
                                                //           context,
                                                //         ) => ChangeNotifierProvider(
                                                //           create:
                                                //               (_) =>
                                                //                   StartEventProvider(),
                                                //           child: StartEvent(
                                                //             event: event,
                                                //           ),
                                                //         ),
                                                //   ),
                                                // );
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(context: context, builder: (context) => AddEventDialog());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
