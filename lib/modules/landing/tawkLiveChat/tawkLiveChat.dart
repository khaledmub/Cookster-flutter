import 'package:flutter/material.dart';
import 'package:flutter_tawkto/flutter_tawk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
        final sanitizedName = userName.trim();
        final sanitizedEmail = userEmail.trim();
        final hasValidEmail = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(
          sanitizedEmail,
        );
        final TawkVisitor? visitor =
            hasValidEmail && sanitizedName.isNotEmpty
                ? TawkVisitor(name: sanitizedName, email: sanitizedEmail)
                : null;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: true,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.white,
            centerTitle: true,
            title: Text('Customer Support'),
            actions: [
              IconButton(
                tooltip: 'Open in browser',
                icon: const Icon(Icons.open_in_new),
                onPressed: () async {
                  final uri = Uri.parse(chatLink);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
              ),
            ],
          ),
          body: Tawk(
            directChatLink: chatLink,
            visitor: visitor,
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