import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../providers/sesi_foto.dart';
import '../providers/layouts.dart';

class SesiFoto extends StatefulWidget {
  final Event event;

  const SesiFoto({required this.event, super.key});

  @override
  SesiFotoState createState() => SesiFotoState();
}

class SesiFotoState extends State<SesiFoto> {
  int _photoCount = 1; // Start from 1

  @override
  Widget build(BuildContext context) {
    final sesiFotoProvider = Provider.of<SesiFotoProvider>(context);
    final layoutsProvider = Provider.of<LayoutsProvider>(
      context,
      listen: false,
    );

    return FutureBuilder(
      future: layoutsProvider.loadLayouts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else {
          final layout = widget.event.getLayout(context);

          return Scaffold(
            appBar: AppBar(title: Text('Sesi Foto: ${widget.event.name}')),
            body: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.enter): () async {
                  // if (_photoCount <= layout.coordinates.length) {
                  //   await sesiFotoProvider.takePhoto(
                  //     widget.event.saveFolder,
                  //     widget.event.uploadFolder,
                  //     widget.event.name,
                  //     layout.coordinates,
                  //     layout.basePhoto,
                  //     context,
                  //   );
                  //   setState(() {
                  //     _photoCount++;
                  //   });
                  // }
                },
              },
              child: Focus(
                autofocus: true,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: const Center(
                            child: Text(
                              'Press Enter to Take Photo',
                              style: TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 4.0,
                                  mainAxisSpacing: 4.0,
                                ),
                            itemCount: sesiFotoProvider.takenPhotos.length,
                            itemBuilder: (context, index) {
                              return Image.file(
                                sesiFotoProvider.takenPhotos[index],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    if (sesiFotoProvider.isLoading)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(sesiFotoProvider.loadingMessage),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }
}
