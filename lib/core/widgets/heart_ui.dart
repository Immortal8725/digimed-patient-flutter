import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Colours from the website "My Heart" design.
class HeartColors {
  static const accent = Color(0xFF1765F2);
  static const darkAccent = Color(0xFF5B8DF7);
  static Color panel(bool dark) => dark ? const Color(0xFF101A2B) : const Color(0xFFEDEDED);
  static Color card(bool dark) => dark ? DigimedBrand.darkSurface : Colors.white;
  static Color inner(bool dark) => dark ? const Color(0xFF1C2A40) : const Color(0xFFF0F0F0);
  static Color accentOf(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? darkAccent : accent;
}

bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Bullet section header with optional trailing widget.
class HeartSection extends StatelessWidget {
  const HeartSection(this.title, this.child, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      HeartHeader(title, subtitle: subtitle, trailing: trailing),
      const SizedBox(height: 10),
      child,
    ]);
  }
}

class HeartHeader extends StatelessWidget {
  const HeartHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(children: [
      Icon(Icons.circle, size: 7, color: HeartColors.accentOf(context)),
      const SizedBox(width: 6),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, overflow: TextOverflow.ellipsis, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (subtitle != null) Text(subtitle!, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
      ?trailing,
    ]);
  }
}

/// White rounded card with a soft shadow.
class HeartCard extends StatelessWidget {
  const HeartCard({super.key, required this.child, this.padding = const EdgeInsets.all(12), this.onTap, this.margin});
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final card = Container(
      decoration: BoxDecoration(
        color: HeartColors.card(dark),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: dark ? Colors.black26 : const Color(0x14000000), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}

/// Rounded square icon chip; [active] fills it with the accent blue.
class HeartIconChip extends StatelessWidget {
  const HeartIconChip(this.icon, {super.key, this.active = false, this.onTap, this.tooltip, this.size = 36});
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = HeartColors.accentOf(context);
    final chip = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: active ? accent : HeartColors.inner(_isDark(context)), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: size / 2, color: active ? Colors.white : Theme.of(context).colorScheme.onSurface),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

/// Grey inner box used for empty states.
class HeartEmptyBox extends StatelessWidget {
  const HeartEmptyBox(this.text, {super.key, this.icon, this.detail, this.action});
  final String text;
  final String? detail;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(color: HeartColors.inner(_isDark(context)), borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, color: muted), const SizedBox(height: 8)],
        Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
        if (detail != null) ...[const SizedBox(height: 4), Text(detail!, textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12))],
        if (action != null) ...[const SizedBox(height: 12), action!],
      ]),
    );
  }
}

/// Rounded blue call to action with a trailing arrow.
class HeartCta extends StatelessWidget {
  const HeartCta(this.label, {super.key, this.onPressed, this.icon = Icons.arrow_forward});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        child: Row(children: [
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          if (icon != null) Icon(icon, size: 18),
        ]),
      ),
    );
  }
}

/// Page body: grey padded list in the same panel style.
class HeartPage extends StatelessWidget {
  const HeartPage({super.key, required this.children, this.onRefresh, this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24)});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final list = ListView(padding: padding, children: [
      for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 16), children[i]],
    ]);
    return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// Card row with an icon chip, title, subtitle and chevron.
class HeartTile extends StatelessWidget {
  const HeartTile({super.key, required this.title, this.subtitle, this.icon = Icons.chevron_right_rounded, this.onTap, this.trailing, this.active = false});
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HeartCard(
        onTap: onTap,
        child: Row(children: [
          HeartIconChip(icon, active: active),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(subtitle!, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
          trailing ?? (onTap == null ? const SizedBox.shrink() : Icon(Icons.arrow_forward_ios_rounded, size: 14, color: HeartColors.accentOf(context))),
        ]),
      ),
    );
  }
}

/// Scrollable page whose content sits in one soft card under a bullet header.
class HeartFormPanel extends StatelessWidget {
  const HeartFormPanel({super.key, required this.title, required this.children, this.padding = const EdgeInsets.all(16)});
  final String title;
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: padding, children: [
      HeartSection(
        title,
        HeartCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    ]);
  }
}
