import 'package:ncmb/ncmb.dart';
import 'package:flutter/material.dart';

// ログイン画面用StatefulWidget
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key, required this.onLogin}) : super(key: key);
  final Function onLogin;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

// ログイン画面用State
class _LoginPageState extends State<LoginPage> {
  var _name = ''; // 入力してもらう表示名

  // ログイン処理
  void anonymousLogin() async {
    // 匿名認証でログイン
    final user = await NCMBUser.loginAsAnonymous();
    // 入力された表示名をセット
    user.set('displayName', _name);
    // 情報更新
    await user.save();
    // 完了イベントを呼ぶ
    widget.onLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Login')),
        body: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text(
            'チャットの名前を入力してください',
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 250,
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _name = value;
                    });
                  },
                ),
              ),
              TextButton(onPressed: anonymousLogin, child: const Text("ログインする"))
            ],
          )
        ]));
  }
}
