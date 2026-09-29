import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// 全局白噪音服务（应用级单例）
///
/// 情绪树洞有两个入口，会产生两个 TreeholePage 实例：
/// 1. 底部 Tab「树洞」（IndexedStack 保活，页面不销毁）
/// 2. 首页「开始情绪倾诉」（Get.toNamed 推送路由，返回即 dispose）
///
/// 之前每个实例各持一个 AudioPlayer，导致：推送路由退出时 dispose 把声音关掉；
/// 两个实例还可能各放一层白噪音叠加。收敛到全局单例后：
/// - 退出任一入口，白噪音继续播放（与 Tab 入口行为一致）
/// - 全局只有一层声音，currentNoise 通过 ValueNotifier 同步给所有页面实例
class WhiteNoiseService {
  static final WhiteNoiseService _instance = WhiteNoiseService._();
  factory WhiteNoiseService() => _instance;
  WhiteNoiseService._() {
    _player.setReleaseMode(ReleaseMode.loop);
  }

  final AudioPlayer _player = AudioPlayer();

  /// 当前白噪音：'rain' / 'wind' / 'stream' / null（已关闭）
  final ValueNotifier<String?> currentNoise = ValueNotifier<String?>(null);

  Timer? _fadeTimer;
  double _currentVolume = 1.0;

  static const Map<String, String> _assetMap = {
    'rain': 'audio/rain.mp3',
    'wind': 'audio/night_wind.mp3',
    'stream': 'audio/stream.mp3',
  };

  /// 切换白噪音：点同一个 → 淡出关闭；点另一个 → 切换并淡入
  Future<void> toggle(String key) async {
    _fadeTimer?.cancel();

    if (currentNoise.value == key) {
      currentNoise.value = null;
      _fadeTo(0.0, const Duration(seconds: 3), onDone: () {
        _player.stop();
        _currentVolume = 1.0;
      });
    } else {
      await _player.stop();
      _currentVolume = 0.0;
      await _player.setVolume(0.0);
      await _player.play(AssetSource(_assetMap[key]!));
      currentNoise.value = key;
      _fadeTo(1.0, const Duration(seconds: 3));
    }
  }

  /// 立即停止（无淡出），供需要强制静音的场景使用
  Future<void> stopImmediately() async {
    _fadeTimer?.cancel();
    _currentVolume = 1.0;
    currentNoise.value = null;
    await _player.stop();
  }

  double _easeInOut(double t) => t * t * (3 - 2 * t);

  void _fadeTo(double target, Duration duration, {VoidCallback? onDone}) {
    _fadeTimer?.cancel();
    final steps = (duration.inMilliseconds / 50).round();
    final startVolume = _currentVolume;
    final delta = target - startVolume;
    int step = 0;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      step++;
      if (step >= steps) {
        _currentVolume = target;
        _player.setVolume(target);
        timer.cancel();
        _fadeTimer = null;
        onDone?.call();
      } else {
        final progress = _easeInOut(step / steps);
        _currentVolume = startVolume + delta * progress;
        _player.setVolume(_currentVolume);
      }
    });
  }
}
