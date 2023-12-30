/*
 Copyright (c) 2023, Winson  https://www.coderblog.in
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * The name of Pierre-Olivier Latour may not be used to endorse
 or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL PIERRE-OLIVIER LATOUR BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:internal_http_server/assets_cache.dart';
import 'package:internal_http_server/file_model.dart';
import 'package:internal_http_server/logger.dart';
import 'package:path/path.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class InternalHttpServer {
  /// Server address
  final InternetAddress address;

  /// Optional server port (note: might be already taken)
  /// Defaults to 0 (binds server to a random free port)
  final int port;

  /// Assets base path
  final String assetsBasePath = 'packages/internal_http_server/lib/webserver/';

  final String title;

  final String _indexFile;
  String? _description;
  final String _website;
  final String _copyright;

  List<MimeMultipart> parts = [];

  final Directory? _rootDir;
  HttpServer? _server;

  final Logger logger;

  late IOSink uploadFile;
  bool isFirstPart = true;

  InternalHttpServer({
    // server ip address, default is : InternetAddress.anyIPv4
    required this.address,
    // the webserver title
    required this.title,
    // the default index file of the website
    String? indexFile,
    // the website link in footer
    String? website,
    // the copyright in footer
    String? copyright,
    // Pass this argument if you want your assets to be served from app directory, not from app bundle
    Directory? rootDir,
    // TCP port server will be listening on. Will choose an available port automatically if no port was passed
    this.port = 0,
    this.logger = const SilentLogger(),
  })  : _rootDir = rootDir,
        _website = website ?? 'https://www.coderblog.in',
        _indexFile = indexFile ?? 'index.html',
        _copyright = copyright ?? '2023 CoderBlog';

  /// Actual port server is listening on
  int? get boundPort => _server?.port;

  setDescription(String desc) {
    _description = desc;
  }

  /// Starts server
  Future<InternetAddress> serve({bool shared = false}) async {
    final s = await HttpServer.bind(address, port, shared: shared);
    // debugPrint('Server listening on ${s.address}:${s.port}');
    s.listen(_handleReq);

    _server = s;

    return s.address;
  }

  Future<void> stop() async {
    AssetsCache.clear();
    await _server?.close();
  }

  _handleReq(HttpRequest request) async {
    String path = request.requestedUri.path.replaceFirst('/', '');

    if (path == '') {
      //path = 'index.html';
      path = _indexFile;
    }
    // print('path: $path');

    final name = basename(path);
    final mime = lookupMimeType(name);

    try {
      debugPrint(
          'method: ${request.method}  path: ${request.requestedUri.path} pa: ${request.uri.queryParameters} head: ${request.headers.contentType.toString()}');

      if (request.method == 'POST' && request.uri.path == '/startUpload') {
        _startUpload(request);
      } else if (request.method == 'POST' && request.uri.path == '/uploading') {
        _handleFileUploading(request);
      } else if (request.method == 'POST' &&
          request.uri.path == '/uploadDone') {
        _uploadDone(request);
      } else if (request.uri.path == '/finishUploaded') {
        return _fileUploaded(request);
      } else if (request.uri.path == '/list') {
        return _getFileList(request);
      } else if (request.uri.path == '/delete') {
        return _deleteFile(request);
      } else if (request.uri.path == '/create') {
        return _createFolder(request);
      } else if (request.uri.path == '/move') {
        return _moveFile(request);
      } else if (request.uri.path == '/download') {
        _downloadFile(request);
      } else {
        final data = await _loadAsset(path);

        request.response.headers.add('Content-Type', '$mime; charset=utf-8');
        request.response.add(data.buffer.asUint8List());

        request.response.close();
      }
      // logger.logOk(path, mime.toString());
    } catch (err) {
      request.response.statusCode = 404;
      request.response.close();
      // debugPrint(err);
      // debugPrint(
      //     'error == method: ${request.method}  path: ${request.requestedUri}');
      logger.logNotFound(path, mime.toString());
    }
  }

  Future<ByteData> _loadAsset(String path) async {
    if (AssetsCache.assets.containsKey(path)) {
      return AssetsCache.assets[path]!;
    }

    if (_rootDir == null) {
      // print('path=============');
      // print(join(assetsBasePath, path));
      ByteData data = await rootBundle.load(join(assetsBasePath, path));
      return data;
    }

    if (await Directory(_rootDir.path).exists()) {}

    debugPrint(join(_rootDir.path, path));
    final f = File(join(_rootDir.path, path));
    return (await f.readAsBytes()).buffer.asByteData();
  }

  _startUpload(HttpRequest request) async {
    debugPrint('start upload file==============');
    //init the file object
    Map<String, dynamic> jsonData = await _getParameters(request);
    String fileName = jsonData['name'];

    var savePath = jsonData['path'];
    final appDocDir = await getApplicationDocumentsDirectory();
    String subdirectoryPath = appDocDir.path;
    if (savePath != '') {
      subdirectoryPath += '/$savePath';
    }

    uploadFile = File(p.join(subdirectoryPath, fileName)).openWrite();
  }

  _handleFileUploading(HttpRequest request) async {
    debugPrint('uploading file==============');
    if (request.headers.contentType?.mimeType == 'multipart/form-data') {
      var transformer = MimeMultipartTransformer(
          request.headers.contentType!.parameters['boundary']!);

      var bodyStream = transformer.bind(request);

      await for (var part in bodyStream) {
        //parts.add(part);
        if (isFirstPart) {
          isFirstPart = false;
        } else {
          part.headers.remove('content-disposition');
        }

        var fileByte =
            await part.fold<List<int>>(<int>[], (b, d) => b..addAll(d));

        if (fileByte.length > 1) {
          //print(' Part Byte Length: ${fileByte.length}');

          uploadFile.add(fileByte);
          await Future.delayed(Duration.zero);
        }
      }

      final response = {
        'message': 'File uploadeding',
      };

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(json.encode(response))
        ..close();
    }
  }

  _uploadDone(HttpRequest request) async {
    // debugPrint('uploaded one file done==============');

    isFirstPart = true;

    final response = {
      'message': 'File uploaded done',
    };
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(json.encode(response))
      ..close();
  }

  _fileUploaded(HttpRequest request) async {
    // debugPrint('finished uploading all files==============');

    await uploadFile.flush();
    await uploadFile.close();

    final response = {
      'message': 'File uploaded successfully',
    };
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(json.encode(response))
      ..close();
  }

  _getFileList(HttpRequest request) async {
    // var path = request.headers.contentType!.parameters['path']!;
    // debugPrint('path line 336: $path');

    Map<String, dynamic> jsonData = await _getParameters(request);
    String directoryName = jsonData['path'];
    // print('directoryName:$directoryName');

    Directory appDocDir = await getApplicationDocumentsDirectory();
    // if (uploadRootDir == null) {
    //   uploadRootDir = appDocDir.path;
    // } else {
    //   uploadRootDir = appDocDir.path + uploadRootDir!;
    //   print('upload folder 2==============: $uploadRootDir');
    //   var directory = Directory(uploadRootDir!);
    //   if (!await directory.exists()) {
    //     //create the folder
    //     directory
    //         .create(recursive: true)
    //         .then((Directory newDirectory) {})
    //         .catchError((e) {});
    //   }
    // }
    String subdirectoryPath = appDocDir.path + directoryName;
    debugPrint('subdirectoryPath: $subdirectoryPath');
    Directory documentsDirectory = Directory(subdirectoryPath);

    List<Map<String, dynamic>> filelist = [];

    if (documentsDirectory.existsSync()) {
      List<Directory> directories =
          documentsDirectory.listSync().whereType<Directory>().toList();
      for (var dir in directories) {
        var folder = basename(dir.path);
        if (folder != 'opencc') {
          var item = FileModel(
              fileName: basename(dir.path),
              path: '/${dir.path.replaceAll('${appDocDir.path}/', '')}');
          filelist.add(item.toJson());
        }
      }

      List<File> files =
          documentsDirectory.listSync().whereType<File>().toList();
      for (var file in files) {
        var fileName = basename(file.path);
        // print('filename: $fileName');
        var item = FileModel(
            fileName: fileName,
            path: '/${file.path.replaceAll('${appDocDir.path}/', '')}',
            fileSize: file.lengthSync().toDouble());
        filelist.add(item.toJson());
      }
    }

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String deviceName = 'Your Phone'; // the default value

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      deviceName = androidInfo.model;
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      deviceName = iosInfo.name;
    }

    final response = {
      'device': deviceName,
      'files': filelist,
      'title': title,
      'description': _description,
      'website': _website,
      'copyright': _copyright
    };

    //print(response);

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(json.encode(response))
      ..close();
  }

  _deleteFile(HttpRequest request) async {
    debugPrint('delete====');

    Map<String, dynamic> jsonData = await _getParameters(request);
    String deleteFile = jsonData['filename'];

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String filePath = '${appDocDir.path}/$deleteFile';

    String result = '';
    var statusCode = HttpStatus.ok;

    if (FileSystemEntity.isFileSync(filePath)) {
      try {
        File file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          result = 'File $deleteFile has been deleted';
        } else {
          result = 'Can not found the file';
          statusCode = HttpStatus.expectationFailed;
        }
      } catch (e) {
        result = 'Errors for deleting : $e';
        statusCode = HttpStatus.expectationFailed;
      }
    } else if (FileSystemEntity.isDirectorySync(filePath)) {
      result = _deleteDirectoryAndContents(filePath);
      if (result != 'OK') {
        statusCode = HttpStatus.expectationFailed;
      }
    }

    final message = {'message': result};

    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(json.encode(message))
      ..close();
  }

  _createFolder(HttpRequest request) async {
    Map<String, dynamic> jsonData = await _getParameters(request);
    String directoryName = jsonData['path'];
    if (!directoryName.endsWith('/')) {
      directoryName += '/';
    }
    debugPrint(directoryName);

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String directoryPath = '/${appDocDir.path}/$directoryName';
    Directory directory = Directory(directoryPath);

    final response = {
      'message': '',
    };
    var statusCode = HttpStatus.ok;

    if (await directory.exists()) {
      response['message'] = 'folder $directoryName is existed';
      statusCode = HttpStatus.expectationFailed;
    } else {
      directory.create(recursive: true).then((Directory newDirectory) {
        response['message'] = 'folder $directoryName has been created';
      }).catchError((e) {
        response['message'] = 'Error for creating folder：$e';
        statusCode = HttpStatus.expectationFailed;
      });
    }

    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(json.encode(response))
      ..close();
  }

  _downloadFile(HttpRequest request) async {
    debugPrint('download====');

    String downloadFile = request.uri.queryParameters['path']!;

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String filePath = '${appDocDir.path}/$downloadFile';

    File file = File(filePath);
    if (await file.exists()) {
      final response = request.response
        ..headers.add('Content-Type', 'application/octet-stream')
        ..headers.add('Content-Disposition',
            'attachment; filename=${Uri.encodeComponent(file.path.split('/').last)}');

      await response.addStream(file.openRead());

      await response.close();
    }
  }

  _moveFile(HttpRequest request) async {
    debugPrint('move====');

    Map<String, dynamic> jsonData = await _getParameters(request);
    String oldPath = jsonData['oldPath'];
    String newPath = jsonData['newPath'];

    debugPrint('old path:$oldPath new path:$newPath');

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String oldFilePath = '${appDocDir.path}/$oldPath';
    String newFilePath = '${appDocDir.path}/$newPath';

    String result = '';
    var statusCode = HttpStatus.ok;

    try {
      if (FileSystemEntity.isFileSync(oldFilePath)) {
        File oldfile = File(oldFilePath);
        if (await oldfile.exists()) {
          await oldfile.rename(newFilePath);
          result = 'File $oldPath has been edited';
        } else {
          result = 'Can not found the file';
          statusCode = HttpStatus.expectationFailed;
        }
      } else {
        //rename folder
        var dir = Directory(oldFilePath);
        if (await dir.exists()) {
          await dir.rename(newFilePath);
          result = 'Folder $oldPath has been edited';
        } else {
          result = 'Can not found the folder';
          statusCode = HttpStatus.expectationFailed;
        }
      }
    } catch (e) {
      result = 'Error for editing：$e';
      statusCode = HttpStatus.expectationFailed;
    }

    final message = {'message': result};

    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(json.encode(message))
      ..close();
  }

  Future<Map<String, dynamic>> _getParameters(HttpRequest request) async {
    Uint8List data = await request.fold(Uint8List(0),
        (previous, element) => Uint8List.fromList([...previous, ...element]));

    Map<String, String> queryParams = Uri.splitQueryString(utf8.decode(data));
    return Map.from(queryParams);
  }

  String _deleteDirectoryAndContents(String directoryPath) {
    Directory directory = Directory(directoryPath);

    if (directory.existsSync()) {
      directory.listSync(recursive: true).forEach((FileSystemEntity entity) {
        if (entity is File) {
          entity.deleteSync();
        } else if (entity is Directory) {
          entity.deleteSync(recursive: true);
        }
      });

      directory.deleteSync(recursive: true);
      return 'OK';
    } else {
      return 'Folder $directoryPath does not exist';
    }
  }
}
