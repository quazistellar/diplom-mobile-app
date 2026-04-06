import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

/// данный класс отображает экран профиля пользователя
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiClient _apiClient = ApiClient();
  final Uuid _uuid = const Uuid();
  
  bool _isLoading = false;
  Map<String, dynamic> _profileData = {};
  List<dynamic> _paymentHistory = [];
  Map<String, dynamic> _statistics = {};
  pw.Font? _arialRegular;
  pw.Font? _arialBold;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadFonts();
  }

  /// данный метод загружает шрифты для PDF
  Future<void> _loadFonts() async {
    try {
      final fontData = await rootBundle.load("assets/fonts/arial.ttf");
      final boldFontData = await rootBundle.load("assets/fonts/arialbd.ttf");
      
      setState(() {
        _arialRegular = pw.Font.ttf(fontData);
        _arialBold = pw.Font.ttf(boldFontData);
      });
    } catch (e) {
      _arialRegular = pw.Font.helvetica();
      _arialBold = pw.Font.helveticaBold();
    }
  }

  /// данный метод загружает данные профиля
  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await _apiClient.get<Map<String, dynamic>>('/profile/');
      
      if (!mounted) return;
      setState(() {
        _profileData = data['user'] ?? {};
        _paymentHistory = data['payment_history'] ?? [];
        _statistics = data['statistics'] ?? {};
      });
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки профиля: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// данный метод форматирует дату
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd.MM.yyyy HH:mm').format(date.toLocal());
    } catch (e) {
      return dateStr;
    }
  }

  /// данный метод генерирует номер чека
  String _generateReceiptNumber(String paymentId, String courseId, String date) {
    final uuid = _uuid.v4().substring(0, 8).toUpperCase();
    
    try {
      final dateObj = DateTime.parse(date);
      return 'ЧК-${dateObj.year}${dateObj.month.toString().padLeft(2, '0')}${dateObj.day.toString().padLeft(2, '0')}-$uuid';
    } catch (e) {
      return 'ЧК-$uuid';
    }
  }

  /// данный метод генерирует PDF чек
  Future<Uint8List> _generatePdf({
    required String paymentId,
    required String receiptNumber,
    required String courseId,
    required String courseName,
    required String amount,
    required String date,
  }) async {
    final formattedDate = _formatDate(date);
    final userName = _profileData['full_name'] ?? 
                    '${_profileData['last_name'] ?? ''} ${_profileData['first_name'] ?? ''}'.trim();
    final userEmail = _profileData['email'] ?? 'Не указан';
    
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    colors: [
                      PdfColor.fromInt(0xFF7B7FD5),
                      PdfColor.fromInt(0xFF86A8E7),
                      PdfColor.fromInt(0xFF91EAE4),
                    ],
                    begin: pw.Alignment.centerLeft,
                    end: pw.Alignment.centerRight,
                  ),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'UNIREAX',
                      style: pw.TextStyle(
                        font: _arialBold,
                        fontSize: 32,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      'Образовательная платформа',
                      style: pw.TextStyle(
                        font: _arialRegular,
                        fontSize: 14,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Center(
                child: pw.Text(
                  'ЧЕК ОБ ОПЛАТЕ КУРСА',
                  style: pw.TextStyle(
                    font: _arialBold,
                    fontSize: 24,
                    color: PdfColor.fromInt(0xFF151D49),
                  ),
                ),
              ),

              pw.SizedBox(height: 30),

              _buildInfoBlock(
                title: 'Информация о платеже',
                items: [
                  {'label': 'Номер платежа:', 'value': paymentId.isNotEmpty ? paymentId : 'Не указан'},
                  {'label': 'Дата оплаты:', 'value': formattedDate},
                  {'label': 'Статус:', 'value': 'Оплачено'},
                ],
              ),

              pw.SizedBox(height: 20),

              _buildInfoBlock(
                title: 'Информация о курсе',
                items: [
                  {'label': 'Название курса:', 'value': courseName},
                  {'label': 'Сумма (в рублях):', 'value': '$amount'},
                ],
              ),

              pw.SizedBox(height: 20),

              _buildInfoBlock(
                title: 'Информация о пользователе',
                items: [
                  {'label': 'ФИО:', 'value': userName},
                  {'label': 'Email:', 'value': userEmail},
                ],
              ),

              pw.SizedBox(height: 30),

              pw.Row(
                children: [
                  pw.Text(
                    'Итоговая сумма (в рублях):',
                    style: pw.TextStyle(
                      font: _arialBold,
                      fontSize: 18,
                      color: PdfColor.fromInt(0xFF7B7FD5),
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Text(
                    '$amount',
                    style: pw.TextStyle(
                      font: _arialBold,
                      fontSize: 22,
                      color: PdfColor.fromInt(0xFF151D49),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 40),

              pw.Column(
                children: [
                  pw.Divider(color: PdfColor.fromInt(0xFF7B7FD5)),
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Text(
                      'Чек №$receiptNumber',
                      style: pw.TextStyle(
                        font: _arialRegular,
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      'Документ сгенерирован автоматически',
                      style: pw.TextStyle(
                        font: _arialRegular,
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// данный метод создает блок информации для PDF
  pw.Widget _buildInfoBlock({
    required String title,
    required List<Map<String, String>> items,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8F9FF),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: _arialBold,
              fontSize: 16,
              color: PdfColor.fromInt(0xFF5864F1),
            ),
          ),
          pw.SizedBox(height: 10),
          ...items.map((item) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 120,
                  child: pw.Text(
                    item['label']!,
                    style: pw.TextStyle(
                      font: _arialBold,
                      fontSize: 12,
                      color: PdfColors.black,
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    item['value']!,
                    style: pw.TextStyle(
                      font: _arialRegular,
                      fontSize: 12,
                      color: PdfColors.black,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  /// данный метод генерирует и сохраняет чек в PDF
  Future<void> _generateAndSaveReceipt({
    required String paymentId,
    required String receiptNumber,
    required String courseId,
    required String courseName,
    required String amount,
    required String date,
  }) async {
    if (!mounted) return;
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      while (_arialRegular == null || _arialBold == null) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
      }

      final pdfBytes = await _generatePdf(
        paymentId: paymentId,
        receiptNumber: receiptNumber,
        courseId: courseId,
        courseName: courseName,
        amount: amount,
        date: date,
      );
      
      if (mounted) {
        Navigator.pop(context);
      } else {
        return;
      }

      final fileName = 'receipt_${receiptNumber.replaceAll('-', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(pdfBytes);
      
      if (mounted) {
        _showReceiptOptions(tempFile, fileName);
      }

    } catch (e) {
      print('Ошибка создания PDF: $e');
      if (mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {}
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при создании чека: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// данный метод показывает опции для сохраненного чека
  void _showReceiptOptions(File tempFile, String fileName) {
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Чек создан',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                title: const Text('Открыть чек'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  OpenFilex.open(tempFile.path);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.green),
                title: const Text('Поделиться'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  Share.shareXFiles([XFile(tempFile.path)], text: 'Чек об оплате');
                },
              ),
              ListTile(
                leading: const Icon(Icons.save, color: Colors.orange),
                title: const Text('Сохранить в файлы'),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  
                  try {
                    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
                      dialogTitle: 'Выберите папку для сохранения',
                    );

                    if (!mounted) return;

                    if (selectedDirectory != null) {
                      final savePath = '$selectedDirectory/$fileName';
                      final savedFile = File(savePath);
                      await tempFile.copy(savedFile.path);
                      
                      if (await savedFile.exists()) {
                        try {
                          if (await tempFile.exists()) {
                            await tempFile.delete();
                          }
                        } catch (e) {
                          print('Error deleting temp file: $e');
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Файл сохранен: $savePath'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Сохранение отменено'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    print('Error saving file: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ошибка при сохранении: ${e.toString()}'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(bottomSheetContext);
                },
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// данный метод показывает детали чека
  Future<void> _viewReceipt(Map<String, dynamic> payment) async {
    if (!mounted) return;
    
    final paymentId = payment['payment_id']?.toString() ?? ''; 
    final courseId = payment['course_id']?.toString() ?? '';
    final courseName = payment['course_name'] ?? 'Курс';
    final amount = payment['amount']?.toString() ?? '0';
    final date = payment['payment_date'] ?? '';

    final receiptNumber = _generateReceiptNumber(paymentId, courseId, date);
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Чек об оплате',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Text(
                      'Оплата успешна!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      'Курс "$courseName" успешно оплачен.',
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Сумма (в рублях): $amount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Поздравляем! Вы успешно записаны на курс.',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📄 Чек об оплате',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 1.5,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            children: [
                              _buildReceiptItem('Номер платежа', paymentId.isNotEmpty ? paymentId : 'Не указан'),
                              _buildReceiptItem('Дата оплаты', _formatDate(date)),
                              _buildReceiptItem('Слушатель', _profileData['full_name'] ?? 'Не указан'),
                              _buildReceiptItem('Статус', 'Оплачено', color: Colors.green),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          if (paymentId.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'ID платежа в ЮKassa',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          const SizedBox(height: 20),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _generateAndSaveReceipt(
                                  paymentId: paymentId,
                                  receiptNumber: receiptNumber,
                                  courseId: courseId,
                                  courseName: courseName,
                                  amount: amount,
                                  date: date,
                                );
                              },
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('Скачать чек PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                textStyle: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Номер чека: $receiptNumber',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Документ сгенерирован автоматически',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text('Закрыть'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// данный метод создает элемент чека
  Widget _buildReceiptItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('Мой профиль'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Выход'),
                  content: const Text('Вы уверены, что хотите выйти?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Выйти'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                await authProvider.logout();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/auth');
                }
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: theme.primaryColor.withOpacity(0.1),
                                child: Text(
                                  _profileData['first_name']?[0]?.toUpperCase() ?? 
                                  _profileData['username']?[0]?.toUpperCase() ?? '?',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _profileData['full_name'] ?? 'Без имени',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _profileData['role'] ?? 'Слушатель курсов',
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _profileData['email'] ?? 'Email не указан',
                                style: TextStyle(
                                  color: theme.hintColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Статистика',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    'Всего курсов',
                                    '${_statistics['total_enrolled'] ?? 0}',
                                    Icons.school,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    'Оплачено',
                                    '${_statistics['total_paid_courses'] ?? 0}',
                                    Icons.payment,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.primaryColor.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Всего потрачено',
                                    style: TextStyle(
                                      color: theme.hintColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_statistics['total_spent'] ?? '0'} ₽',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.history, color: theme.primaryColor),
                                const SizedBox(width: 8),
                                const Text(
                                  'История оплат',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            if (_paymentHistory.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.payment_outlined,
                                        size: 48,
                                        color: theme.hintColor.withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Нет оплаченных курсов',
                                        style: TextStyle(
                                          color: theme.hintColor,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _paymentHistory.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (context, index) {
                                  final payment = _paymentHistory[index];
                                  final paymentId = payment['payment_id']?.toString() ?? '';
                                  final displayId = paymentId.isNotEmpty && paymentId != 'null'
                                      ? paymentId.substring(0, paymentId.length > 8 ? 8 : paymentId.length)
                                      : _uuid.v4().substring(0, 6).toUpperCase();
                                  
                                  return InkWell(
                                    onTap: () => _viewReceipt(payment),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.receipt_long,
                                              color: Colors.green,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  payment['course_name'] ?? 'Курс',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _formatDate(payment['payment_date']),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.hintColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${payment['amount']} ₽',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.primaryColor,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'ID: $displayId',
                                                  style: const TextStyle(
                                                    fontSize: 8,
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  /// данный метод создает карточку статистики
  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.primaryColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.hintColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}