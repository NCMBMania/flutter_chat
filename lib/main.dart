import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ncmb/ncmb.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './my_home_page.dart';

void main() async {
  await dotenv.load();
  // NCMBの初期化
  NCMB(dotenv.env['APPLICATION_KEY']!, dotenv.env['CLIENT_KEY']!);
  runApp(const MyApp());
}

// アプリのメインStatelessWidget
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Chat'),
    );
  }
}
