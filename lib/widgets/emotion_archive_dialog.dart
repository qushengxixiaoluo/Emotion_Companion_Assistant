import 'package:flutter/material.dart';
import '../app/styles/app_styles.dart';
import '../app/styles/ui_style.dart';
import '../app/themes/app_colors.dart';
import '../models/emotion_models.dart';
import '../services/storage_service.dart';

/// 情绪归档日历：按月查看有记录的日期，点开某天展示当日情绪变化图谱与日记列表
Future<void> showEmotionArchiveDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const EmotionArchiveDialog(),
  );
}

class EmotionArchiveDialog extends StatefulWidget {
  const EmotionArchiveDialog({super.key});

  @override
  State<EmotionArchiveDialog> createState() => _EmotionArchiveDialogState();
}

class _EmotionArchiveDialogState extends State<EmotionArchiveDialog> {
  final StorageService _storage = StorageService();

  List<EmotionRecord> _records = [];
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  /// 'yyyy-M-d' → 该天有记录
  final Set<String> _daysWithRecords = {};
  /// 'yyyy-M-d' → 该天汇总主导情绪（用于圆点颜色）
  final Map<String, String> _dayDominant = {};

  static const Map<String, Color> _emotionColors = {
    '悲伤': AppColors.softPink,
    '焦虑': AppColors.softOrange,
    '愤怒': AppColors.angerRed,
    '孤独': AppColors.gentlePurple,
    '开心': AppColors.calmGreen,
    '平静': AppColors.lightCyan,
    '压抑': AppColors.warmBeige,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Future<void> _load() async {
    final records = await _storage.getAllRecords();
    records.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final days = <String>{};
    final dominant = <String, List<EmotionRecord>>{};
    for (final r in records) {
      if (r.dominantEmotion == '分析中...') continue;
      final key = _dayKey(r.createdAt);
      days.add(key);
      dominant.putIfAbsent(key, () => []).add(r);
    }

    DateTime? latestDay;
    for (final r in records.reversed) {
      if (r.dominantEmotion == '分析中...') continue;
      latestDay = DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);
      break;
    }

    if (!mounted) return;
    setState(() {
      _records = records;
      _daysWithRecords
        ..clear()
        ..addAll(days);
      _dayDominant
        ..clear()
        ..addEntries(dominant.entries.map((e) =>
            MapEntry(e.key, _aggregateDominant(e.value))));
      if (latestDay != null) {
        _focusedMonth = DateTime(latestDay.year, latestDay.month);
        _selectedDay = latestDay;
      } else {
        final now = DateTime.now();
        _focusedMonth = DateTime(now.year, now.month);
        _selectedDay = DateTime(now.year, now.month, now.day);
      }
    });
  }

  /// 当天多条记录的主导情绪：取分数最高维度的众数
  String _aggregateDominant(List<EmotionRecord> dayRecords) {
    final counts = <String, int>{};
    for (final r in dayRecords) {
      counts[r.dominantEmotion] = (counts[r.dominantEmotion] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
      // 切月后默认选中该月第一个有记录的日子（没有则不选中具体日）
      String? firstKey;
      for (int day = 1; day <= 31; day++) {
        final d = DateTime(_focusedMonth.year, _focusedMonth.month, day);
        if (d.month != _focusedMonth.month) break;
        if (_daysWithRecords.contains(_dayKey(d))) {
          firstKey = _dayKey(d);
          _selectedDay = d;
          break;
        }
      }
      if (firstKey == null) _selectedDay = null;
    });
  }

  List<EmotionRecord> _recordsOfSelectedDay() {
    final day = _selectedDay;
    if (day == null) return [];
    final key = _dayKey(day);
    return _records
        .where((r) =>
            _dayKey(r.createdAt) == key && r.dominantEmotion != '分析中...')
        .toList();
  }

