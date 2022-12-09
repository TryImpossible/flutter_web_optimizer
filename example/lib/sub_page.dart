import 'package:flutter/material.dart';

class SubPage extends StatelessWidget {
  const SubPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('子页面')),
      body: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: Image.asset('assets/images/lufei.jpeg'),
        ),
      ),
    );
  }
}
