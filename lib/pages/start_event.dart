import 'dart:io';
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
  @override
  void initState() {
    super.initState();
    // Call loadCompositeImages after the widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StartEventProvider>(
        context,
        listen: false,
      ).loadCompositeImages(widget.event.uploadFolder);
    });
  }

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

  void _showImagePreview(BuildContext context, int index, List<File> images) {
    if (images.isNotEmpty && index >= 0 && index < images.length) {
      showDialog(
        context: context,
        builder:
            (dialogContext) =>
                ImagePreview(images: images, initialIndex: index),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StartEventProvider>(
      builder: (context, startEventProvider, child) {
        final compositeImages = startEventProvider.compositeImages;

        return Scaffold(
          appBar: AppBar(title: Text('Start Event: ${widget.event.name}')),
          body: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.enter):
                  () => _navigateToSesiFoto(context),
              const SingleActivator(LogicalKeyboardKey.keyR, control: true):
                  () => _refreshCompositeImages(context),
            },
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _refreshCompositeImages(context),
                    child:
                        startEventProvider.isLoading
                            ? const Center(child: CircularProgressIndicator())
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
                                return GestureDetector(
                                  onTap:
                                      () => _showImagePreview(
                                        context,
                                        index,
                                        compositeImages,
                                      ),
                                  child: Image.file(
                                    startEventProvider.compositeImages[index],
                                  ),
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
        );
      },
    );
  }
}

class ImagePreview extends StatefulWidget {
  final List<File> images;
  final int initialIndex;

  const ImagePreview({
    required this.images,
    required this.initialIndex,
    Key? key,
  }) : super(key: key);

  @override
  _ImagePreviewState createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _nextImage() {
    setState(() {
      if (_currentIndex < widget.images.length - 1) {
        _currentIndex++;
      }
    });
  }

  void _previousImage() {
    setState(() {
      if (_currentIndex > 0) {
        _currentIndex--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(child: Image.file(widget.images[_currentIndex])),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (_currentIndex > 0)
            Positioned(
              left: 20,
              top: MediaQuery.of(context).size.height / 2 - 30,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_left,
                  color: Colors.white,
                  size: 50,
                ),
                onPressed: _previousImage,
              ),
            ),
          if (_currentIndex < widget.images.length - 1)
            Positioned(
              right: 20,
              top: MediaQuery.of(context).size.height / 2 - 30,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_right,
                  color: Colors.white,
                  size: 50,
                ),
                onPressed: _nextImage,
              ),
            ),
        ],
      ),
    );
  }
}
