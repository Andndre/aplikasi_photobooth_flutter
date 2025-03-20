import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../providers/start_event.dart';
import 'sesi_foto.dart';
import 'package:aplikasi_photobooth_flutter/providers/sesi_foto.dart';

class StartEvent extends StatefulWidget {
  final Event event;

  const StartEvent({required this.event, super.key});

  @override
  _StartEventState createState() => _StartEventState();
}

class _StartEventState extends State<StartEvent> {
  Future<void> _navigateToSesiFoto(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => ChangeNotifierProvider(
              create: (_) => SesiFotoProvider(),
              child: SesiFoto(event: widget.event),
            ),
      ),
    );
    await Provider.of<StartEventProvider>(
      context,
      listen: false,
    ).loadCompositeImages(widget.event.uploadFolder);
  }

  Future<void> _refreshCompositeImages(BuildContext context) async {
    await Provider.of<StartEventProvider>(
      context,
      listen: false,
    ).loadCompositeImages(widget.event.uploadFolder);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider = StartEventProvider();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          provider.loadCompositeImages(widget.event.uploadFolder);
        });
        return provider;
      },
      child: Consumer<StartEventProvider>(
        builder: (context, startEventProvider, child) {
          return Scaffold(
            appBar: AppBar(title: Text('Start Event: ${widget.event.name}')),
            body: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.enter):
                    () => _navigateToSesiFoto(context),
                const SingleActivator(LogicalKeyboardKey.keyR, control: true):
                    () => _refreshCompositeImages(context),
              },
              child: Focus(
                autofocus: true,
                child: Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => _refreshCompositeImages(context),
                        child:
                            startEventProvider.isLoading
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : startEventProvider.compositeImages.isEmpty
                                ? const Center(
                                  child: Text('No composite images found.'),
                                )
                                : GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 4.0,
                                        mainAxisSpacing: 4.0,
                                      ),
                                  itemCount:
                                      startEventProvider.compositeImages.length,
                                  itemBuilder: (context, index) {
                                    return Image.file(
                                      startEventProvider.compositeImages[index],
                                    );
                                  },
                                ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: () => _navigateToSesiFoto(context),
                        child: const Text('Mulai Sesi Foto'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
