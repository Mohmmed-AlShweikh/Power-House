import 'package:flutter/material.dart';
import '../../theme/portal_tokens.dart';
import 'portal_number.dart';
import 'portal_navigation.dart';

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
  Widget build(BuildContext context) => PortalFloatingNavigation(
        items: consumerNavItems,
        selected: selected,
        onSelected: onSelected,
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
                  PortalNumber(subtitle,
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
  final String? scheduledOnValue, scheduledOffValue, tariff;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onSettings;
  const PortalGeneratorPanel(
      {super.key,
      required this.isOn,
      required this.detail,
      this.scheduledOnValue,
      this.scheduledOffValue,
      this.tariff,
      this.onToggle,
      this.onSettings});
  @override
  Widget build(BuildContext context) {
    final tone = isOn ? PortalTone.working : PortalTone.stopped;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (toneInk, toneFill) = tone.colors(context);
    final ink = isOn && !dark ? PortalTokens.surface : toneInk;
    final fill = isOn && !dark ? PortalTokens.working : toneFill;
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: PortalTokens.heroHeight),
      padding: const EdgeInsets.all(PortalTokens.xl),
      decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(PortalTokens.radiusPanel),
          border: Border.all(color: toneInk)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isOn ? Icons.power_settings_new : Icons.power_off_outlined,
              color: ink, size: PortalTokens.xxl),
          const SizedBox(width: PortalTokens.md),
          Expanded(
              child: Text('حالة المولد',
                  style: text.labelLarge?.copyWith(color: ink))),
          if (onSettings != null)
            IconButton(
                onPressed: onSettings,
                tooltip: 'تحديث السعر والجدول',
                icon: Icon(Icons.tune_outlined, color: ink)),
          if (onToggle != null)
            RepaintBoundary(
                key: const ValueKey('generator-switch-zoom'),
                child: ColoredBox(
                    color: fill,
                    child: Switch(
                      value: isOn,
                      onChanged: onToggle,
                      activeTrackColor: PortalTokens.generatorSwitchTrack,
                      activeThumbColor: PortalTokens.generatorSwitchThumb,
                      inactiveTrackColor: PortalTone.stopped.colors(context).$1,
                      inactiveThumbColor:
                          Theme.of(context).colorScheme.onSurface,
                      trackOutlineColor: const WidgetStatePropertyAll(
                          PortalTokens.transparent),
                      thumbIcon: WidgetStateProperty.resolveWith((states) =>
                          Icon(
                              states.contains(WidgetState.selected)
                                  ? Icons.check
                                  : Icons.remove,
                              size: PortalTokens.lg,
                              color: isOn
                                  ? PortalTokens.working
                                  : PortalTone.stopped.colors(context).$2)),
                    ))),
        ]),
        const SizedBox(height: PortalTokens.lg),
        Text(isOn ? 'المولد يعمل الآن' : 'المولد متوقف',
            style: text.headlineLarge?.copyWith(color: ink)),
        const SizedBox(height: PortalTokens.xs),
        PortalNumber(detail, style: text.bodyMedium?.copyWith(color: ink)),
        if (tariff != null ||
            scheduledOnValue != null ||
            scheduledOffValue != null) ...[
          const SizedBox(height: PortalTokens.lg),
          if (tariff != null)
            RepaintBoundary(
                key: const ValueKey('generator-price-zoom'),
                child: ColoredBox(
                    color: fill,
                    child: PortalLabelValue(
                        label: 'سعر kWh', value: tariff!, ink: ink))),
          if (scheduledOnValue != null)
            PortalLabelValue(
                label: 'تشغيل مجدول', value: scheduledOnValue!, ink: ink),
          if (scheduledOffValue != null)
            PortalLabelValue(
                label: 'إيقاف مجدول', value: scheduledOffValue!, ink: ink),
        ],
      ]),
    );
  }
}

class PortalMetric extends StatelessWidget {
  final String label, value;
  final String? footnote;
  final IconData icon;
  const PortalMetric(
      {super.key,
      required this.label,
      required this.value,
      this.footnote,
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
          PortalNumber(value, style: Theme.of(context).textTheme.headlineLarge),
          if (footnote != null)
            PortalNumber(footnote!,
                style: Theme.of(context).textTheme.bodySmall),
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

class PortalDataRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const PortalDataRow(
      {super.key,
      required this.label,
      required this.value,
      required this.icon});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: PortalTokens.md),
        child: Row(children: [
          Icon(icon,
              color: Theme.of(context).colorScheme.primary,
              size: PortalTokens.gutter),
          const SizedBox(width: PortalTokens.md),
          Expanded(
              child:
                  Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          const SizedBox(width: PortalTokens.sm),
          Expanded(
              child: PortalNumber(value,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.titleMedium)),
        ]),
      );
}

class PortalRecordRow extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final String? trailing, statusLabel;
  final PortalTone statusTone;
  final VoidCallback? onTap;
  const PortalRecordRow(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      this.trailing,
      this.statusLabel,
      this.statusTone = PortalTone.stopped,
      this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PortalTokens.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: PortalTokens.smallIconBox,
                height: PortalTokens.smallIconBox,
                decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(PortalTokens.radiusSmall),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant)),
                child: Icon(icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: PortalTokens.gutter)),
            const SizedBox(width: PortalTokens.md),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: PortalTokens.xs),
                  PortalNumber(subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  if (statusLabel != null)
                    Padding(
                        padding: const EdgeInsets.only(top: PortalTokens.sm),
                        child: PortalStatusChip(
                            label: statusLabel!,
                            tone: statusTone,
                            icon: Icons.circle_outlined)),
                ])),
            if (trailing != null) ...[
              const SizedBox(width: PortalTokens.md),
              PortalNumber(trailing!,
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ]),
        ),
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

