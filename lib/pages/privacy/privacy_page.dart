import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/themes/app_colors.dart';
import '../../app/responsive/adaptive_content_wrapper.dart';
import '../../app/app_controller.dart';
import '../../services/storage_service.dart';
import '../../widgets/unified_config_dialog.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => PrivacyPageState();
}

class PrivacyPageState extends State<PrivacyPage> {
  final StorageService _storageService = StorageService();
  final AppController _appController = Get.find<AppController>();
  bool _isLocked = false;
  bool _darkMode = false;

  // PIN 校验失败限制：连续 5 次错误后禁用输入 30 秒（页面内状态，无需持久化）
  static const int _pinMaxFails = 5;
  static const int _pinLockSeconds = 30;
  int _pinFailCount = 0;
  DateTime? _pinLockUntil;
  Timer? _pinLockTimer;
  // 当前打开的 PIN 校验弹窗的刷新器，用于实时刷新倒计时
  void Function(VoidCallback)? _pinDialogUpdater;

  bool get _isPinLockedOut =>
      _pinLockUntil != null && DateTime.now().isBefore(_pinLockUntil!);

  int get _pinLockRemaining {
    if (_pinLockUntil == null) return 0;
    final s = _pinLockUntil!.difference(DateTime.now()).inSeconds;
    return s < 1 ? 1 : s;
  }

