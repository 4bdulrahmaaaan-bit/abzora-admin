import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class DocumentOcrService {
  const DocumentOcrService();

  Future<Map<String, dynamic>> scanImage({
    required XFile file,
    String documentType = '',
  }) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final recognizedText = await recognizer.processImage(inputImage);
      return _buildResult(
        documentType: documentType,
        rawText: recognizedText.text,
      );
    } finally {
      await recognizer.close();
    }
  }

  Map<String, dynamic> _buildResult({
    required String documentType,
    required String rawText,
  }) {
    final normalizedRawText = rawText.trim();
    final compact = normalizedRawText.replaceAll(RegExp(r'\s+'), ' ');
    final aadhaar = RegExp(r'\b\d{12}\b')
            .firstMatch(compact.replaceAll(RegExp(r'\s+'), ''))
            ?.group(0) ??
        '';
    final pan = RegExp(r'\b[A-Z]{5}[0-9]{4}[A-Z]\b').firstMatch(compact.toUpperCase())?.group(0) ?? '';
    final license = RegExp(r'\b[A-Z]{2}\d{2}[A-Z]{2}\d{4}\b').firstMatch(compact.toUpperCase())?.group(0) ?? '';
    final hasText = normalizedRawText.isNotEmpty;
    final matches = <String, dynamic>{
      if (aadhaar.isNotEmpty) 'aadhaarNumber': aadhaar,
      if (pan.isNotEmpty) 'panNumber': pan,
      if (license.isNotEmpty) 'licenseNumber': license,
      'rawText': normalizedRawText,
      'recognizedText': normalizedRawText,
      'documentType': documentType,
      'documentTypeNormalized': documentType.trim().toLowerCase(),
      'confidenceScore': hasText
          ? (aadhaar.isNotEmpty || pan.isNotEmpty || license.isNotEmpty ? 88 : 72)
          : 0,
      'requiresManualReview': !hasText,
      'flags': hasText ? <String>[] : <String>['unable_to_read_document'],
    };
    if (aadhaar.isNotEmpty) {
      matches['aadhaarValid'] = true;
    }
    if (pan.isNotEmpty) {
      matches['panValid'] = true;
    }
    if (license.isNotEmpty) {
      matches['licenseValid'] = true;
    }
    return matches;
  }
}
