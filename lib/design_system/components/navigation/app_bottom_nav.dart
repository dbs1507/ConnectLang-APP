import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

/// Um item da bottom nav. [icon] fica quando inativo, [activeIcon] some no
/// lugar quando selecionado — mesmo padrão do Material (contorno inativo,
/// preenchido ativo), pra usar o Efeito de Jakob a favor.
class AppNavItem {
  const AppNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Bottom navigation fixa — máximo 4–5 itens (Lei de Hick: poucas opções,
/// decisão rápida), sem drawer lateral. O item 0 é sempre a home
/// "continuar de onde parou", nunca um dashboard genérico.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  }) : assert(
         items.length >= 3 && items.length <= 5,
         'Bottom nav deve ter entre 3 e 5 itens (Lei de Hick).',
       );

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.yellowPale16,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const _navAnim = Duration(milliseconds: 280);
const _navCurve = Curves.easeOutCubic;

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.buttonBlack;
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.buttonBlack.withValues(alpha: 0.1),
      highlightColor: AppColors.buttonBlack.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Center(
          child: AnimatedContainer(
            duration: _navAnim,
            curve: _navCurve,
            constraints: const BoxConstraints(minWidth: 56),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? AppColors.buttonBlack : Colors.transparent,
              borderRadius: AppRadius.buttonShape,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: _navAnim,
                  switchInCurve: _navCurve,
                  switchOutCurve: _navCurve,
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    key: ValueKey(selected),
                    size: 20,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedDefaultTextStyle(
                    duration: _navAnim,
                    curve: _navCurve,
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: color,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    child: Text(
                      item.label,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
