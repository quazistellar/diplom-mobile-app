import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';

mixin NavigationHelper<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
  }

  void handleNavigationTap(int index, BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    
    if (navProvider.currentIndex == index) return;
    
    navProvider.currentIndex = index;
    
    String? route;
    switch (index) {
      case 0:
        route = '/main';
        break;
      case 1:
        route = '/courses';
        break;
      case 2:
        route = '/progress';
        break;
      case 3:
        route = '/results';
        break;
      case 4:
        route = '/settings';
        break;
    }
    
    if (route != null) {
      final currentRoute = ModalRoute.of(context)?.settings.name;
      if (currentRoute == route) return;
      
      Navigator.pushNamedAndRemoveUntil(
        context, 
        route, 
        (route) => false, 
      );
    }
  }
}