import 'package:flutter/material.dart';
import 'asset_image_widget.dart' deferred as image_widget;

class ImageWidget extends StatelessWidget {
  const ImageWidget.lufei({super.key}) : name = 'assets/images/lufei.jpeg';
  final String name;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: image_widget.loadLibrary(),
      builder: (_, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return image_widget.AssetImageWidget(name);
        } else {
          return const CircularProgressIndicator();
        }
      },
    );
  }
}
