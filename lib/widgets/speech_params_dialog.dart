import 'package:flutter/material.dart';
import '../app/styles/app_styles.dart';
import '../app/themes/app_colors.dart';
import '../app/config/speech_config.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';

Future<void> showSpeechParamsDialog(BuildContext context) async {
  final speechService = SpeechService();
  final storageService = StorageService();

  final userSpeed = await storageService.getTtsSpeed();
  final userVolume = await storageService.getTtsVolume();
  final userPitch = await storageService.getTtsPitch();

  double speed = userSpeed ?? SpeechConfig.ttsSpeed;
  double volume = userVolume ?? SpeechConfig.defaultVolume;
  double pitch = userPitch ?? SpeechConfig.defaultPitch;

  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: BoxDecoration(
            // 与主题 dialogTheme 的 dialogB(20) 顶部圆角配对
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            gradient: LinearGradient(
              colors: [
                AppColors.softOrange.withValues(alpha: 0.08),
                AppColors.softOrange.withValues(alpha: 0.01),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.softOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.tune, color: Theme.of(context).colorScheme.onSurface, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('语音参数', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    Text(
                      '调节 TTS 朗读的语速、音量与音调',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                _buildSliderSection(
                  context: context,
                  icon: Icons.speed,
                  label: '语速',
                  value: speed,
                  valueText: '${speed.toStringAsFixed(1)}x',
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  minLabel: '0.5x 慢速',
                  maxLabel: '2.0x 快速',
                  color: AppColors.softOrange,
                  onChanged: (v) => setDialogState(() => speed = v),
                ),
                const SizedBox(height: 20),

                _buildSliderSection(
                  context: context,
                  icon: Icons.volume_up_outlined,
                  label: '音量',
                  value: volume,
                  valueText: '${volume.toStringAsFixed(1)}x',
                  min: 0.1,
                  max: 3.0,
                  divisions: 29,
                  minLabel: '0.1x 静音',
                  maxLabel: '3.0x 响亮',
                  color: AppColors.gentlePurple,
                  onChanged: (v) => setDialogState(() => volume = v),
                ),
                const SizedBox(height: 20),

                _buildSliderSection(
                  context: context,
                  icon: Icons.music_note_outlined,
                  label: '音调',
                  value: pitch,
                  valueText: '${pitch.toStringAsFixed(1)}x',
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  minLabel: '0.5x 低沉',
                  maxLabel: '2.0x 尖锐',
                  color: AppColors.lightCyan,
                  onChanged: (v) => setDialogState(() => pitch = v),
                ),

                const SizedBox(height: 24),
                const Divider(height: 1),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await storageService.setTtsSpeed(SpeechConfig.ttsSpeed);
                        await storageService.setTtsVolume(SpeechConfig.defaultVolume);
                        await storageService.setTtsPitch(SpeechConfig.defaultPitch);
                        await speechService.reloadTtsConfig();
                        setDialogState(() {
                          speed = SpeechConfig.ttsSpeed;
                          volume = SpeechConfig.defaultVolume;
                          pitch = SpeechConfig.defaultPitch;
                        });
                      },
                      child: const Text('恢复默认', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        await storageService.setTtsSpeed(speed);
                        await storageService.setTtsVolume(volume);
                        await storageService.setTtsPitch(pitch);
                        await speechService.reloadTtsConfig();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.softOrange,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        elevation: 0,
                      ),
                      child: const Text('保存', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildSliderSection({
  required BuildContext context,
  required IconData icon,
  required String label,
  required double value,
  required String valueText,
  required double min,
  required double max,
  required int divisions,
  required String minLabel,
  required String maxLabel,
  required Color color,
  required ValueChanged<double> onChanged,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.04),
      borderRadius: AppRadius.smB,
      border: AppStroke.all(context, width: AppStroke.thin),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                valueText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 8,
              pressedElevation: 4,
            ),
            overlayShape: const RoundSliderOverlayShape(
              overlayRadius: 16,
            ),
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.12),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.08),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface)),
              Text(maxLabel, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
        ),
      ],
    ),
  );
}
