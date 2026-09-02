import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'api_client.dart';
import 'config.dart';

class UploadedFile {
  final String url;
  final int bytes;
  UploadedFile({required this.url, required this.bytes});
}

/// Compresses a photo toward ~200KB on-device (low-bandwidth requirement),
/// then uploads it directly to object storage via a short-lived presigned
/// URL — bytes never pass through the API server, so many photos can
/// upload in parallel without loading it.
class UploadService {
  static Future<UploadedFile> uploadPhoto(String filePath) async {
    final compressed = await _compressToTarget(filePath);
    final presign = await ApiClient.instance.dio.post('/storage/presign', data: {
      'kind': 'photo',
      'contentType': 'image/jpeg',
    });
    final uploadUrl = presign.data['uploadUrl'] as String;
    final publicUrl = presign.data['publicUrl'] as String;

    await Dio().put(
      uploadUrl,
      data: Stream.fromIterable([compressed]),
      options: Options(
        headers: {
          Headers.contentLengthHeader: compressed.length,
          Headers.contentTypeHeader: 'image/jpeg',
        },
      ),
    );

    return UploadedFile(url: publicUrl, bytes: compressed.length);
  }

  static Future<UploadedFile> uploadAudio(String filePath, {required String contentType}) async {
    final data = await _readFile(filePath);
    final presign = await ApiClient.instance.dio.post('/storage/presign', data: {
      'kind': 'audio',
      'contentType': contentType,
    });
    final uploadUrl = presign.data['uploadUrl'] as String;
    final publicUrl = presign.data['publicUrl'] as String;

    await Dio().put(
      uploadUrl,
      data: Stream.fromIterable([data]),
      options: Options(
        headers: {
          Headers.contentLengthHeader: data.length,
          Headers.contentTypeHeader: contentType,
        },
      ),
    );

    return UploadedFile(url: publicUrl, bytes: data.length);
  }

  static Future<Uint8List> _compressToTarget(String filePath) async {
    var quality = 85;
    Uint8List? result;
    while (quality >= 30) {
      result = await FlutterImageCompress.compressWithFile(
        filePath,
        quality: quality,
        minWidth: 1280,
        minHeight: 960,
      );
      if (result == null) break;
      if (result.lengthInBytes <= AppConfig.photoTargetBytes) break;
      quality -= 15;
    }
    return result ?? await _readFile(filePath);
  }

  static Future<Uint8List> _readFile(String path) => File(path).readAsBytes();
}
