import 'dart:convert';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:video_player/video_player.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('主页面'),
        actions: <Widget>[
          TextButton(
            onPressed: () => _goSubPage(context),
            child: const Text('进入子页面'),
          ),
        ],
      ),
      body: const SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _SVG(),
            _Video(),
            _Toast(),
            _GoogleFonts(),
            _PackageInfo(),
          ],
        ),
      ),
    );
  }

  void _goSubPage(BuildContext context) {
    Navigator.of(context).pushNamed('/sub');
  }
}

class _Video extends StatefulWidget {
  const _Video({super.key});

  @override
  State<_Video> createState() => _VideoState();
}

class _VideoState extends State<_Video> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    final Uri uri = Uri.parse(
        'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4');
    _videoPlayerController = VideoPlayerController.networkUrl(uri);
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoInitialize: true,
      aspectRatio: 16 / 9,
      autoPlay: true,
      looping: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
      child: AspectRatio(
        aspectRatio: _chewieController.aspectRatio ?? (16 / 9),
        child: Chewie(controller: _chewieController),
      ),
    );
  }
}

class _SVG extends StatelessWidget {
  const _SVG({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: SvgPicture.asset(
                'assets/svg/dart.svg',
                placeholderBuilder: (BuildContext context) => Container(
                  padding: const EdgeInsets.all(30.0),
                  child: const CircularProgressIndicator(),
                ),
              ),
            ),
            Expanded(
              child: SvgPicture.asset(
                'assets/svg/flutter_logo.svg',
                placeholderBuilder: (BuildContext context) => Container(
                  padding: const EdgeInsets.all(30.0),
                  child: const CircularProgressIndicator(),
                ),
              ),
            ),
          ],
        ),
        const Text(
          'this is svg',
          style: TextStyle(color: Colors.redAccent),
        ),
      ],
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ElevatedButton(
        onPressed: _showToast,
        child: const Text('Fluttertoast'),
      ),
    );
  }

  void _showToast() {
    Fluttertoast.showToast(
      msg: "This is Center Short Toast",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
      webPosition: 'center',
    );
  }
}

class _GoogleFonts extends StatelessWidget {
  const _GoogleFonts({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        // const Text('', style: TextStyle(color: Colors.black)),
        Text(
          'This is Google Fonts',
          style: GoogleFonts.acme(
            textStyle: Theme.of(context).textTheme.headlineMedium,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _PackageInfo extends StatelessWidget {
  const _PackageInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
        final Map<String, dynamic> info =
            snapshot.data?.data ?? <String, dynamic>{};
        final String value = JsonEncoder.withIndent('  ').convert(info);
        return Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            children: [
              Text('PackageInfo'),
              Text(value),
            ],
          ),
        );
      },
    );
  }
}
