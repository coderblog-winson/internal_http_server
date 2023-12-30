import 'dart:io';

import 'package:flutter/material.dart';
import 'package:internal_http_server/internal_http_server.dart';
import 'package:internal_http_server/logger.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Internal HTTP Server Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Internal HTTP Server Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var isListening = false;
  String buttonLabel = 'Start';

  final String server_description = ''' Description:
        <ul>
          <li>
            You can put your <strong>webserver</strong> description here 
          </li>
          <li>
          It's support any <strong style='color:red'>HTML</strong>, you can describe what you want to say
          </li>
        </ul>

        How to use:
        <ul>
          <li>1. You can drag and drop the file here or click the 'Upload File' button  to upload</li>
          <li>2. It's support larger file</li>
          <li>3. You can upload multiple files once time</li>
        </ul>
       ''';

  InternalHttpServer server = InternalHttpServer(
    title: 'Testing Web Server',
    address: InternetAddress.anyIPv4,
    port: 8080,
    logger: const DebugLogger(),
  );

  @override
  Widget build(BuildContext context) {
    // set the description
    server.setDescription(server_description);

    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(
              height: 50,
            ),
            const SizedBox(
              width: 300,
              child: Text(
                'Please connect to the same wifi network and you can access the below address in your browser from PC',
                style: TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(
              height: 50,
            ),
            FutureBuilder(
                future: getCurrentIP(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(
                      'http://${snapshot.data!}:8080',
                      style: const TextStyle(fontSize: 20),
                    );
                  }
                  return const Text('Can not find the WIFI address');
                }),
            const SizedBox(
              height: 50,
            ),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                child: Text(buttonLabel),
                onPressed: () {
                  if (isListening) {
                    stopServer();
                  } else {
                    startServer();
                  }
                },
              ),
            ),
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future<String> getCurrentIP() async {
    // Getting WIFI IP Details
    String currentIP = '';
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          print(
              'Name: ${interface.name}  IP Address: ${addr.address}  IPV4: ${InternetAddress.anyIPv4}');

          if (addr.type == InternetAddressType.IPv4 &&
              addr.address.startsWith('192')) {
            currentIP = addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    // print('currentIP========: $currentIP');
    return currentIP;
  }

  startServer() async {
    server.serve().then((value) {
      setState(() {
        isListening = true;
        buttonLabel = 'Stop';
      });
    });
  }

  stopServer() async {
    server.stop().then((value) {
      setState(() {
        isListening = false;
        buttonLabel = 'Start';
      });
    });
  }
}
