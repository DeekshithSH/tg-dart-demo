import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:socks5_proxy/socks.dart';
import 'package:t/t.dart' as t;
import 'package:tg/tg.dart' as tg;

class TelegramSessionClient {
  final int apiId;
  final String apiHash;
  final void Function(t.UpdatesBase update)? onUpdate;

  Socket? _socket;
  StreamController<Uint8List>? _sender;
  StreamController<Uint8List>? _receiver;
  late tg.Obfuscation _obf;
  tg.Client? _client;

  TelegramSessionClient({
    required this.apiId,
    required this.apiHash,
    this.onUpdate,
  });

  Future<void> connect([String ip = '149.154.167.50', int port = 443]) async {
    await close();

    print("Connecting to $ip:$port");
    _obf = tg.Obfuscation.random(false, 4);
    _socket = await Socket.connect(ip, port);
    // final _socket = await SocksTCPClient.connect(
    //   [
    //     ProxySettings(InternetAddress.loopbackIPv4, 1080),
    //   ],
    //   InternetAddress(ip),
    //   port,
    // );
    print("Done");
    _sender = StreamController<Uint8List>();
    _receiver = StreamController<Uint8List>.broadcast();

    _sender!.stream.listen(_socket!.add);
    _socket!.listen(_receiver!.add);

    _client = tg.Client(
      sender: _sender!.sink,
      receiver: _receiver!.stream,
      obfuscation: _obf,
      session: null,
    );

    if (onUpdate != null) {
      _client!.stream.listen(onUpdate!);
    }

    await _client!.initConnection<t.Config>(
      apiId: apiId,
      deviceModel: Platform.operatingSystem,
      appVersion: "1.0.0",
      systemVersion: Platform.operatingSystemVersion,
      systemLangCode: "en",
      langCode: "en",
      langPack: "",
      proxy: null,
      params: null,
      query: t.HelpGetConfig(),
    );
  }

  Future<t.Result<t.AuthAuthorizationBase>> start({required String botToken}) async {
    final c = _client;
    if (c == null) throw Exception("Client not connected");

    final auth = await c.auth.importBotAuthorization(
      flags: 0,
      apiId: apiId,
      apiHash: apiHash,
      botAuthToken: botToken,
    );

    if (auth.error == null) return auth;

    if (auth.error?.errorCode == 303) {
      final configResult = await c.help.getConfig();
      final config = configResult.result;
      if (config is! t.Config) {
        throw Exception("Unexpected config type: ${config.runtimeType}");
      }

      final dcOptions = config.dcOptions.cast<t.DcOption>();
      final match = RegExp(r'\d+').firstMatch(auth.error!.errorMessage);
      final dcId = int.parse(match!.group(0)!);
      final dc = dcOptions.firstWhere(
        (opt) => opt.id == dcId && !opt.ipv6 && !opt.mediaOnly,
      );

      await connect(dc.ipAddress, dc.port);
      await Future.delayed(Duration(seconds: 1));
      return await start(botToken: botToken);
    } else if (auth.error?.errorCode == 420){
      final match = RegExp(r'\d+').firstMatch(auth.error!.errorMessage);
      final sleep_time = int.parse(match!.group(0)!);
      print("sleeping for $sleep_time seconds");
      await Future.delayed(Duration(seconds: sleep_time));
      return await start(botToken: botToken);
    } else {
      throw Exception("Unhandled Error: ${auth.error}");
    }
  }

  tg.Client? get client => _client;

  Future<void> close() async {
    await _sender?.close();
    await _receiver?.close();
    await _socket?.close();
    _client = null;
    _socket = null;
    _sender = null;
    _receiver = null;
  }
}

t.DcOption findDcOption({
  required List<t.DcOption> dcOptions,
  required int dcId,
  bool ipv6 = false,
  bool mediaOnly = false,
}) {
  return dcOptions.firstWhere(
    (item) =>
        item.id == dcId && (item.ipv6 == ipv6) && item.mediaOnly == mediaOnly,
  );
}