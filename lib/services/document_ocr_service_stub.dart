import 'package:image_picker/image_picker.dart';

class DocumentOcrService {
  const DocumentOcrService();

  Future<Map<String, dynamic>> scanImage({
    required XFile file,
    String documentType = '',
  }) async {
    return <String, dynamic>{
      'documentType': documentType,
      'documentTypeNormalized': documentType.trim().toLowerCase(),
      'rawText': '',
      'recognizedText': '',
      'confidenceScore': 0,
      'requiresManualReview': true,
      'flags': <String>['ocr_not_available'],
    };
  }
}