  void _beginPinLockout() {
    _pinLockUntil = DateTime.now().add(const Duration(seconds: _pinLockSeconds));
    _pinLockTimer?.cancel();
    _pinLockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        _pinLockTimer = null;
        return;
      }
      if (!_isPinLockedOut) {
        timer.cancel();
        _pinLockTimer = null;
        _pinLockUntil = null;
        _pinFailCount = 0;
      }
      // 刷新弹窗倒计时（弹窗关闭后 updater 已置空）
      try {
        _pinDialogUpdater?.call(() {});
      } catch (_) {}
      setState(() {});
    });
  }

  void _resetPinFailures() {
    _pinFailCount = 0;
    _pinLockUntil = null;
    _pinLockTimer?.cancel();
    _pinLockTimer = null;
  }

  String get _pinLockErrorText =>
      '连续$_pinMaxFails次错误，请${_pinLockRemaining}秒后再试';

  @override
  void dispose() {
    _pinLockTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final locked = await _storageService.isLocked();
    setState(() {
      _isLocked = locked;
      _darkMode = _appController.isDarkMode.value;
    });
  }

  /// 外部可调用的刷新方法，用于跨页面同步
  Future<void> refreshData() async {
    await _loadState();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? [AppColors.gentlePurple.withValues(alpha: 0.15), AppColors.darkBackground]
        : [AppColors.gentlePurple.withValues(alpha: 0.06), AppColors.background];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '隐私中心',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.hazeBlue,
                fontWeight: FontWeight.w600,
              ),
        ),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: AdaptiveContentWrapper(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 12, bottom: 32),
          child: Column(
            children: [
              _buildSecurityStatusCard(),
              const SizedBox(height: 16),
              _buildSettingsSection(),
              const SizedBox(height: 16),
              _buildDangerZoneSection(),
              const SizedBox(height: 16),
              _buildAdvancedSettingsSection(),
              const SizedBox(height: 16),
              _buildPrivacyPolicySection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
        ),
      ),
    );
  }

  // ===================== 1. 安全状态卡片 =====================

  Widget _buildSecurityStatusCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.gentlePurple.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.gentlePurple.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            // 安全图标外圈装饰
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.calmGreen.withValues(alpha: 0.18),
                    AppColors.gentlePurple.withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.calmGreen.withValues(alpha: 0.15),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.calmGreen,
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '你的隐私已被保护',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.calmGreen,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '所有数据仅存储在本机，全程加密保护',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '~ ~ ~',
                style: TextStyle(
                  color: AppColors.gentlePurple.withValues(alpha: 0.20),
                  fontSize: 14,
                  letterSpacing: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== 2. 安全设置 =====================

  Widget _buildSettingsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.security,
            text: '安全设置',
            color: AppColors.gentlePurple,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.gentlePurple.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  icon: Icons.lock_outline,
                  title: '树洞锁定',
                  subtitle: '锁定后需要密码才能访问树洞',
                  value: _isLocked,
                  iconColor: AppColors.gentlePurple,
                  activeColor: AppColors.gentlePurple,
                  onChanged: (val) async {
                    if (val) {
                      await _handleEnableLock();
                    } else {
                      final unlocked = await _handleDisableLock();
                      if (unlocked) {
                        await _storageService.setLocked(false);
                        setState(() => _isLocked = false);
                      }
                    }
                  },
                ),
                Divider(
                  height: 1,
                  indent: 64,
                  endIndent: 20,
                  color: AppColors.gentlePurple.withValues(alpha: 0.10),
                ),
                _buildSwitchTile(
                  icon: Icons.dark_mode_outlined,
                  title: '夜间护眼模式',
                  subtitle: '降低屏幕亮度，保护眼睛',
                  value: _darkMode,
                  iconColor: AppColors.gentlePurple,
                  activeColor: AppColors.gentlePurple,
                  onChanged: (val) async {
                    setState(() => _darkMode = val);
                    _appController.toggleDarkMode(val);

                    final ok = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('温馨提示'),
                        content: const Text('桌面图标已更换，点击确定退出应用后生效。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('确定', style: TextStyle(color: AppColors.hazeBlue)),
                          ),
                        ],
                      ),
                    );

                    if (ok == true) {
                      _appController.switchIconAndExit(val);
                    } else {
                      setState(() => _darkMode = !val);
                      _appController.toggleDarkMode(!val);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== 3. 危险操作 =====================

  Widget _buildDangerZoneSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.warning_amber_rounded,
            text: '危险操作',
            color: AppColors.angerRed,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.angerRed.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.delete_outline,
                  title: '一键清空所有记录',
                  subtitle: '清空情绪日记、对话、梦境等全部数据，不可恢复',
                  color: AppColors.angerRed,
                  onTap: _confirmClearAll,
                ),
                Divider(
                  height: 1,
                  indent: 64,
                  endIndent: 20,
                  color: AppColors.angerRed.withValues(alpha: 0.10),
                ),
                _buildActionTile(
                  icon: Icons.lock_reset_outlined,
                  title: '修改树洞密码',
                  subtitle: '设置新的访问密码',
                  color: AppColors.softOrange,
                  onTap: _showSetPinDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== 4. 高级设置 =====================

  Widget _buildAdvancedSettingsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.tune,
            text: '高级设置',
            color: AppColors.hazeBlue,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.hazeBlue.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.api,
                  title: 'API 配置',
                  subtitle: '大模型 & 语音合成 API 设置',
                  color: AppColors.hazeBlue,
                  onTap: () => showUnifiedConfigDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== 5. 隐私政策 =====================

  Widget _buildPrivacyPolicySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.description_outlined,
            text: '隐私政策',
            color: AppColors.calmGreen,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.calmGreen.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
            child: Column(
              children: [
                _buildPolicyItem('零用户敏感信息采集'),
                _buildPolicyItem('无需实名认证、无需读取通讯录'),
                _buildPolicyItem('无需读取相册、无需位置权限'),
                _buildPolicyItem('所有倾诉内容本地加密存储'),
                _buildPolicyItem('所有历史数据永久保留'),
                _buildPolicyItem('无后台数据售卖、无第三方信息共享'),
                _buildPolicyItem('符合个人隐私保护法律法规'),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '~ ~ ~',
                    style: TextStyle(
                      color: AppColors.calmGreen.withValues(alpha: 0.20),
                      fontSize: 14,
                      letterSpacing: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== 通用组件 =====================

  /// 区域标题: 左侧强调条 + 图标 + 文字
  Widget _buildSectionTitle({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color iconColor,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: activeColor,
      activeTrackColor: activeColor.withValues(alpha: 0.30),
      inactiveThumbColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
      inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
        size: 18,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onTap: onTap,
    );
  }

  Widget _buildPolicyItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.calmGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppColors.calmGreen,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== 以下为业务逻辑方法（保持不变） =====================

  /// 开启锁定时，如果没有密码则先要求设置
  Future<void> _handleEnableLock() async {
    final hasPin = await _storageService.hasPin();
    if (!hasPin) {
      final set = await _showCreatePinDialog(title: '首次锁定树洞', hint: '请设置4-6位数字密码');
      if (set == true) {
        await _storageService.setLocked(true);
        setState(() => _isLocked = true);
        if (mounted) {
          await _showRecoveryQASetupDialog();
        }
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('锁定树洞'),
          content: const Text('锁定后需要输入密码才能访问，是否确认？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('确认锁定', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await _storageService.setLocked(true);
        setState(() => _isLocked = true);
      }
    }
  }

  /// 关闭锁定时，需要验证密码
  Future<bool> _handleDisableLock() async {
    // 兜底：根本没有 PIN（异常态）时无密码可验，直接允许关闭锁定，避免死锁
    final hasPin = await _storageService.hasPin();
    if (!hasPin) return true;

    final controller = TextEditingController();
    String? errorText = _isPinLockedOut ? _pinLockErrorText : null;

    final verified = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 注册弹窗刷新器，锁屏倒计时可实时刷新本弹窗
          _pinDialogUpdater = setDialogState;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('解锁树洞'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !_isPinLockedOut,
                  decoration: InputDecoration(
                    hintText: _isPinLockedOut ? '请稍后再试' : '请输入解锁密码',
                    errorText: errorText,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // 先关闭当前弹窗
                      _showForgotPasswordDialogForDisable();
                    },
                    child: Text(
                      '忘记密码？',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.hazeBlue.withValues(alpha: 0.7),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              TextButton(
                onPressed: _isPinLockedOut
                    ? null
                    : () async {
                        final ok = await _storageService.verifyPin(controller.text);
                        if (ok) {
                          _resetPinFailures();
                          if (dialogContext.mounted) Navigator.pop(context, true);
                        } else {
                          _pinFailCount += 1;
                          if (_pinFailCount >= _pinMaxFails) {
                            _beginPinLockout();
                          }
                          setDialogState(() {
                            errorText = _isPinLockedOut
                                ? _pinLockErrorText
                                : '密码错误，还可尝试${_pinMaxFails - _pinFailCount}次';
                          });
                        }
                      },
                child: Text('解锁', style: TextStyle(color: AppColors.hazeBlue)),
              ),
            ],
          );
        },
      ),
    );
    _pinDialogUpdater = null;
    return verified ?? false;
  }

  /// 忘记密码流程（用于关闭锁定时）
  Future<void> _showForgotPasswordDialogForDisable() async {
    final hasQA = await _storageService.hasRecoveryQA();
    if (!hasQA) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('无法找回'),
            content: const Text('尚未设置密保问题，无法通过此方式找回密码。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('知道了', style: TextStyle(color: AppColors.hazeBlue)),
              ),
            ],
          ),
        );
      }
      return;
    }

    final question = await _storageService.getRecoveryQuestion();
    final answerController = TextEditingController();
    String? errorText;

    if (!mounted) return;
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.help_outline, color: AppColors.softOrange, size: 24),
              const SizedBox(width: 8),
              const Text('找回密码'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('请回答以下密保问题：', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  question ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: answerController,
                decoration: InputDecoration(
                  hintText: '请输入答案',
                  errorText: errorText,
                ),
                maxLength: 30,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final ok = await _storageService.verifyRecoveryAnswer(answerController.text.trim());
                if (ok) {
                  Navigator.pop(context, true);
                } else {
                  setDialogState(() => errorText = '答案错误，请重试');
                }
              },
              child: Text('验证', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      ),
    );

    if (verified == true && mounted) {
      // 不清空旧 PIN：_showCreatePinDialog 成功时才 setPin 覆盖。
      // 用户中途取消 → 旧 PIN 与锁定状态原样保留，不会出现"锁还在但任意密码可解"的漏洞。
      final set = await _showCreatePinDialog(title: '重置密码', hint: '请设置新的4-6位数字密码');
      if (set == true && mounted) {
        _showRecoveryQASetupDialog();
        _resetPinFailures();
        await _storageService.setLocked(false);
        setState(() => _isLocked = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('密码已重置，锁定已解除'),
            backgroundColor: AppColors.calmGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认清空'),
        content: const Text(
          '此操作将永久删除以下本机数据，且不可恢复：\n'
          '· 情绪日记\n'
          '· 对话记录\n'
          '· 梦境记录\n'
          '· 对话摘要与用户画像\n\n'
          'API 配置、树洞锁定与密码设置不会被删除。\n\n'
          '确定要继续吗？',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await _storageService.clearAllRecords();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('已清空情绪日记、对话、梦境等全部数据'),
                  backgroundColor: AppColors.calmGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: Text('确认清空', style: TextStyle(color: AppColors.angerRed)),
          ),
        ],
      ),
    );
  }

  /// 修改密码入口：先判断是否有旧密码
  void _showSetPinDialog() async {
    final hasPin = await _storageService.hasPin();
    if (!hasPin) {
      final set = await _showCreatePinDialog(title: '设置树洞密码', hint: '请设置4-6位数字密码');
      if (set == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('密码设置成功'),
            backgroundColor: AppColors.calmGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        await _showRecoveryQASetupDialog();
      }
    } else {
      final verified = await _showVerifyOldPinDialog();
      if (verified == true) {
        final set = await _showCreatePinDialog(title: '修改树洞密码', hint: '请输入新的4-6位数字密码');
        if (set == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('密码修改成功'),
              backgroundColor: AppColors.calmGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          // 修改密码后强制更新密保
          if (mounted) await _showRecoveryQASetupDialog();
        }
      }
    }
  }

  /// 验证旧密码弹窗
  Future<bool?> _showVerifyOldPinDialog() async {
    final controller = TextEditingController();
    String? errorText = _isPinLockedOut ? _pinLockErrorText : null;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 注册弹窗刷新器，锁屏倒计时可实时刷新本弹窗
          _pinDialogUpdater = setDialogState;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('验证旧密码'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !_isPinLockedOut,
                  decoration: InputDecoration(
                    hintText: _isPinLockedOut ? '请稍后再试' : '请输入旧密码',
                    errorText: errorText,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // 关闭当前弹窗
                      _showForgotPasswordDialogForChangePin();
                    },
                    child: Text(
                      '忘记密码？',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.hazeBlue.withValues(alpha: 0.7),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              TextButton(
                onPressed: _isPinLockedOut
                    ? null
                    : () async {
                        final verified = await _storageService.verifyPin(controller.text);
                        if (verified) {
                          _resetPinFailures();
                          if (dialogContext.mounted) Navigator.pop(context, true);
                        } else {
                          _pinFailCount += 1;
                          if (_pinFailCount >= _pinMaxFails) {
                            _beginPinLockout();
                          }
                          setDialogState(() {
                            errorText = _isPinLockedOut
                                ? _pinLockErrorText
                                : '密码错误，还可尝试${_pinMaxFails - _pinFailCount}次';
                          });
                        }
                      },
                child: Text('确认', style: TextStyle(color: AppColors.hazeBlue)),
              ),
            ],
          );
        },
      ),
    );
    _pinDialogUpdater = null;
    return result;
  }

  /// 忘记密码流程（用于修改密码时）
  Future<void> _showForgotPasswordDialogForChangePin() async {
    final hasQA = await _storageService.hasRecoveryQA();
    if (!hasQA) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('无法找回'),
            content: const Text('尚未设置密保问题，无法通过此方式找回密码。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('知道了', style: TextStyle(color: AppColors.hazeBlue)),
              ),
            ],
          ),
        );
      }
      return;
    }

    final question = await _storageService.getRecoveryQuestion();
    final answerController = TextEditingController();
    String? errorText;

    if (!mounted) return;
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.help_outline, color: AppColors.softOrange, size: 24),
              const SizedBox(width: 8),
              const Text('找回密码'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('请回答以下密保问题：', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  question ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: answerController,
                decoration: InputDecoration(
                  hintText: '请输入答案',
                  errorText: errorText,
                ),
                maxLength: 30,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final ok = await _storageService.verifyRecoveryAnswer(answerController.text.trim());
                if (ok) {
                  Navigator.pop(context, true);
                } else {
                  setDialogState(() => errorText = '答案错误，请重试');
                }
              },
              child: Text('验证', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      ),
    );

    if (verified == true && mounted) {
      // 不清空旧 PIN：只有新建密码成功后 setPin 才会覆盖旧值；取消则什么都不动
      final set = await _showCreatePinDialog(title: '重置密码', hint: '请设置新的4-6位数字密码');
      if (set == true && mounted) {
        _showRecoveryQASetupDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('密码已重置'),
            backgroundColor: AppColors.calmGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 创建密码弹窗（两步验证：输入 → 确认）
  Future<bool?> _showCreatePinDialog({required String title, required String hint}) {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('请输入4-6位数字密码', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: hint,
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final pin = controller.text;
                if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
                  setDialogState(() => errorText = '请输入4-6位数字密码');
                  return;
                }
                final confirmed = await _showConfirmPinDialog(pin);
                if (confirmed == true) {
                  await _storageService.setPin(pin);
                  Navigator.pop(context, true);
                } else if (confirmed == false) {
                  setDialogState(() => errorText = '两次输入不一致，请重新输入');
                  controller.clear();
                }
              },
              child: Text('下一步', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      ),
    );
  }

  /// 确认密码弹窗（二次输入）
  Future<bool?> _showConfirmPinDialog(String firstPin) {
    final controller = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('请再次输入密码以确认', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: '请再次输入密码'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () {
              if (controller.text == firstPin) {
                Navigator.pop(context, true);
              } else {
                Navigator.pop(context, false);
              }
            },
            child: Text('确认', style: TextStyle(color: AppColors.hazeBlue)),
          ),
        ],
      ),
    );
  }

  /// 二级安保：设置密保问题与答案（强制设置）
  Future<void> _showRecoveryQASetupDialog() async {
    final questionController = TextEditingController();
    final answerController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.security, color: AppColors.softOrange, size: 24),
            const SizedBox(width: 8),
            const Text('二级安保设置'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '设置密保问题，忘记密码时可通过回答此问题找回',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: questionController,
              decoration: const InputDecoration(
                hintText: '请输入密保问题（如：我的小名是什么？）',
                labelText: '密保问题',
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: answerController,
              decoration: const InputDecoration(
                hintText: '请输入答案',
                labelText: '密保答案',
              ),
              maxLength: 30,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final q = questionController.text.trim();
              final a = answerController.text.trim();
              if (q.isEmpty || a.isEmpty) return;
              await _storageService.setRecoveryQA(q, a);
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('密保已设置，忘记密码时可通过密保找回'),
                    backgroundColor: AppColors.calmGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text('确认设置', style: TextStyle(color: AppColors.hazeBlue)),
          ),
        ],
      ),
    );
  }
}
