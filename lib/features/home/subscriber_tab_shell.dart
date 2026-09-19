import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/components/navigation/app_bottom_nav.dart';
import '../../design_system/theme/app_colors.dart';

/// Shell das 5 abas do assinante. A barra fica visível em Início,
/// Vocabulário, Biblioteca, Ditado e Perfil — cada um é um branch, não
/// uma rota empurrada por cima do Início.
class SubscriberTabShell extends StatelessWidget {
  const SubscriberTabShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMuted,
      extendBody: false,
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: const [
          AppNavItem(
            icon: LucideIcons.house,
            activeIcon: LucideIcons.house,
            label: 'Início',
          ),
          AppNavItem(
            icon: LucideIcons.book,
            activeIcon: LucideIcons.book,
            label: 'Vocabulário',
          ),
          AppNavItem(
            icon: LucideIcons.library,
            activeIcon: LucideIcons.library,
            label: 'Biblioteca',
          ),
          AppNavItem(
            icon: LucideIcons.headphones,
            activeIcon: LucideIcons.headphones,
            label: 'Ditado',
          ),
          AppNavItem(
            icon: LucideIcons.user,
            activeIcon: LucideIcons.user,
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
