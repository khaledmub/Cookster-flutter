import 'package:flutter/material.dart';
import 'package:flutter_tawkto/flutter_tawk.dart';

class LiveTawkChat extends StatelessWidget {
  String userName;
  String userEmail;

  LiveTawkChat({Key? key, required this.userName, required this.userEmail})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        centerTitle: true,
        toolbarHeight: 0,
      ),
      body: Tawk(
        directChatLink:
            'https://tawk.to/chat/684ffce6e1d1cb191104095d/1its77pm3?lang=ar',
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
  }
}