  /// 情绪指数 ∈ [-1, 1]：正向(开心/平静)均值 − 负向(悲伤/焦虑/愤怒/孤独/压抑)均值
  double _emotionIndex(EmotionRecord r) {
    final positive = (r.happiness + r.calmness) / 2;
    final negative = (r.sadness + r.anxiety + r.anger + r.loneliness + r.suppression) / 5;
    return (positive - negative).clamp(-1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // shape 交给主题 dialogTheme（2px 描边 + radius 20）
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            _buildMonthNav(context),
            _buildWeekdayRow(),
            _buildCalendarGrid(context),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(height: 1),
            ),
            Flexible(child: _buildDayPanel(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.hazeBlue.withValues(alpha: 0.1),
              borderRadius: AppRadius.smB,
            ),
            child: Icon(Icons.calendar_month_outlined,
                size: 18, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(width: 10),
          Text(
            '情绪归档',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, size: 20,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNav(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, size: 22,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            onPressed: () => _changeMonth(-1),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${_focusedMonth.year}年${_focusedMonth.month}月',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, size: 22,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow() {
    const labels = ['日', '一', '二', '三', '四', '五', '六'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: labels
            .map((l) => Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context) {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final leading = firstDay.weekday % 7; // 周日起始
    final today = DateTime.now();
    final todayKey = _dayKey(today);

    final cells = <Widget>[];
    for (int i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final key = _dayKey(date);
      final hasRecord = _daysWithRecords.contains(key);
      final isSelected = _selectedDay != null && _dayKey(_selectedDay!) == key;
      final isToday = key == todayKey;
      final dotColor = hasRecord
          ? (_emotionColors[_dayDominant[key]] ?? AppColors.hazeBlue)
          : Colors.transparent;

      cells.add(
        GestureDetector(
          onTap: () => setState(() => _selectedDay = date),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.hazeBlue.withValues(alpha: 0.15)
                  : (isToday
                      ? AppColors.hazeBlue.withValues(alpha: 0.06)
                      : Colors.transparent),
              borderRadius: AppRadius.smB,
              border: isSelected
                  ? AppStroke.all(context, width: AppStroke.thin)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
                    color: hasRecord || isSelected
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.86,
        children: cells,
      ),
    );
  }

  Widget _buildDayPanel(BuildContext context) {
    final dayRecords = _recordsOfSelectedDay();
    final day = _selectedDay;

    if (day == null) {
      return _buildHint('点开日历上的日期', '查看当天的情绪变化图谱与日记');
    }
    if (dayRecords.isEmpty) {
      return _buildHint('${day.month}月${day.day}日 没有记录', '这一天的树洞是安静的');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${day.month}月${day.day}日',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                '${dayRecords.length} 条记录',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 当日情绪变化图谱
          SizedBox(
            height: 132,
            width: double.infinity,
            child: CustomPaint(
              painter: _DayEmotionChartPainter(
                isDark: Theme.of(context).brightness == Brightness.dark,
                style: UiStyleScope.of(context),
                points: dayRecords
                    .map((r) => _DayPoint(
                          timeFraction:
                              (r.createdAt.hour * 3600 + r.createdAt.minute * 60) /
                                  (24 * 3600),
                          index: _emotionIndex(r),
                          color:
                              _emotionColors[r.dominantEmotion] ?? AppColors.hazeBlue,
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '情绪指数：开心/平静（上） vs 悲伤/焦虑等（下）',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          ...dayRecords.map((r) => _buildRecordTile(context, r)),
        ],
      ),
    );
  }

  Widget _buildHint(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_available_outlined,
                size: 34, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordTile(BuildContext context, EmotionRecord r) {
    final color = _emotionColors[r.dominantEmotion] ?? AppColors.hazeBlue;
    final time =
        '${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.6),
        borderRadius: AppRadius.smB,
        border: AppStroke.all(context, width: AppStroke.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(time,
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(width: 6),
                    Text(r.dominantEmotion,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  r.content.length > 60
                      ? '${r.content.substring(0, 60)}……'
                      : r.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayPoint {
  final double timeFraction; // 0..1 当天时刻
  final double index; // -1..1 情绪指数
  final Color color;
  const _DayPoint({
    required this.timeFraction,
    required this.index,
    required this.color,
  });
}

/// 当日情绪变化折线图：横轴 0-24 点，纵轴 情绪指数 -1..1（0 为中性基线）
class _DayEmotionChartPainter extends CustomPainter {
  final List<_DayPoint> points;
  final bool isDark;
  final AppUiStyle style;
  _DayEmotionChartPainter({
    required this.points,
    required this.isDark,
    this.style = AppUiStyle.lowPoly,
  });

  bool get _watercolor => style == AppUiStyle.watercolor;

  /// 水彩：线宽收细 0.3，圆头手绘感；lowPoly 原值
  double _sw(double w) => _watercolor && w > 0.7 ? w - 0.3 : w;

  /// 语义色/面片填充在水彩下 alpha ×0.75（更清透）
  double _fillA(double a) => _watercolor ? a * 0.75 : a;

  /// 描边：lowPoly 保持原样（butt 直角），水彩收细 + 圆头圆角
  Paint _stroke(double width, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _sw(width);
    if (_watercolor) {
      p
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 8.0, padR = 8.0, padT = 10.0, padB = 18.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    final ink = AppStroke.ink(isDark: isDark, style: style);

    Offset posOf(_DayPoint p) {
      final x = padL + p.timeFraction * w;
      final y = padT + (1 - (p.index + 1) / 2) * h; // index=1 → 顶部
      return Offset(x, y);
    }

    // 中性基线（index=0）
    final baseY = padT + h / 2;
    final baseLine = _stroke(1, ink.withValues(alpha: 0.30));
    canvas.drawLine(Offset(padL, baseY), Offset(size.width - padR, baseY), baseLine);

    // 时段刻度
    final tickPaint = _stroke(1, ink.withValues(alpha: 0.45));
    final tp = TextPainter(
      text: TextSpan(
        text: '',
        style: TextStyle(
            fontSize: 8.5, color: ink),
      ),
      textDirection: TextDirection.ltr,
    );
    for (final hour in const [0, 6, 12, 18, 24]) {
      final x = padL + (hour / 24) * w;
      canvas.drawLine(
          Offset(x, padT + h), Offset(x, padT + h + 3), tickPaint);
      tp.text = TextSpan(
        text: '$hour',
        style: TextStyle(
            fontSize: 8.5, color: ink),
      );
      tp.layout();
      final dx = (x - tp.width / 2).clamp(0.0, (size.width - tp.width).clamp(0.0, double.infinity));
      tp.paint(canvas, Offset(dx, padT + h + 5));
    }

    if (points.isEmpty) return;

    // 折线（含闭合到基线的低透明面片）
    if (points.length > 1) {
      final sorted = [...points]..sort((a, b) => a.timeFraction.compareTo(b.timeFraction));
      final path = Path()..moveTo(posOf(sorted.first).dx, posOf(sorted.first).dy);
      for (final p in sorted.skip(1)) {
        path.lineTo(posOf(p).dx, posOf(p).dy);
      }

      // 面片：折线闭合到中性基线，画在折线之前
      final areaPath = Path.from(path)
        ..lineTo(posOf(sorted.last).dx, baseY)
        ..lineTo(posOf(sorted.first).dx, baseY)
        ..close();
      canvas.drawPath(
        areaPath,
        Paint()..color = AppColors.hazeBlue.withValues(alpha: _fillA(0.10)),
      );

      final linePaint = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = _sw(2.0)
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, linePaint);
    }

    // 数据点（按主导情绪着色）：菱形实色 + ink 描边，无光晕
    for (final p in points) {
      final c = posOf(p);
      const r = 5.0;
      final diamond = Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r, c.dy)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - r, c.dy)
        ..close();
      canvas.drawPath(
          diamond, Paint()..color = p.color.withValues(alpha: _fillA(p.color.a)));
      canvas.drawPath(diamond, _stroke(1.5, ink));
    }
  }

  @override
  bool shouldRepaint(covariant _DayEmotionChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.isDark != isDark ||
      oldDelegate.style != style;
}
