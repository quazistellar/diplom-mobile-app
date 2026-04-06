import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../services/api_client.dart';

/// данный класс предоставляет сервис для обработки платежей через ЮKassa
class PaymentService {
  static final ApiClient _apiClient = ApiClient();

  /// данная функция открывает окно оплаты (WebView или браузер в зависимости от платформы)
  static Future<void> openYookassaPayment({
    required BuildContext context,
    required String paymentUrl,
    required String paymentId,
    required int courseId,
    required String courseName,
    required double amount,
    required Function(bool success, String? message, String? paymentId) onComplete,
  }) async {
    
    if (Platform.isWindows) {
      await _openInBrowser(context, paymentUrl, paymentId, courseId, onComplete);
    } else {
      await _openWebViewPayment(
        context, 
        paymentUrl, 
        paymentId, 
        courseId, 
        courseName, 
        amount, 
        onComplete
      );
    }
  }

  /// данная функция открывает платежную страницу в браузере (для Windows)
  static Future<void> _openInBrowser(
    BuildContext context,
    String paymentUrl,
    String paymentId,
    int courseId,
    Function(bool success, String? message, String? paymentId) onComplete,
  ) async {
    try {
      final uri = Uri.parse(paymentUrl);
      
      if (await canLaunchUrl(uri)) {
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('Оплата курса'),
                content: const Text(
                  'Сейчас откроется браузер для оплаты.\n'
                  'После завершения оплаты вернитесь в приложение.\n\n'
                  'Проверка статуса платежа будет выполнена автоматически.'
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      onComplete(false, 'Оплата отменена', paymentId);
                    },
                    child: const Text('Отмена'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (context.mounted) {
                        _showWaitingDialog(context, paymentId, courseId, onComplete);
                      }
                    },
                    child: const Text('Перейти к оплате'),
                  ),
                ],
              );
            },
          );
        }
      } else {
        throw Exception('Не удалось открыть браузер');
      }
    } catch (e) {
      onComplete(false, 'Ошибка открытия браузера: $e', paymentId);
    }
  }

  /// данная функция показывает диалог ожидания после оплаты в браузере
  static Future<void> _showWaitingDialog(
    BuildContext context,
    String paymentId,
    int courseId,
    Function(bool success, String? message, String? paymentId) onComplete,
  ) async {
    bool completed = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Ожидание оплаты'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Проверяем статус платежа...\n'
                'Это может занять несколько секунд.'
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  completed = true;
                  Navigator.of(dialogContext).pop();
                  onComplete(false, 'Проверка отменена', paymentId);
                },
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
      },
    );
    
    for (int i = 0; i < 15; i++) {
      if (completed) break;
      
      await Future.delayed(const Duration(seconds: 2));
      
      try {        
        final statusResponse = await _apiClient.get<Map<String, dynamic>>(
          '/payments/status/$paymentId/',
        );
        
        print('🔍 Status response: $statusResponse');
        
        if (statusResponse['success'] == true && statusResponse['status'] == 'succeeded') {
          final confirmResponse = await _apiClient.post<Map<String, dynamic>>(
            '/payments/confirm/$paymentId/',
          );
          
          print('🔍 Confirm response: $confirmResponse');
          
          if (confirmResponse['success'] == true) {
            completed = true;
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop(); 
            }
            onComplete(true, 'Оплата успешно завершена', paymentId);
            return;
          }
        }
      } catch (e) {
        print('🔍 Status check error: $e');
      }
    }
    
    if (!completed && Navigator.canPop(context)) {
      Navigator.of(context).pop(); 
    }
    onComplete(false, 'Время ожидания истекло. Проверьте статус платежа на странице или в профиле.', paymentId);
  }

  /// данная функция открывает платежную страницу в WebView (для мобильных платформ)
  static Future<void> _openWebViewPayment(
    BuildContext context,
    String paymentUrl,
    String paymentId,
    int courseId,
    String courseName,
    double amount,
    Function(bool success, String? message, String? paymentId) onComplete,
  ) async {
    
    bool paymentProcessed = false;
    
    late final PlatformWebViewControllerCreationParams params;
    
    if (Platform.isAndroid) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = WebKitWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            print('WebView progress: $progress%');
          },
          onPageStarted: (String url) {
            print('Page started: $url');
          },
          onPageFinished: (String url) {
            print('Page finished: $url');
            
            if (!paymentProcessed && (url.contains('success') || url.contains('payment-success'))) {
              paymentProcessed = true;
              
              Future.delayed(const Duration(seconds: 2), () async {
                await _checkPaymentStatus(context, paymentId, courseId, onComplete);
                
                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }
              });
            }
          },
          onWebResourceError: (error) {
            print('WebView error: $error');
          },
          onNavigationRequest: (request) {
            print('Navigation request: ${request.url}');
            
            if (!paymentProcessed && (request.url.contains('success') || request.url.contains('payment-success'))) {
              paymentProcessed = true;
              
              Future.delayed(const Duration(seconds: 1), () async {
                await _checkPaymentStatus(context, paymentId, courseId, onComplete);
                
                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }
              });
            }
            
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(paymentUrl));
    
    if (controller.platform is AndroidWebViewController) {
      (controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }
    
    if (controller.platform is WebKitWebViewController) {
      (controller.platform as WebKitWebViewController).setAllowsBackForwardNavigationGestures(true);
    }

    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text('Оплата курса "$courseName"'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  if (!paymentProcessed) {
                    Navigator.of(dialogContext).pop();
                    onComplete(false, 'Оплата отменена', paymentId);
                  } else {
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
            ),
            body: SafeArea(
              child: WebViewWidget(controller: controller),
            ),
          ),
        );
      },
    );
  }

  /// данная функция проверяет статус платежа и подтверждает его
  static Future<void> _checkPaymentStatus(
    BuildContext context,
    String paymentId,
    int courseId,
    Function(bool success, String? message, String? paymentId) onComplete,
  ) async {
    try {
      for (int i = 0; i < 5; i++) {
        try {
          final statusResponse = await _apiClient.get<Map<String, dynamic>>(
            '/payments/status/$paymentId/',
          );

          if (statusResponse['success'] == true && statusResponse['status'] == 'succeeded') {
            final confirmResponse = await _apiClient.post<Map<String, dynamic>>(
              '/payments/confirm/$paymentId/',
            );
                        
            if (confirmResponse['success'] == true) {
              onComplete(true, 'Оплата успешно завершена', paymentId);
              return;
            }
          }
        } catch (e) {
          onComplete(false, 'Ошибка проверки статуса оплаты', paymentId);
          log('Проверка статуса оплаты: $e');
        }
        
        await Future.delayed(const Duration(seconds: 1));
      }
      
      onComplete(false, 'Платеж не подтвержден', paymentId);
      
    } catch (e) {
      log('Ошибка проверки статуса платежа: $e');
      onComplete(false, 'Ошибка проверки статуса платежа', paymentId);
    }
  }
}