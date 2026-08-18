import 'package:file_picker/file_picker.dart';

import '../core/config/app_config.dart';

/// Raised when a hand-picked menu workbook could not be read.
class FileImportException implements Exception {
  /// Creates an exception describing why the import failed.
  const FileImportException(this.message, {this.cause});

  /// Technical description, for logs only.
  final String message;

  /// The underlying error, if any.
  final Object? cause;

  @override
  String toString() => 'FileImportException($message)';
}

/// A workbook chosen by the student.
class PickedWorkbook {
  /// Creates a picked workbook.
  const PickedWorkbook({required this.name, required this.bytes});

  /// File name as shown in the picker, used in confirmation copy.
  final String name;

  /// Raw file contents, handed to the parser.
  final List<int> bytes;
}

/// Lets the student pick a mess-menu spreadsheet from the device.
///
/// This is the only place the app touches the file system.
class FileImportService {
  /// Creates the service.
  const FileImportService();

  /// Opens the system picker, restricted to Excel workbooks.
  ///
  /// Returns `null` when the student cancels. Throws [FileImportException] if
  /// a file was chosen but could not be read.
  Future<PickedWorkbook?> pickMenuWorkbook() async {
    PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        dialogTitle: 'Select the mess menu spreadsheet',
        type: FileType.custom,
        allowedExtensions: AppConfig.importExtensions,
      );
    } on Object catch (error) {
      throw FileImportException('File picker failed', cause: error);
    }

    if (picked == null) return null;

    // Some pickers ignore the extension filter, so the choice is re-checked
    // here rather than letting the parser fail with a confusing message.
    final name = picked.name;
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    if (!AppConfig.importExtensions.contains(extension)) {
      throw const FileImportException('Not a spreadsheet');
    }

    try {
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw const FileImportException('Selected file is empty');
      }
      return PickedWorkbook(name: name, bytes: bytes);
    } on FileImportException {
      rethrow;
    } on Object catch (error) {
      throw FileImportException(
        'Could not read the selected file',
        cause: error,
      );
    }
  }
}
