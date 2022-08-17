import 'package:ncmb/ncmb.dart';
import 'package:flutter/material.dart';
import './login_page.dart';
import './chat_page.dart';

// アプリのメインStatefulWidget
class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// アプリのメインState
// ログイン状態をチェックして、ウィジェットを出し分ける
class _MyHomePageState extends State<MyHomePage> {
  NCMBUser? _user;

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  // ログインチェックを行う処理
  void checkLogin() async {
    final user = await NCMBUser.currentUser();
    setState(() {
      _user = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _user != null
        // ログインしている場合
        ? ChatPage(
            user: _user!,
          )
        // ログインしていない場合
        : LoginPage(
            // ログインした際に呼ばれるイベント
            onLogin: checkLogin);
  }
}
