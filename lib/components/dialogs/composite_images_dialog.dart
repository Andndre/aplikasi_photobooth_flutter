import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photobooth/providers/sesi_foto.dart';
import 'package:provider/provider.dart';

class CompositeImagesDialog extends StatefulWidget {
  final String eventName;
  final String uploadFolder;

  const CompositeImagesDialog({
    super.key,
    required this.eventName,
    required this.uploadFolder,
  });

  @override
  State<CompositeImagesDialog> createState() => _CompositeImagesDialogState();
}

class _CompositeImagesDialogState extends State<CompositeImagesDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SesiFotoProvider>(
        context,
        listen: false,
      ).loadCompositeImages(widget.uploadFolder);
    });
  }

  void _showImagePreview(BuildContext context, int index, List<File> images) {
    if (images.isNotEmpty && index >= 0 && index < images.length) {
      showDialog(
        context: context,
        builder:
            (dialogContext) => Dialog(
              backgroundColor: Colors.black,
              child: Stack(
                children: [
                  Center(child: Image.file(images[index])),
                  Positioned(
                    top: 40,
                    left: 20,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  if (index > 0)
                    Positioned(
                      left: 20,
                      top: MediaQuery.of(context).size.height / 2 - 30,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_left,
                          color: Colors.white,
                          size: 50,
                        ),
                        onPressed: () => setState(() => index--),
                      ),
                    ),
                  if (index < images.length - 1)
                    Positioned(
                      right: 20,
                      top: MediaQuery.of(context).size.height / 2 - 30,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_right,
                          color: Colors.white,
                          size: 50,
                        ),
                        onPressed: () => setState(() => index++),
                      ),
                    ),
                ],
              ),
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SesiFotoProvider>(
      builder: (context, provider, child) {
        final compositeImages = provider.compositeImages;

        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text('Composite Images: ${widget.eventName}'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  PopupMenuButton<SortOrder>(
                    icon: const Icon(Icons.sort),
                    onSelected: provider.setSortOrder,
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: SortOrder.newest,
                            child: Text('Newest First'),
                          ),
                          const PopupMenuItem(
                            value: SortOrder.oldest,
                            child: Text('Oldest First'),
                          ),
                        ],
                  ),
                ],
              ),
              Flexible(
                child:
                    provider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : compositeImages.isEmpty
                        ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No composite images found.'),
                        )
                        : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8.0,
                                mainAxisSpacing: 8.0,
                              ),
                          itemCount: compositeImages.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap:
                                  () => _showImagePreview(
                                    context,
                                    index,
                                    compositeImages,
                                  ),
                              child: Image.file(
                                compositeImages[index],
                                fit: BoxFit.cover,
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}
