import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../utils/navigation_helper.dart';

/// класс создает базовый экран с навигацией
abstract class BaseNavigationScreen extends StatefulWidget {
  const BaseNavigationScreen({super.key});
}

/// данная функция предоставляет состояние для базового экрана навигации
abstract class BaseNavigationScreenState<T extends BaseNavigationScreen> 
    extends State<T> with NavigationHelper {
  
  /// данная функция создает содержимое экрана
  Widget buildContent(BuildContext context);
  
  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navProvider, child) {
        return Scaffold(
          body: buildContent(context),
          bottomNavigationBar: BottomNavBar(
            currentIndex: navProvider.currentIndex,
            onTap: (index) => handleNavigationTap(index, context),
          ),
        );
      },
    );
  }
}