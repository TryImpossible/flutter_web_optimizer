import 'package:flutter/material.dart';

class SubApp extends StatelessWidget {
  const SubApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('子应用')),
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
