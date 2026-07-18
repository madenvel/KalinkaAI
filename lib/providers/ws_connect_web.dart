import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectWs(Uri uri, {required Duration pingInterval}) =>
    WebSocketChannel.connect(uri);
