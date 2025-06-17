import 'package:flutter/material.dart';
import 'package:flutter_tawkto/flutter_tawk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiveTawkChat extends StatelessWidget {
  final String userName;
  final String userEmail;

  LiveTawkChat({
    Key? key,
    required this.userName,
    required this.userEmail,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String engLink = "https://tawk.to/chat/684ffce6e1d1cb191104095d/1ituthmmu";
    String arabicLink = "https://tawk.to/chat/684ffce6e1d1cb191104095d/1its77pm3";

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Get language from SharedPreferences, default to 'en' if not set
        String _language = snapshot.data!.getString('language') ?? 'en';
        // Select chat link based on language
        String chatLink = _language.toLowerCase() == 'ar' ? arabicLink : engLink;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.white,
            centerTitle: true,
            toolbarHeight: 0,
          ),
          body: Tawk(
            directChatLink: chatLink,
            visitor: TawkVisitor(name: userName, email: userEmail),
            onLoad: () {
              print('Hello Tawk!');
            },
            onLinkTap: (String url) {
              print(url);
            },
            placeholder: const Center(child: Text('Loading...')),
          ),
        );
      },
    );
  }
}