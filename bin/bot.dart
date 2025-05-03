import 'dart:math';
import 'dart:typed_data';

import 'package:t/t.dart' as t;
import 'package:bot/client.dart';

final apiId = YOUR_API_ID;
final apiHash = 'YOUR_API_HASH';
final botToken = 'YOUR_BOT_TOKEN';

final session = TelegramSessionClient(apiId: apiId, apiHash: apiHash, onUpdate: handleUpdates);

Future<void> main() async {
  await session.connect();
  await Future.delayed(Duration(seconds: 1));
  await session.start(botToken: botToken);
  print("Account authorized");

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
