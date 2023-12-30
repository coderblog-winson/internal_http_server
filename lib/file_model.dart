// ignore_for_file: public_member_api_docs, sort_constructors_first
class FileModel {
  String fileName;
  String path;
  double? fileSize;
  FileModel({
    required this.fileName,
    required this.path,
    this.fileSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'path': path,
      'fileSize': fileSize,
    };
  }
}
