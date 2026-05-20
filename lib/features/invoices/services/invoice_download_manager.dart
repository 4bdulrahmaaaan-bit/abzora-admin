import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

class InvoiceDownloadManager {
  InvoiceDownloadManager(this._dio);

  final Dio _dio;

  Future<File> downloadToAppStorage({required String id, required String url}) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/invoice_$id.pdf';
    await _dio.download(
      url,
      path,
      options: Options(
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 45),
      ),
    );
    return File(path);
  }

  Future<File?> getCachedCopy(String url) async {
    final file = await DefaultCacheManager().getFileFromCache(url);
    return file?.file;
  }

  Future<File?> getLocalCopyById(String id) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/invoice_$id.pdf');
    if (await file.exists()) return file;
    return null;
  }
}
