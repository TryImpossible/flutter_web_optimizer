import 'package:flutter/material.dart';
import 'widget/image_widget.dart';

class SubPage extends StatelessWidget {
  const SubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('子页面')),
      body: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: ImageWidget.lufei(),
        ),
      ),
    );
  }
}
