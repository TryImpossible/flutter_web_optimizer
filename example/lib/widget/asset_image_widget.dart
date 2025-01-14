import 'package:flutter/material.dart';

class AssetImageWidget extends StatelessWidget {
  const AssetImageWidget(this.name, {super.key});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Image.asset(name);
  }
}
