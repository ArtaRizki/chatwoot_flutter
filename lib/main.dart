import 'dart:developer';
import 'dart:io';

import 'package:chatwoot_flutter_sdk/chatwoot_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Data pengguna Anda yang sudah benar
  final chatwootUser = ChatwootUser(
    identifier: "yuliarta.22173",
    name: "Yuliarta",
    email: "yuliarta.22173@mhs.unesa.ac.id",
  );

  // Data Website Token Anda yang sudah berhasil
  final websiteToken = "11VtaV2Bt6zy3EeRbEQaf9iY";
  final baseUrl = "https://app.chatwoot.com";
  @override
  void initState() {
    super.initState();
    init();
  }

  init() {
    final chatwootCallbacks = ChatwootCallbacks(
      onWelcome: () {
        log("on welcome");
      },
      onPing: () {
        log("on ping");
      },
      onConfirmedSubscription: () {
        log("on confirmed subscription");
      },
      onConversationStartedTyping: () {
        log("on conversation started typing");
      },
      onConversationStoppedTyping: () {
        log("on conversation stopped typing");
      },
      onPersistedMessagesRetrieved: (persistedMessages) {
        log("persisted messages retrieved");
      },
      onMessagesRetrieved: (messages) {
        log("messages retrieved");
      },
      onMessageReceived: (chatwootMessage) {
        log("message received");
      },
      onMessageDelivered: (chatwootMessage, echoId) {
        log("message delivered");
      },
      onMessageSent: (chatwootMessage, echoId) {
        log("message sent");
      },
      onError: (error) {
        log("Ooops! Something went wrong. Error Cause: ${error.cause}");
      },
    );

    ChatwootClient.create(
          baseUrl: "https://app.chatwoot.com",
          inboxIdentifier: 'ESdpDFzfSiYLimgVMzdXaEwD',
          user: chatwootUser,
          enablePersistence: true,
          callbacks: chatwootCallbacks,
        )
        .then((client) {
          log("CLIENT : ${client.user?.name ?? ''}");
          client.loadMessages();
        })
        .onError((error, stackTrace) {
          log("chatwoot client creation failed with error $error: $stackTrace");
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chatwoot Example")),
      body: SafeArea(
        child: ChatwootWidget(
          websiteToken: "11VtaV2Bt6zy3EeRbEQaf9iY",
          baseUrl: "https://app.chatwoot.com",
          user: chatwootUser,
          locale: "en",
          closeWidget: () {
            if (Platform.isAndroid) {
              SystemNavigator.pop();
            }
            //  else if (Platform.isIOS) {
            //   exit(0);
            // }
          },
          //attachment only works on android for now
          onAttachFile: _androidFilePicker,
          onLoadStarted: () {
            log("loading widget");
          },
          onLoadProgress: (int progress) {
            log("loading... $progress");
          },
          onLoadCompleted: () {
            log("widget loaded");
          },
        ),
      ),
    );
  }

  Future<List<String>> _androidFilePicker() async {
    final picker = image_picker.ImagePicker();
    final photo = await picker.pickImage(
      source: image_picker.ImageSource.gallery,
    );

    if (photo == null) {
      return [];
    }

    final imageData = await photo.readAsBytes();
    final decodedImage = image.decodeImage(imageData);
    final scaledImage = image.copyResize(decodedImage!, width: 500);
    final jpg = image.encodeJpg(scaledImage, quality: 90);

    final filePath = (await getTemporaryDirectory()).uri.resolve(
      './image_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final file = await File.fromUri(filePath).create(recursive: true);
    await file.writeAsBytes(jpg, flush: true);

    return [file.uri.toString()];
  }
}
