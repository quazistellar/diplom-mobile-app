import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../utils/navigation_helper.dart';

abstract class BaseNavigationScreen extends StatefulWidget {
  const BaseNavigationScreen({super.key});
}

abstract class BaseNavigationScreenState<T extends BaseNavigationScreen> 
    extends State<T> with NavigationHelper {
  
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