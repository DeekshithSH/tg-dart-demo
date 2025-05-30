import 'package:tgram/tgram.dart';
import 'dart:convert';
import 'dart:io';

import 'package:t/t.dart' as t;
import 'package:dotenv/dotenv.dart';

var env = DotEnv(includePlatformEnvironment: true)..load();

late final TelegramClient tgclient;

Future<void> main() async {
  if (!env.isEveryDefined(['API_ID', 'API_HASH', "BOT_TOKEN"])){
    print("Missing required envs");
    return;
  }
  final apiId = int.parse(env['API_ID']!);
  final apiHash = env['API_HASH']!;
  final botToken = env['BOT_TOKEN']!;

  final sessionData = loadSession();
  tgclient = TelegramClient(
    apiId: apiId,
    apiHash: apiHash,
    onUpdate: handleUpdates,
    session: sessionData,
    useSocks: false
    );

  ProcessSignal.sigint.watch().listen((signal) async {
    print('Received SIGINT, shutting down gracefully...');
    await File("session.json").writeAsString(jsonEncode(tgclient.exportSession()));
    await tgclient.close();
    print('Cleanup done. Exiting.');
    exit(0);
  });

  await tgclient.connect();
  await Future.delayed(Duration(seconds: 1));
  if(sessionData==null){
    print("Authenticating");
    await tgclient.loginBot(botToken);
  }
  print("Account authorized");

  final client = tgclient.client;
  if (client == null) throw Exception("Client is null");

  final result = await client.users.getFullUser(id: t.InputUserSelf());
  final user = result.result;
  if (user is t.UsersUserFull && user.users.isNotEmpty) {
    final me = user.users[0] as t.User;
    print("Hello, I'm ${me.firstName}");
    print("You can find me using: @${me.username}");
  } else {
    print("Could not fetch user info");
  }
}

void handleUpdates(t.UpdatesBase update) async{
  print("Received update");
  if(update is t.Updates){
    for (final message in update.updates){
      if (message is t.UpdateNewMessage){
        final msg = message.message;
        if (msg is t.Message){
          // For now only private message
          t.User? user;
          t.User? chat;
          if (msg.peerId is t.PeerUser){
            final peer = msg.peerId as t.PeerUser;
            chat = update.users.whereType<t.User>().firstWhere((u) => u.id == peer.userId);
          }
          if (msg.fromId is t.PeerUser){
            final peer = msg.peerId as t.PeerUser;
            user = update.users.whereType<t.User>().firstWhere((u) => u.id == peer.userId);
          }
          if (chat != null) {
            handleMessage(msg, user, chat);
          }
        }
      }
    }
  }
}

Future handleMessage(t.Message message, t.User? user, t.User chat) async{
  final client = tgclient.client;
  if (client == null) return ;
  await tgclient.forwardMessage(
    fromPeer: t.InputPeerUser(userId: chat.id, accessHash: chat.accessHash ?? 0),
    toPeer: t.InputPeerUser(userId: chat.id, accessHash: chat.accessHash ?? 0),
    msgIds: [message.id],
    hideSender: true
  );
}

Map<String, dynamic>? loadSession() {
  try {
    final text = File('session.json').readAsStringSync();
    return jsonDecode(text);
  } catch (e) {
    return null;
  }
}