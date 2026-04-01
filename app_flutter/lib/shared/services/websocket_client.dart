import 'package:web_socket_channel/web_socket_channel.dart';

class AppWebSocketClient {
  AppWebSocketClient(String url) : channel = WebSocketChannel.connect(Uri.parse(url));

  final WebSocketChannel channel;
}