/// Scrollable content under the approved floating navigation.
class PortalPage extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children, actions;
  final bool reserveNavigation;
  const PortalPage(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.children,
      this.actions = const [],
      this.reserveNavigation = true});
  @override
  Widget build(BuildContext context) => Scaffold(
          body: Column(children: [
        PortalIdentityBar(title: title, subtitle: subtitle, actions: actions),
        Expanded(
            child: ListView(
                padding: EdgeInsetsDirectional.fromSTEB(
                    PortalTokens.gutter,
                    PortalTokens.sm,
                    PortalTokens.gutter,
                    (reserveNavigation
                            ? PortalTokens.navClearance
                            : PortalTokens.xl) +
                        MediaQuery.paddingOf(context).bottom),
                children: children)),
      ]));
}

/// Separate semantic label and value columns. Currency/unit text never shares
/// a bidi paragraph with the Arabic label.
class PortalLabelValue extends StatelessWidget {
  final String label, value;
  final Color? ink;
  final bool prominent;
  const PortalLabelValue(
      {super.key,
      required this.label,
      required this.value,
      this.ink,
      this.prominent = false});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: PortalTokens.xs),
      child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: PortalNumber(label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: ink))),
            const SizedBox(width: PortalTokens.md),
            Flexible(
                child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(value,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        style: (prominent
                                ? Theme.of(context).textTheme.headlineMedium
                                : Theme.of(context).textTheme.labelLarge)
                            ?.copyWith(color: ink)))),
          ]));
}

class PortalInvoiceRow extends StatelessWidget {
  final String title, amount, status;
  final String? period, note;
  final PortalTone tone;
  final IconData icon;
  final Color? accent;
  final Widget? footer;
  final VoidCallback? onTap;
  const PortalInvoiceRow(
      {super.key,
      required this.title,
      required this.amount,
      required this.status,
      required this.tone,
      required this.icon,
      this.period,
      this.note,
      this.accent,
      this.footer,
      this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: PortalPanel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon,
              color: accent ?? tone.colors(context).$1,
              size: PortalTokens.icon),
          const SizedBox(width: PortalTokens.md),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                PortalNumber(title,
                    style: Theme.of(context).textTheme.titleMedium),
                if (period != null)
                  PortalNumber(period!,
                      style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: PortalTokens.sm),
                Wrap(
                    spacing: PortalTokens.md,
                    runSpacing: PortalTokens.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(amount,
                              textDirection: TextDirection.ltr,
                              style:
                                  Theme.of(context).textTheme.headlineMedium)),
                      PortalStatusChip(
                          label: status,
                          tone: tone,
                          icon: Icons.circle_outlined),
                    ]),
                if (note != null)
                  Padding(
                      padding: const EdgeInsets.only(top: PortalTokens.sm),
                      child: Text(note!,
                          style: Theme.of(context).textTheme.bodySmall)),
              ])),
        ]),
        if (footer != null) ...[
          const SizedBox(height: PortalTokens.md),
          footer!
        ],
      ])));
}

/// Same exception content as the original global error builder, themed only.
class PortalExceptionView extends StatelessWidget {
  final String exceptionText;
  const PortalExceptionView(this.exceptionText, {super.key});
  @override
  Widget build(BuildContext context) => Material(
      child: SafeArea(
          child: Center(
              child: Padding(
                  padding: PortalTokens.pagePadding,
                  child: PortalErrorState(exceptionText)))));
}

class PortalDiagnosticDialog extends StatelessWidget {
  final String title, info;
  final VoidCallback onClose;
  const PortalDiagnosticDialog(
      {super.key,
      required this.title,
      required this.info,
      required this.onClose});
  @override
  Widget build(BuildContext context) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: SingleChildScrollView(
              child: SelectableText(info,
                  style: Theme.of(context).textTheme.bodySmall)),
          actions: [
            ElevatedButton(onPressed: onClose, child: const Text('حسناً'))
          ]);
}
