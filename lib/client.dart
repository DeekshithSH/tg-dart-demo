import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:socks5_proxy/socks.dart';
import 'package:t/t.dart' as t;
import 'package:tg/tg.dart' as tg;

class ConnTriple {
  final Socket socket;
  final StreamController<Uint8List> sender;
  final StreamController<Uint8List> receiver;

  ConnTriple(this.socket, this.sender, this.receiver);
}


class TelegramSessionClient {
  final int apiId;
  final String apiHash;
  final void Function(t.UpdatesBase update)? onUpdate;
  final Map<String, dynamic>? session;
  final bool useSocks;

  Socket? _socket;
  StreamController<Uint8List>? _sender;
  StreamController<Uint8List>? _receiver;
  late tg.Obfuscation _obf;
  tg.Client? _client;
  Map<int, tg.Client> mediaClient = {};
  Map<int, ConnTriple> mediaConn = {};
  int? dcId;

  List<t.DcOption> _dc = [t.DcOption(
    ipv6: false,
    mediaOnly: false,
    tcpoOnly: false,
    cdn: false,
    static: false,
    thisPortOnly: false,
    id: 4,
    ipAddress: '149.154.167.92',
    port: 443,
  )];

  TelegramSessionClient({
    required this.apiId,
    required this.apiHash,
    this.onUpdate,
    this.session,
    this.useSocks = false
  });

  Future<void> connect(t.DcOption? dc) async {
    await close();
    final data = session;
    if(data != null){
      dcId = data["dc_id"] as int;
      dc = t.DcOption(
        ipv6: false,
        mediaOnly: false,
        tcpoOnly: false,
        cdn: false,
        static: false,
        thisPortOnly: false,
        id: data["dc_id"] as int,
        ipAddress: data["ip"],
        port: data["port"] as int
      );
    }else{
      dc ??= _dc[0];
      dcId=dc.id;
    }

    print("Connecting to ${dc.ipAddress}:${dc.port}");
    _obf = tg.Obfuscation.random(false, 4);
    if (useSocks){
      _socket = await SocksTCPClient.connect(
        [
          ProxySettings(InternetAddress.loopbackIPv4, 1080),
        ],
        InternetAddress(dc.ipAddress),
        dc.port,
      );
    } else {
      _socket = await Socket.connect(dc.ipAddress, dc.port);
    }

    print("Done");
    _sender = StreamController<Uint8List>();
    _receiver = StreamController<Uint8List>.broadcast();

    _sender!.stream.listen(_socket!.add);
    _socket!.listen(_receiver!.add);

    _client = tg.Client(
      sender: _sender!.sink,
      receiver: _receiver!.stream,
      obfuscation: _obf,
      authKey: data != null? t.AuthorizationKey.fromJson(data["auth_key"]): null
    );

    if(session != null){
      await _client!.connect();
    }

    if (onUpdate != null) {
      _client!.stream.listen(onUpdate!);
    }
    print("Sending Init Connection request");
    final config = await _client!.initConnection<t.Config>(
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
    if (config.result?.dcOptions is List) {
      _dc = List<t.DcOption>.from(config.result!.dcOptions);
    }
    print("Done");
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

      final match = RegExp(r'\d+').firstMatch(auth.error!.errorMessage);
      final dcId = int.parse(match!.group(0)!);
      final dc = _dc.firstWhere(
        (opt) => opt.id == dcId && !opt.ipv6 && !opt.mediaOnly,
      );

      await connect(dc);
      await Future.delayed(Duration(seconds: 1));
      return await start(botToken: botToken);
    } else if (auth.error?.errorCode == 420){
      final match = RegExp(r'\d+').firstMatch(auth.error!.errorMessage);
      final sleepTime = int.parse(match!.group(0)!);
      print("sleeping for $sleepTime seconds");
      await Future.delayed(Duration(seconds: sleepTime));
      return await start(botToken: botToken);
    } else {
      throw Exception("Unhandled Error: ${auth.error}");
    }
  }

  Future<tg.Client> getDcClient(int clientDc) async{
    final client = _client;
    if (client == null){
      throw Exception("Client is not started yet");
    }

    if (clientDc == dcId){
      return client;
    }

    final dc = _dc.firstWhere(
      (opt) => opt.id == clientDc && !opt.ipv6 && !opt.mediaOnly,
    );

    final tempClient = mediaClient[dc.id];
    if (tempClient != null){
      return tempClient;
    }

    print("Connecting to ${dc.ipAddress}:${dc.port}");
    final obf = tg.Obfuscation.random(false, 4);
    final Socket socket;
    if (useSocks){
      socket = await SocksTCPClient.connect(
        [
          ProxySettings(InternetAddress.loopbackIPv4, 1080),
        ],
        InternetAddress(dc.ipAddress),
        dc.port,
      );
    } else {
      socket = await Socket.connect(dc.ipAddress, dc.port);
    }

    print("Done");
    final sender = StreamController<Uint8List>();
    final receiver = StreamController<Uint8List>.broadcast();

    sender.stream.listen(socket.add);
    socket.listen(receiver.add);

    final dcClient = tg.Client(
      sender: _sender!.sink,
      receiver: _receiver!.stream,
      obfuscation: obf,
    );
    print("Sending Init Connection request");
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
    print("Done");
    mediaClient[dc.id] = dcClient;
    mediaConn[dc.id] = ConnTriple(socket, sender, receiver);
    return dcClient;
  }

  Future<void> close() async {
    await _sender?.close();
    await _receiver?.close();
    await _socket?.close();
    _client = null;
    _socket = null;
    _sender = null;
    _receiver = null;
    // for (var c in mediaClient.values) {
      // no method exist to close client
    // }
    mediaClient.clear();
    for (var conn in mediaConn.values) {
      await conn.socket.close();
      await conn.sender.close();
      await conn.receiver.close();
    }
    mediaConn.clear();
  }

  Map<String, dynamic> exportSession(){
    final c = _client;
    if (c == null){
      throw Exception("Client not started yet");
    }
    final ak = c.authKey;
    if (ak == null) {
      throw Exception("AuthKey is null");
    }
    final dc = _dc.firstWhere((opt) => opt.id == dcId && !opt.ipv6 && !opt.mediaOnly);
    return {
      "auth_key": ak.toJson(),
      "api_id": apiId,
      "dc_id": dc.id,
      "ip": dc.ipAddress,
      "port": dc.port
    };
  }

  tg.Client? get client => _client;
}
