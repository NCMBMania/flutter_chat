import 'package:ncmb/ncmb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:html_unescape/html_unescape.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';

// チャット画面用StatefulWidget
class ChatPage extends StatefulWidget {
  const ChatPage({Key? key, required this.user}) : super(key: key);
  final NCMBUser user;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

// チャット画面用State
class _ChatPageState extends State<ChatPage> {
  // チャットメッセージを格納するリスト
  List<types.Message> _messages = [];
  // チャットユーザー情報
  late types.User _user;
  // WebSocket用オブジェクト
  late WebSocketChannel _channel;
  // HTMLのアンエスケープ処理用
  final _unescape = HtmlUnescape();
  // ファイル名用
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _initWebSocket(); // WebSocket接続
    _listenWebSocket(); // WebSocketリスナー
    _loadMessages(); // メッセージ取得
    _setUser(); // ユーザー情報セット
  }

  // WebSocketを初期化する
  void _initWebSocket() {
    _channel =
        WebSocketChannel.connect(Uri.parse(dotenv.env['WEBSOCKET_URL']!));
  }

  // WebSocketリスニングイベントを設定する
  void _listenWebSocket() {
    _channel.stream.listen((data) async {
      // メッセージ情報からNCMBObjectを復元する
      final map = json.decode(data) as Map<String, dynamic>;
      final object = _decodeNCMBObject(map['message'], 'Message') as NCMBObject;
      final user = _decodeNCMBObject(map['user'], 'user') as NCMBUser;
      // ユーザー情報を追加
      object.set('user', user);
      // NCMBObjectからチャットメッセージへ変換する
      final message = _createMessage(object);
      // メッセージを追加
      setState(() {
        _messages.insert(0, message);
      });
    });
  }

  // WebSocketのメッセージからNCMBObjectやNCMBUserを復元する
  Object _decodeNCMBObject(String str, String className) {
    final messageJson =
        json.decode(_unescape.convert(str)) as Map<String, dynamic>;
    // NCMBObjectとNCMBUserの出し分け
    final object = className == 'user' ? NCMBUser() : NCMBObject(className);
    object.sets(messageJson);
    return object;
  }

  // WebSocketでメッセージ送信
  void _sendMessage(NCMBObject object) {
    _channel.sink.add(jsonEncode(
        {'message': object.toString(), 'user': widget.user.toString()}));
  }

  /// チャット画面用のメッセージオブジェクトを作成します
  types.Message _createMessage(NCMBObject message) {
    // ユーザー情報とNCMBのメッセージから、ベースになる情報を作成
    var user = message.get('user') == null
        ? NCMBUser()
        : message.get('user') as NCMBUser;
    var messageJson = {
      'author': {
        'id': user.objectId!,
        'lastName': user.getString('displayName', defaultValue: '退会ユーザー'),
      },
      'id': message.objectId!,
      'createdAt': message
          .getDateTime('createDate', defaultValue: DateTime.now())
          .millisecondsSinceEpoch,
    };
    // ファイル名があるかどうかで処理分け
    if (message.containsKey('fileName')) {
      // 画像用メッセージ
      messageJson['type'] = 'image';
      // 画像表示用に必要な情報を設定
      messageJson['name'] = message.getString('fileName');
      messageJson['height'] = message.getDouble('height');
      messageJson['size'] = message.getInt('size');
      messageJson['uri'] =
          "${dotenv.env['NCMB_PUBLIC_FILE_PATH']}${message.getString('fileName')}";
      messageJson['width'] = message.getDouble('width');
    } else {
      // テキスト用メッセージの場合
      messageJson['type'] = 'text';
      messageJson['text'] = message.getString('message', defaultValue: '');
    }
    return types.Message.fromJson(messageJson);
  }

  // 既存のメッセージをNCMBから読み込む処理
  void _loadMessages() async {
    // メッセージを取得
    var query = NCMBQuery('Message');
    query.include('user');
    query.limit(100);
    query.order('createDate');
    final messages = await query.fetchAll();
    // NCMBのメッセージからチャット用メッセージに変換
    var chatMessages = messages.map((m) => _createMessage(m)).toList();
    // 表示を更新
    setState(() {
      _messages = chatMessages;
    });
  }

  // ログインユーザー情報をチャットユーザー情報に変換して設定する
  void _setUser() {
    _user = types.User(
        id: widget.user.objectId!,
        lastName: widget.user.getString('displayName'));
  }

  // メッセージ送信時のイベント処理
  void _onSendPressed(types.PartialText message) async {
    // NCMBObjectを作成して保存
    var object = await _createNCMBObject(message: message.text);
    await object.save();
    // WebSocketで送信
    _sendMessage(object);
  }

  // NCMBObjectを作成して返す
  Future<NCMBObject> _createNCMBObject(
      {String? message, String? fileName, Uint8List? bytes}) async {
    var object = NCMBObject('Message');
    // テキストメッセージの場合
    if (message != null) {
      object.set('message', message);
    }
    // 画像メッセージの場合
    if (fileName != null) {
      final image = await decodeImageFromList(bytes!);
      object.set('fileName', fileName);
      // 画像表示用に必要な情報を設定
      object.set('height', image.height.toDouble());
      object.set('size', bytes.length);
      object.set('width', image.width.toDouble());
    }
    object.set('user', widget.user);
    // ACL（アクセス権限）の設定
    var acl = NCMBAcl();
    acl
      ..setPublicReadAccess(true) // 誰でも読み込み可能
      ..setUserWriteAccess(widget.user, true); // 編集は自分だけ
    object.set('acl', acl);
    return object;
  }

  // 画像添付用のモーダルを表示するイベント
  void _handleAtachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleImageSelection(); // 画像選択ダイアログの表示など
                },
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(children: const [
                    Icon(Icons.image),
                    SizedBox(width: 8),
                    Text('画像を選択'),
                  ]),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(children: const [
                    Icon(Icons.close),
                    SizedBox(width: 8),
                    Text('キャンセル'),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 画像選択時の処理
  /// 画像をNCMBFileでアップロード後、ファイル名などをNCMBObjectに登録する
  void _handleImageSelection() async {
    // 画像の選択ダイアログ表示
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );
    // 選択された画像がない場合は終了
    if (result == null) return;
    // 選択されたファイルをUnit8Listに変換
    final bytes = await result.readAsBytes();
    // ファイル名の設定
    final fileName = result.mimeType == 'image/jpeg'
        ? '${_uuid.v4()}.jpg'
        : '${_uuid.v4()}.png';
    // ファイルアップロード
    await NCMBFile.upload(fileName, bytes);
    // ファイルと関連付けたNCMBObjectを作成
    var object = await _createNCMBObject(fileName: fileName, bytes: bytes);
    // NCMBObjectを保存
    await object.save();
    // WebSocketで送信
    _sendMessage(object);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: Chat(
          messages: _messages,
          onPreviewDataFetched:
              (types.TextMessage message, types.PreviewData previewData) {},
          onSendPressed: _onSendPressed,
          onAttachmentPressed: _handleAtachmentPressed,
          showUserAvatars: true,
          showUserNames: true,
          user: _user,
        ));
  }
}
