import 'package:flutter/material.dart';
import '../../theme/portal_tokens.dart';

class PortalBrandMark extends StatelessWidget {
  const PortalBrandMark({super.key});
  @override
  Widget build(BuildContext context) => Image.asset(
        Theme.of(context).brightness == Brightness.dark
            ? 'assets/brand/approved-a/mark-reversed-384.png'
            : 'assets/brand/approved-a/mark-primary-384.png',
        width: PortalTokens.target,
        height: PortalTokens.target,
        semanticLabel: 'بوابة المولدات',
      );
}

/// Common screen frame, ready for the remaining screens after the checkpoint.
class PortalScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? appBar;
  const PortalScaffold(
      {super.key, required this.body, this.bottomNavigationBar, this.appBar});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
      );
}

class PortalActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  const PortalActionButton(
      {super.key, required this.label, this.onPressed, this.busy = false});
  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox.square(
                dimension: PortalTokens.icon,
                child: CircularProgressIndicator())
            : Text(label),
      );
}

class PortalInput extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;
  const PortalInput(
      {super.key,
      required this.label,
      this.controller,
      this.onChanged,
      this.keyboardType,
      this.obscureText = false});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(labelText: label),
      );
}

class PortalConsumerNavigation extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;
  const PortalConsumerNavigation(
      {super.key, required this.selected, required this.onSelected});
  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: onSelected,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined), label: 'الاستهلاك'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'الفواتير'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'الملف'),
        ],
      );
}

class PortalIdentityBar extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> actions;
  const PortalIdentityBar(
      {super.key,
      required this.title,
      required this.subtitle,
      this.actions = const []});
  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: Padding(
          padding: PortalTokens.panelPadding,
          child: Row(children: [
            const PortalBrandMark(),
            const SizedBox(width: PortalTokens.md),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          )),
                ])),
            ...actions,
          ]),
        ),
      );
}

class PortalPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const PortalPanel(
      {super.key,
      required this.child,
      this.padding = PortalTokens.panelPadding});
  @override
  Widget build(BuildContext context) =>
      Card(child: Padding(padding: padding, child: child));
}

class PortalSection extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const PortalSection(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
            top: PortalTokens.xl, bottom: PortalTokens.md),
        child: Row(children: [
          Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (trailing != null) trailing!,
        ]),
      );
}

class PortalStatusChip extends StatelessWidget {
  final String label;
  final PortalTone tone;
  final IconData icon;
  const PortalStatusChip(
      {super.key, required this.label, required this.tone, required this.icon});
  @override
  Widget build(BuildContext context) {
    final (ink, fill) = tone.colors(context);
    return Semantics(
        label: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(PortalTokens.radiusSmall)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: PortalTokens.sm, vertical: PortalTokens.xs),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: PortalTokens.lg, color: ink),
              const SizedBox(width: PortalTokens.xs),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: ink)),
            ]),
          ),
        ));
  }
}

class PortalGeneratorPanel extends StatelessWidget {
  final bool isOn;
  final String detail;
  final String? schedule, tariff;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onSettings;
  const PortalGeneratorPanel(
      {super.key,
      required this.isOn,
      required this.detail,
      this.schedule,
      this.tariff,
      this.onToggle,
      this.onSettings});
  @override
  Widget build(BuildContext context) {
    final tone = isOn ? PortalTone.working : PortalTone.stopped;
    final (ink, fill) = tone.colors(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: PortalTokens.panelPadding,
      decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(PortalTokens.radiusPanel),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isOn ? Icons.power_settings_new : Icons.power_off_outlined,
              color: ink),
          const SizedBox(width: PortalTokens.sm),
          Expanded(
              child: Text('حالة المولد',
                  style: text.labelLarge?.copyWith(color: ink))),
          if (onSettings != null)
            IconButton(
                onPressed: onSettings,
                tooltip: 'تحديث السعر والجدول',
                icon: Icon(Icons.tune_outlined, color: ink)),
          if (onToggle != null) Switch(value: isOn, onChanged: onToggle),
        ]),
        Text(isOn ? 'المولد يعمل الآن' : 'المولد متوقف',
            style: text.headlineMedium?.copyWith(color: ink)),
        const SizedBox(height: PortalTokens.xs),
        Text(detail, style: text.bodyMedium?.copyWith(color: ink)),
        if (tariff != null || schedule != null) ...[
          const SizedBox(height: PortalTokens.md),
          if (tariff != null)
            Text(tariff!, style: text.labelLarge?.copyWith(color: ink)),
          if (schedule != null)
            Text(schedule!, style: text.bodySmall?.copyWith(color: ink)),
        ],
      ]),
    );
  }
}

class PortalMetric extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const PortalMetric(
      {super.key,
      required this.label,
      required this.value,
      required this.icon});
  @override
  Widget build(BuildContext context) => PortalPanel(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon,
                color: Theme.of(context).colorScheme.primary,
                size: PortalTokens.gutter),
            const SizedBox(width: PortalTokens.sm),
            Expanded(
                child:
                    Text(label, style: Theme.of(context).textTheme.bodySmall)),
          ]),
          const SizedBox(height: PortalTokens.sm),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
        ],
      ));
}

class PortalMetricPair extends StatelessWidget {
  final Widget first, second;
  const PortalMetricPair(
      {super.key, required this.first, required this.second});
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: first),
        const SizedBox(width: PortalTokens.md),
        Expanded(child: second),
      ]);
}

class PortalRecordRow extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final String? trailing;
  final VoidCallback? onTap;
  const PortalRecordRow(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      this.trailing,
      this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: PortalTokens.sm,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: trailing == null
            ? null
            : Text(trailing!, style: Theme.of(context).textTheme.labelSmall),
        onTap: onTap,
      );
}

class PortalEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const PortalEmptyState(this.message,
      {super.key, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: PortalTokens.xl),
        child: Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: PortalTokens.md),
          Expanded(child: Text(message)),
        ]),
      );
}

class PortalLoadingState extends StatelessWidget {
  const PortalLoadingState({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: PortalTokens.panelPadding,
        child: Center(
            child: Semantics(
                label: 'جارٍ التحميل',
                child: const CircularProgressIndicator())),
      );
}

class PortalErrorState extends StatelessWidget {
  final String message;
  const PortalErrorState(this.message, {super.key});
  @override
  Widget build(BuildContext context) =>
      PortalEmptyState(message, icon: Icons.error_outline);
}

class PortalDestinations extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;
  const PortalDestinations(
      {super.key, required this.selected, required this.onSelected});
  static const labels = [
    'نظرة عامة',
    'الطلبات',
    'المشتركون',
    'الفواتير',
    'الشكاوى',
    'ملفي'
  ];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.pending_actions_outlined,
    Icons.people_outline,
    Icons.receipt_long_outlined,
    Icons.chat_bubble_outline,
    Icons.person_outline
  ];
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: PortalTokens.lg),
        child: Column(
            children: List.generate(
                2,
                (row) => Row(
                      children: List.generate(3, (column) {
                        final i = row * 3 + column;
                        return Expanded(
                            child: Padding(
                          padding: const EdgeInsets.all(PortalTokens.xs),
                          child: Semantics(
                              selected: selected == i,
                              child: TextButton.icon(
                                onPressed: () => onSelected(i),
                                style: TextButton.styleFrom(
                                    backgroundColor: selected == i
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                        : PortalTokens.transparent),
                                icon: Icon(icons[i], size: PortalTokens.gutter),
                                label: Text(labels[i],
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium),
                              )),
                        ));
                      }),
                    ))),
      );
}
