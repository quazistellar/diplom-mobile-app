import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import '../services/api_client.dart';

class CertificateProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _certificates = [];
  Map<String, dynamic>? _eligibilityData;
  
  final ApiClient _apiClient = ApiClient();
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<dynamic> get certificates => _certificates;
  Map<String, dynamic>? get eligibilityData => _eligibilityData;

  /// данная функция логирует сообщения
  void _log(String message) {
    if (kDebugMode) print('[CertificateProvider] $message');
  }

  /// данная функция загружает список сертификатов пользователя
  Future<void> loadCertificates() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final isAuth = await _apiClient.isAuthenticated();
      if (!isAuth) throw Exception('Требуется авторизация');

      final response = await _apiClient.getCertificates();
      _certificates = List<dynamic>.from(response['certificates'] ?? []);
      _log('Загружено ${_certificates.length} сертификатов');
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _log(_errorMessage!);
    } catch (e) {
      _errorMessage = 'Ошибка загрузки: $e';
      _log(_errorMessage!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// данная функция проверяет возможность получения сертификата
  Future<Map<String, dynamic>> checkEligibility(int courseId) async {
    try {
      final isAuth = await _apiClient.isAuthenticated();
      if (!isAuth) throw Exception('Требуется авторизация');

      _eligibilityData = await _apiClient.checkCertificateEligibility(courseId);
      return _eligibilityData!;
    } on ApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Ошибка проверки: $e');
    }
  }

  /// данная функция выпускает сертификат
  Future<Map<String, dynamic>> issueCertificate(int courseId) async {
    try {
      final isAuth = await _apiClient.isAuthenticated();
      if (!isAuth) throw Exception('Требуется авторизация');

      final response = await _apiClient.issueCertificate(courseId);
      await loadCertificates();
      return response;
    } on ApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Ошибка получения сертификата: $e');
    }
  }

  /// данная функция скачивает сертификат
  Future<String> downloadCertificate(int certificateId) async {
    try {
      final isAuth = await _apiClient.isAuthenticated();
      if (!isAuth) throw Exception('Требуется авторизация');

      final bytes = await _apiClient.downloadCertificate(certificateId);
      final fileName = 'certificate_$certificateId.pdf';
      final filePath = await _apiClient.saveFile(bytes, fileName);
      return filePath;
    } on ApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Ошибка скачивания: $e');
    }
  }

  /// данная функция открывает файл сертификата
  Future<void> openCertificate(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      throw Exception('Не удалось открыть файл');
    }
  }

  /// данная функция очищает данные сертификатов
  void clearData() {
    _certificates = [];
    _eligibilityData = null;
    notifyListeners();
  }
}