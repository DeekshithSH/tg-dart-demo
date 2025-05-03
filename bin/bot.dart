import 'package:t/t.dart' as t;
import 'package:bot/client.dart';

final apiId = YOUR_API_ID;
final apiHash = 'YOUR_API_HASH';
final botToken = 'YOUR_BOT_TOKEN';

Future<void> main() async {
  final session = TelegramSessionClient(apiId: apiId, apiHash: apiHash);

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
