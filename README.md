Simple Telegram Bot

A simple command-line Telegram bot built with Dart.

This bot uses MTProto to authenticate using your bot token and prints the bot’s name and username.

---

Setup Instructions

1. Clone This repository
   ```sh
   git clone https://github.com/DeekshithSH/tg-dart-demo
   ```

2. Install dependencies
   Run this in your project root:
   ```sh
   dart pub get
   ```

3. Update credentials
   Open bin/bot.dart and update the following constants:

   ```
   apiId = YOUR_API_ID;
   apiHash = 'YOUR_API_HASH';
   botToken = 'YOUR_BOT_TOKEN';
   ```

   You can obtain
   - API ID and Hash from https://my.telegram.org
   - Bot Token from https://t.me/BotFather


4. Run the bot
   ```sh
   dart run
   ```

   If successful, your bot’s display name and username will be printed.

---

- The entry point of the application is in the bin/ directory.