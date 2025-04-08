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
    if (images.isEmpty || index < 0 || index >= images.length) return;

    showDialog(
      context: context,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Image.file(images[index], fit: BoxFit.contain),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
                if (index > 0)
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white70,
                        size: 36,
                      ),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _showImagePreview(context, index - 1, images);
                      },
                    ),
                  ),
                if (index < images.length - 1)
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white70,
                        size: 36,
                      ),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _showImagePreview(context, index + 1, images);
                      },
                    ),
                  ),
                Positioned(
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      "${index + 1} / ${images.length}",
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
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
                title: Text('Gallery ${widget.eventName}'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  PopupMenuButton<SortOrder>(
                    icon: const Icon(Icons.sort),
                    onSelected:
                        (order) => provider.setSortOrder(order), // Fixed
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
                                crossAxisSpacing: 12.0,
                                mainAxisSpacing: 12.0,
                              ),
                          itemCount: compositeImages.length,
                          itemBuilder: (context, index) {
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              elevation: 3.0,
                              child: InkWell(
                                onTap:
                                    () => _showImagePreview(
                                      context,
                                      index,
                                      compositeImages,
                                    ),
                                child: Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black12,
                                        image: DecorationImage(
                                          image: FileImage(
                                            compositeImages[index],
                                          ),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.3),
                                            ],
                                            stops: const [0.7, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
