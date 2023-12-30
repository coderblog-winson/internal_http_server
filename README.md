# Introduction

This is a package to help you create an internal HTTP server in your app, you can let user upload the files within this web server.

# Feature

1. The nice HTML layout :)
2. Support drag and drop the file to upload
3. Support upload multiple files
4. Can CRUD and move a file and folder
5. Support upload larger file (over 1GB)
6. You can put the description with HTML in web server
7. Support iOS and Android

# Limition

Not support to create nesting sub folders. 

# The demo screen capture

![Web Server](https://github.com/coderblog-winson/internal_http_server/blob/main/screen_capture/webserver_screen.png)

<a href="#screenshots">
  <img src="https://github.com/coderblog-winson/internal_http_server/blob/main/screen_capture/phone_screen.png" width="300px">
</a>&nbsp;&nbsp;

# How to use 

## 1. Init the InternalHttpServer

```dart
 InternalHttpServer server = InternalHttpServer(
    title: 'Testing Web Server',
    address: InternetAddress.anyIPv4,
    port: 8080,
    logger: const DebugLogger(),
  );
```
## 2. Update your description with any HTML codes

define the description string

```dart
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
```

update to web server

```dart
server.setDescription(server_description);
```

## 3. Create two method to start and stop the server

```dart
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
```

create a button to start and stop server

```dart
ElevatedButton(
  child: Text(buttonLabel),
  onPressed: () {
    if (isListening) {
      stopServer();
    } else {
      startServer();
    }
  },
),
```

also, you need to let user know what the IP address of your web server, so you should get the device IP as below and show the IP in your APP 

```dart
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
```

Please find the full example here [here (../example/lib/main.dart)][here].


# In the end

Due to my limited time and energy, I warmly welcome everyone to work together to improve this project. For example, nested directories are not yet supported. :)

By the way, also welcome to my blog to let me know what do your thoughts : https://www.coderblog.in

