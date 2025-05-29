import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:t/t.dart' as t;
import 'package:bot/client.dart';
import 'package:dotenv/dotenv.dart';

var env = DotEnv(includePlatformEnvironment: true)..load();

late final TelegramSessionClient session;

Future<void> main() async {
  if (!env.isEveryDefined(['API_ID', 'API_HASH', "BOT_TOKEN"])){
    print("Missing required envs");
    return;
  }
  final apiId = int.parse(env['API_ID']!);
  final apiHash = env['API_HASH']!;
  final botToken = env['BOT_TOKEN']!;

  final sessionData = loadSession();
  session = TelegramSessionClient(
    apiId: apiId,
    apiHash: apiHash,
    onUpdate: handleUpdates,
    session: sessionData,
    useSocks: true
    );

  await session.connect(t.DcOption(ipv6: false, mediaOnly: false, tcpoOnly: false, cdn: false, static: false, thisPortOnly: false, id: 1, ipAddress: "149.154.175.51", port: 443));
  await Future.delayed(Duration(seconds: 1));
  if(sessionData==null){
    await session.start(botToken: botToken);
    print("Account authorized");
  }
  print("Done");

  final client = session.client;
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

  ProcessSignal.sigint.watch().listen((signal) async {
    print('Received SIGINT, shutting down gracefully...');
    await File("session.json").writeAsString(jsonEncode(session.exportSession()));
    await session.close();
    print('Cleanup done. Exiting.');
    exit(0);
  });

}

void handleUpdates(t.UpdatesBase update) async{
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
  final client = session.client;
  if (client == null) return ;
  await client.messages.sendMessage(
    noWebpage: false,
    silent: false,
    background: false,
    clearDraft: false,
    noforwards: false,
    updateStickersetsOrder: false,
    invertMedia: false,
    allowPaidFloodskip: false,
    peer: t.InputPeerUser(userId: chat.id, accessHash: chat.accessHash ?? 0),
    message: message.message,
    randomId: generateRandomId()
  );
}

int generateRandomId() {
  final random = Random.secure();
  final buffer = Uint8List(8);
  for (int i = 0; i < 8; i++) {
    buffer[i] = random.nextInt(256);
  }
  return ByteData.sublistView(buffer).getInt64(0, Endian.little);
}

Map<String, dynamic>? loadSession() {
  try {
    final text = File('session.json').readAsStringSync();
    return jsonDecode(text);
  } catch (e) {
    return null;
  }
}