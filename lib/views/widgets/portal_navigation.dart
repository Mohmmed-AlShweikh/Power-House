import 'package:flutter/material.dart';
import '../../theme/portal_tokens.dart';

enum PortalNavAlternative { raisedTiles, separateIslands, focusWindow }

class PortalNavItem {
  final String label;
  final IconData icon;
  const PortalNavItem(this.label, this.icon);
}

const consumerNavItems = [
  PortalNavItem('الرئيسية', Icons.home_outlined),
  PortalNavItem('الاستهلاك', Icons.bar_chart_outlined),
  PortalNavItem('الفواتير', Icons.receipt_long_outlined),
  PortalNavItem('الملف', Icons.person_outline),
];
const adminNavItems = [
  PortalNavItem('نظرة عامة', Icons.dashboard_outlined),
  PortalNavItem('المشتركون', Icons.people_outline),
  PortalNavItem('الفواتير', Icons.receipt_long_outlined),
  PortalNavItem('الشكاوى', Icons.chat_bubble_outline),
  PortalNavItem('المزيد', Icons.more_horiz),
];

/// Three distinct structures, all 80dp including the lift and outer padding.
/// Order follows inherited RTL; selected state also uses shape/position/weight.
class PortalFloatingNavigation extends StatelessWidget {
  final List<PortalNavItem> items;
  final int selected;
  final ValueChanged<int> onSelected;
  final PortalNavAlternative alternative;
  const PortalFloatingNavigation(
      {super.key,
      required this.items,
      required this.selected,
      required this.onSelected,
      this.alternative = PortalNavAlternative.raisedTiles});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final islands = alternative == PortalNavAlternative.separateIslands;
    final focus = alternative == PortalNavAlternative.focusWindow;
    return SizedBox(
      height: PortalTokens.navHeight,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
            start: PortalTokens.navInset,
            end: PortalTokens.navInset,
            top: PortalTokens.sm,
            bottom: PortalTokens.xs),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: islands ? PortalTokens.transparent : colors.surface,
            borderRadius: BorderRadius.circular(
                focus ? PortalTokens.radius : PortalTokens.radiusSheet),
            border: islands ? null : Border.all(color: colors.outlineVariant),
            boxShadow: islands
                ? null
                : const [
                    BoxShadow(
                        color: PortalTokens.subtleShadow,
                        blurRadius: PortalTokens.sm,
                        offset: Offset(0, PortalTokens.xs))
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(items.length, (i) {
              final active = i == selected;
              final expanded = focus && active;
              final label = Text(items[i].label,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: (active
                          ? PortalTokens.navActiveLabel
                          : PortalTokens.navLabel)
                      .copyWith(color: colors.onSurface));
              final icon = Icon(items[i].icon,
                  size: islands ? PortalTokens.gutter : PortalTokens.icon,
                  color: active && !islands && !focus
                      ? colors.onPrimary
                      : active
                          ? colors.primary
                          : colors.onSurfaceVariant);
              Widget content;
              if (expanded) {
                content = DecoratedBox(
                  decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(PortalTokens.radius),
                      border: Border.all(
                          color: colors.primary,
                          width: PortalTokens.focusLine)),
                  child: Padding(
                      padding: const EdgeInsets.all(PortalTokens.xs),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            icon,
                            const SizedBox(width: PortalTokens.xs),
                            Flexible(child: label),
                          ])),
                );
              } else if (islands) {
                content = DecoratedBox(
                  decoration: BoxDecoration(
                      color: active ? colors.primaryContainer : colors.surface,
                      borderRadius: BorderRadius.circular(PortalTokens.radius),
                      border: Border.all(
                          color:
                              active ? colors.primary : colors.outlineVariant,
                          width: active
                              ? PortalTokens.focusLine
                              : PortalTokens.line)),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        icon,
                        const SizedBox(height: PortalTokens.xs),
                        label,
                        Container(
                            width: PortalTokens.lg,
                            height: PortalTokens.xs,
                            color: active
                                ? colors.primary
                                : PortalTokens.transparent),
                      ]),
                );
              } else {
                final tile = Container(
                    width: focus ? PortalTokens.icon : PortalTokens.navTile,
                    height: focus ? PortalTokens.icon : PortalTokens.navTile,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: active && !focus
                            ? colors.primary
                            : PortalTokens.transparent,
                        borderRadius:
                            BorderRadius.circular(PortalTokens.radius),
                        boxShadow: active && !focus
                            ? const [
                                BoxShadow(
                                    color: PortalTokens.subtleShadow,
                                    blurRadius: PortalTokens.sm,
                                    offset: Offset(0, PortalTokens.xs))
                              ]
                            : null),
                    child: icon);
                content = Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.translate(
                          offset: Offset(
                              0, active && !focus ? -PortalTokens.navLift : 0),
                          child: tile),
                      label,
                    ]);
              }
              return Expanded(
                  flex: expanded ? 2 : 1,
                  child: Padding(
                    padding: EdgeInsets.all(
                        islands ? PortalTokens.xs : PortalTokens.zero),
                    child: Semantics(
                        selected: active,
                        button: true,
                        label: items[i].label,
                        child: Material(
                          color: PortalTokens.transparent,
                          child: InkWell(
                              key: ValueKey('nav-${items[i].label}'),
                              borderRadius:
                                  BorderRadius.circular(PortalTokens.radius),
                              onTap: () => onSelected(i),
                              child: Padding(
                                  padding: EdgeInsets.all(focus
                                      ? PortalTokens.xs
                                      : PortalTokens.zero),
                                  child: content)),
                        )),
                  ));
            }),
          ),
        ),
      ),
    );
  }
}
