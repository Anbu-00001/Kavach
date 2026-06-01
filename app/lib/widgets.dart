// widgets.dart — shared primitives: shield, button, chip, brand mark, screen scaffold.
import 'package:flutter/material.dart';
import 'theme.dart';

// ───────────── Listening-rings shield ─────────────
class Shield extends StatefulWidget {
  final double size;
  final Color color;
  final bool listening;
  const Shield({super.key, this.size = 200, required this.color, this.listening = false});
  @override
  State<Shield> createState() => _ShieldState();
}

class _ShieldState extends State<Shield> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _ShieldPainter(widget.color, widget.listening ? _c.value : -1),
          ),
        ),
      );
}

class _ShieldPainter extends CustomPainter {
  final Color c;
  final double t; // <0 = not listening
  _ShieldPainter(this.c, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200.0;
    final center = Offset(100 * s, 100 * s);
    void ring(double r, double op) => canvas.drawCircle(center, r * s,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 3 * s..color = c.withValues(alpha: op));
    ring(92, 0.16);
    ring(66, 0.34);
    ring(40, 0.6);
    canvas.drawCircle(center, 17 * s, Paint()..color = c);
    if (t >= 0) {
      final r = 17 + t * (92 - 17);
      canvas.drawCircle(center, r * s,
          Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5 * s..color = c.withValues(alpha: 0.55 * (1 - t)));
    }
  }

  @override
  bool shouldRepaint(_ShieldPainter old) => old.t != t || old.c != c;
}

// ───────────── Button ─────────────
class KButton extends StatefulWidget {
  final String label;
  final String? sub;
  final IconData? icon;
  final String kind; // primary, danger, secondary, soft, ghost
  final Color? color;
  final bool disabled;
  final VoidCallback? onTap;
  const KButton(this.label, {super.key, this.sub, this.icon, this.kind = 'primary', this.color, this.disabled = false, this.onTap});
  @override
  State<KButton> createState() => _KButtonState();
}

class _KButtonState extends State<KButton> {
  bool down = false;
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    final p = t.pal;
    Color bg, fg;
    Border? border;
    final accent = widget.color ?? p.brand;
    switch (widget.kind) {
      case 'danger': bg = p.high; fg = Colors.white; break;
      case 'secondary': bg = Colors.transparent; fg = p.ink; border = Border.all(color: p.line, width: 2); break;
      case 'soft': bg = p.surface2; fg = p.ink; break;
      case 'ghost': bg = Colors.transparent; fg = p.inkSoft; break;
      default: bg = accent; fg = p.onColor;
    }
    final elevated = widget.kind == 'primary' || widget.kind == 'danger';
    return Opacity(
      opacity: widget.disabled ? 0.5 : 1,
      child: GestureDetector(
        onTapDown: (_) => setState(() => down = true),
        onTapUp: (_) => setState(() => down = false),
        onTapCancel: () => setState(() => down = false),
        onTap: widget.disabled ? null : widget.onTap,
        child: AnimatedScale(
          scale: down ? 0.975 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 66),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(22), border: border,
              boxShadow: elevated ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8))] : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[Icon(widget.icon, color: fg, size: 24), const SizedBox(width: 12)],
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.label, textAlign: TextAlign.center, style: kfont(21 * t.scale, FontWeight.w800, fg, spacing: 0.1)),
                      if (widget.sub != null) Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(widget.sub!, textAlign: TextAlign.center, style: kfont(14 * t.scale, FontWeight.w600, fg.withValues(alpha: 0.85))),
                      ),
                    ],
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

// ───────────── Chip ─────────────
class KChip extends StatelessWidget {
  final String label;
  final Color tint, ink;
  const KChip(this.label, {super.key, required this.tint, required this.ink});
  @override
  Widget build(BuildContext context) {
    final t = KavachTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: ink.withValues(alpha: 0.8), shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text(label, style: kfont(15.5 * t.scale, FontWeight.w700, ink)),
      ]),
    );
  }
}

// ───────────── Brand mark ─────────────
class BrandMark extends StatelessWidget {
  final bool light;
  const BrandMark({super.key, this.light = false});
  @override
  Widget build(BuildContext context) {
    final p = KavachTheme.of(context).pal;
    final c = light ? Colors.white : p.ink;
    final accent = light ? Colors.white : p.brand;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 26, height: 26, child: CustomPaint(painter: _BrandPainter(accent))),
      const SizedBox(width: 10),
      Text('Kavach', style: kfont(22, FontWeight.w800, c, spacing: 0.2)),
      const SizedBox(width: 8),
      Text('कवच', style: kfont(17, FontWeight.w600, c.withValues(alpha: 0.4))),
    ]);
  }
}

class _BrandPainter extends CustomPainter {
  final Color c;
  _BrandPainter(this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200.0;
    final ctr = Offset(100 * s, 100 * s);
    void ring(double r, double op) => canvas.drawCircle(ctr, r * s, Paint()..style = PaintingStyle.stroke..strokeWidth = 10 * s..color = c.withValues(alpha: op));
    ring(88, 0.25);
    ring(56, 0.5);
    canvas.drawCircle(ctr, 20 * s, Paint()..color = c);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ───────────── Progress dots ─────────────
class ProgressDots extends StatelessWidget {
  final int step, total;
  const ProgressDots(this.step, this.total, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = KavachTheme.of(context).pal;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < total; i++)
        Padding(
          padding: const EdgeInsets.only(right: 7),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == step ? 26 : 9, height: 9,
            decoration: BoxDecoration(color: i == step ? p.brand : p.line, borderRadius: BorderRadius.circular(99)),
          ),
        ),
    ]);
  }
}

// ───────────── Screen scaffold (header / scroll body / sticky footer) ─────────────
class KScreen extends StatelessWidget {
  final Widget? header;
  final Widget body;
  final List<Widget>? footer;
  final Color? bg;
  const KScreen({super.key, this.header, required this.body, this.footer, this.bg});
  @override
  Widget build(BuildContext context) {
    final p = KavachTheme.of(context).pal;
    final back = bg ?? p.bg;
    return Container(
      color: back,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 60, 26, 8),
          child: SizedBox(height: 46, child: header ?? const SizedBox()),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 0, 26, 24),
            child: body,
          ),
        ),
        if (footer != null)
          Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [back.withValues(alpha: 0), back], stops: const [0, 0.28],
              ),
            ),
            child: Column(children: [
              for (var i = 0; i < footer!.length; i++) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 12), child: footer![i]),
            ]),
          ),
      ]),
    );
  }
}

class BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const BackBtn(this.onTap, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = KavachTheme.of(context).pal;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle, border: Border.all(color: p.line, width: 2)),
        child: Icon(Icons.arrow_back, color: p.ink, size: 22),
      ),
    );
  }
}
