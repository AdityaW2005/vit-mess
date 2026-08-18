import 'dart:async';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';

/// Raised when the remote menu document could not be retrieved.
///
/// Callers in the repository layer translate this into a `Result.failure`; it
/// never escapes to a ViewModel.
class MenuApiException implements Exception {
  /// Creates an exception describing why the fetch failed.
  const MenuApiException(this.message, {this.statusCode, this.cause});

  /// Technical description, for logs only.
  final String message;

  /// HTTP status, when the request completed with a non-2xx response.
  final int? statusCode;

  /// The underlying error, if any.
  final Object? cause;

  @override
  String toString() =>
      'MenuApiException($message${statusCode == null ? '' : ', $statusCode'})';
}

/// Fetches the menu document over HTTP.
///
/// This is the only place in the app that performs a network call.
class MenuApiService {
  /// Creates the service. Pass a [client] in tests to avoid real sockets.
  MenuApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Downloads the raw menu document.
  ///
  /// Returns the response body as a string. Throws [MenuApiException] on
  /// timeout, transport failure, non-2xx status, or an empty body.
  Future<String> fetchMenuDocument({String url = AppConfig.menuUrl}) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw MenuApiException('Menu URL is not a valid absolute URI: $url');
    }

    http.Response response;
    try {
      response = await _client
          .get(uri, headers: const <String, String>{'Accept': 'application/json'})
          .timeout(AppConfig.networkTimeout);
    } on TimeoutException catch (error) {
      throw MenuApiException('Request timed out', cause: error);
    } on http.ClientException catch (error) {
      throw MenuApiException('Transport failure', cause: error);
    } on Object catch (error) {
      // Socket errors and platform failures surface as untyped errors on some
      // platforms; the repository only needs to know the fetch did not work.
      throw MenuApiException('Network unavailable', cause: error);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MenuApiException(
        'Unexpected status',
        statusCode: response.statusCode,
      );
    }

    final body = response.body;
    if (body.trim().isEmpty) {
      throw MenuApiException('Empty response body', statusCode: response.statusCode);
    }
    return body;
  }

  /// Releases the underlying HTTP client.
  void dispose() => _client.close();
}
