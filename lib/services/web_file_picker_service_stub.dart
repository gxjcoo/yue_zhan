import 'package:file_picker/file_picker.dart';

/// 非Web环境的存根实现
class WebFilePickerService {
  static Future<List<dynamic>> pickAudioFiles() async {
    throw UnsupportedError('此方法仅支持Web环境');
  }
  
  static Future<FilePickerResult?> pickFilesWithFilePicker() async {
    throw UnsupportedError('此方法仅支持Web环境');
  }
  
  static dynamic htmlFileToPlatformFile(dynamic htmlFile) {
    throw UnsupportedError('此方法仅支持Web环境');
  }
  
  static Map<String, dynamic> getFileInfo(dynamic file) {
    throw UnsupportedError('此方法仅支持Web环境');
  }
}
