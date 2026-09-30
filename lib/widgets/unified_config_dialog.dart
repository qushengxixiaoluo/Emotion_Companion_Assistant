import 'package:flutter/material.dart';
import '../app/config/speech_config.dart';
import '../app/styles/app_styles.dart';
import '../app/themes/app_colors.dart';
import '../models/llm_profile.dart';
import '../services/llm_service.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';

Future<void> showUnifiedConfigDialog(BuildContext context, {bool isFirstLaunch = false}) async {
  final llmService = LlmService();
  final speechService = SpeechService();
  final storageService = StorageService();

  // LLM prefills
  final userLlmUrl = await storageService.getLlmBaseUrl();
  final userLlmKey = await storageService.getLlmApiKey();
  final userLlmModel = await storageService.getLlmModel();
  final userLlmFormat = await storageService.getLlmApiFormat();
  final hasLlmConfig = userLlmUrl != null && userLlmUrl.isNotEmpty
      && userLlmKey != null && userLlmKey.isNotEmpty;

  // TTS prefills
  final userTtsUrl = await storageService.getTtsBaseUrl();
  final userTtsKey = await storageService.getTtsApiKey();
  final userTtsModel = await storageService.getTtsModel();
  final hasTtsConfig = userTtsUrl != null && userTtsUrl.isNotEmpty
      && userTtsKey != null && userTtsKey.isNotEmpty;

  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: !isFirstLaunch,
    builder: (ctx) => _UnifiedConfigDialog(
      llmService: llmService,
      speechService: speechService,
      storageService: storageService,
      initialLlmUrl: userLlmUrl ?? '',
      initialLlmKey: userLlmKey ?? '',
      initialLlmModel: userLlmModel ?? '',
      initialLlmApiFormat: userLlmFormat ?? 'openai',
      hasLlmConfig: hasLlmConfig,
      initialTtsUrl: userTtsUrl ?? '',
      initialTtsKey: userTtsKey ?? '',
      initialTtsModel: userTtsModel ?? '',
      hasTtsConfig: hasTtsConfig,
      isFirstLaunch: isFirstLaunch,
    ),
  );
}

class _UnifiedConfigDialog extends StatefulWidget {
  final LlmService llmService;
  final SpeechService speechService;
  final StorageService storageService;
  final String initialLlmUrl;
  final String initialLlmKey;
  final String initialLlmModel;
  final String initialLlmApiFormat;
  final bool hasLlmConfig;
  final String initialTtsUrl;
  final String initialTtsKey;
  final String initialTtsModel;
  final bool hasTtsConfig;
  final bool isFirstLaunch;

  const _UnifiedConfigDialog({
    required this.llmService,
    required this.speechService,
    required this.storageService,
    required this.initialLlmUrl,
    required this.initialLlmKey,
    required this.initialLlmModel,
    required this.initialLlmApiFormat,
    required this.hasLlmConfig,
    required this.initialTtsUrl,
    required this.initialTtsKey,
    required this.initialTtsModel,
    required this.hasTtsConfig,
    this.isFirstLaunch = false,
  });

  @override
  State<_UnifiedConfigDialog> createState() => _UnifiedConfigDialogState();
}

class _UnifiedConfigDialogState extends State<_UnifiedConfigDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // LLM state
  late final TextEditingController _llmUrlCtrl;
  late final TextEditingController _llmKeyCtrl;
  late final TextEditingController _llmModelCtrl;
  // API 格式：'openai'（OpenAI 兼容）| 'anthropic'（Anthropic 原生）
  late String _llmApiFormat;
  bool _llmObscureKey = true;
  bool _llmTesting = false;
  bool _llmTestPassed = false;
  String? _llmError;

  // TTS state
  late final TextEditingController _ttsUrlCtrl;
  late final TextEditingController _ttsKeyCtrl;
  late final TextEditingController _ttsModelCtrl;
  bool _ttsObscureKey = true;
  bool _ttsTesting = false;
  bool _ttsTestPassed = false;
  String? _ttsError;
  String _ttsProvider = SpeechConfig.providerSystem;
  List<Map<String, String>> _systemVoices = [];
  String? _selectedSystemVoice;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _llmUrlCtrl = TextEditingController(text: widget.initialLlmUrl);
    _llmKeyCtrl = TextEditingController(text: widget.initialLlmKey);
    _llmModelCtrl = TextEditingController(text: widget.initialLlmModel);
    _llmApiFormat = widget.initialLlmApiFormat;
    _llmTestPassed = widget.hasLlmConfig;

    _ttsUrlCtrl = TextEditingController(text: widget.initialTtsUrl);
    _ttsKeyCtrl = TextEditingController(text: widget.initialTtsKey);
    _ttsModelCtrl = TextEditingController(text: widget.initialTtsModel);
    _ttsTestPassed = widget.hasTtsConfig;
    _loadTtsProvider();
  }

  Future<void> _loadTtsProvider() async {
    final provider = await widget.storageService.getTtsProvider();
    final savedVoice = await widget.storageService.getTtsVoiceType();
    final voices = widget.speechService.systemVoices;
    if (mounted) {
      setState(() {
        _ttsProvider = provider;
        _systemVoices = voices;
        _selectedSystemVoice = savedVoice;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _llmUrlCtrl.dispose();
    _llmKeyCtrl.dispose();
    _llmModelCtrl.dispose();
    _ttsUrlCtrl.dispose();
    _ttsKeyCtrl.dispose();
    _ttsModelCtrl.dispose();
    super.dispose();
  }

  bool get _llmAllEmpty =>
      _llmUrlCtrl.text.trim().isEmpty &&
      _llmKeyCtrl.text.trim().isEmpty &&
      _llmModelCtrl.text.trim().isEmpty;

  bool get _ttsAllEmpty =>
      _ttsUrlCtrl.text.trim().isEmpty &&
      _ttsKeyCtrl.text.trim().isEmpty &&
      _ttsModelCtrl.text.trim().isEmpty;

  bool get _canSaveLlm => _llmAllEmpty || _llmTestPassed;
  bool get _canSaveTts => _ttsAllEmpty || _ttsTestPassed;

  @override
  Widget build(BuildContext context) {
    final dialog = AlertDialog(
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.dialog)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.hazeBlue, AppColors.gentlePurple],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('API 配置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      Text(
                        '大模型 & 语音合成',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.isFirstLaunch) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.softOrange.withValues(alpha: 0.08),
                  borderRadius: AppRadius.smB,
                  border: AppStroke.all(context),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.onSurface),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '请先配置大模型和语音合成服务，或选择跳过。未配置时相关功能将不可用，之后可在「我的 → API 配置」中随时设置。',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Tab bar
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.textHint.withValues(alpha: 0.05),
                borderRadius: AppRadius.smB,
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppRadius.smB,
                  boxShadow: AppShadow.hard(context, dy: 2, alpha: 0.20),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                labelColor: Theme.of(context).colorScheme.onSurface,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                padding: const EdgeInsets.all(3),
                tabs: const [
                  Tab(text: '大模型'),
                  Tab(text: '语音合成'),
                ],
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 420,
        height: 440,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildLlmTab(),
            _buildTtsTab(),
          ],
        ),
      ),
    );

    if (widget.isFirstLaunch) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (!didPop) {
            await _markBothSubmitted();
            await widget.llmService.reloadConfig();
            await widget.speechService.reloadTtsConfig();
            if (mounted) Navigator.of(context).pop();
          }
        },
        child: dialog,
      );
    }
    return dialog;
  }

  // ============================================================
  // LLM Tab
  // ============================================================
  Widget _buildLlmTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('API 格式'),
          const SizedBox(height: 6),
          _buildApiFormatSelector(),
          const SizedBox(height: 14),
          _buildFieldLabel('API 地址'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _llmUrlCtrl,
            hintText: _llmApiFormat == 'anthropic'
                ? 'https://api.anthropic.com'
                : 'https://api.openai.com/v1',
            enabled: !_llmTesting,
            onChanged: (_) => _resetLlmTest(),
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('API Key'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _llmKeyCtrl,
            hintText: '请输入你的 API Key',
            obscureText: _llmObscureKey,
            enabled: !_llmTesting,
            onChanged: (_) => _resetLlmTest(),
            suffixIcon: IconButton(
              icon: Icon(
                _llmObscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: _llmTesting ? null : () => setState(() => _llmObscureKey = !_llmObscureKey),
            ),
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('模型名称'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _llmModelCtrl,
            hintText: _llmApiFormat == 'anthropic'
                ? 'claude-sonnet-4-5'
                : 'deepseek-chat / gpt-4o',
            enabled: !_llmTesting,
            onChanged: (_) => _resetLlmTest(),
          ),

          if (_llmError != null) ...[
            const SizedBox(height: 12),
            _buildErrorBanner(_llmError!),
          ] else if (widget.hasLlmConfig && !_llmTestPassed) ...[
            const SizedBox(height: 12),
            _buildHintBanner(),
          ],

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _buildActionRow(
            isTesting: _llmTesting,
            testPassed: _llmTestPassed,
            hasConfig: widget.hasLlmConfig,
            canSave: _canSaveLlm,
            testColor: AppColors.calmGreen,
            saveColor: AppColors.hazeBlue,
            onTest: _testLlm,
            onSave: _saveLlm,
            onReset: _resetLlmToDefault,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TTS Tab
  // ============================================================
  Widget _buildTtsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 提供者选择
          _buildFieldLabel('语音引擎'),
          const SizedBox(height: 8),
          _buildProviderSelector(),
          const SizedBox(height: 16),

          if (_ttsProvider == SpeechConfig.providerSystem)
            _buildSystemTtsSection()
          else
            _buildApiTtsSection(),
        ],
      ),
    );
  }

  Widget _buildProviderSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.textHint.withValues(alpha: 0.05),
        borderRadius: AppRadius.smB,
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _ttsProvider = SpeechConfig.providerSystem),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _ttsProvider == SpeechConfig.providerSystem
                      ? Theme.of(context).colorScheme.surface
                      : Colors.transparent,
                  borderRadius: AppRadius.smB,
                  boxShadow: _ttsProvider == SpeechConfig.providerSystem
                      ? AppShadow.hard(context, dy: 2, alpha: 0.20)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone_android, size: 14, color: _ttsProvider == SpeechConfig.providerSystem ? AppColors.calmGreen : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 6),
                    Text(
                      '系统默认',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _ttsProvider == SpeechConfig.providerSystem ? FontWeight.w600 : FontWeight.normal,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _ttsProvider = SpeechConfig.providerApi),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _ttsProvider == SpeechConfig.providerApi
                      ? Theme.of(context).colorScheme.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _ttsProvider == SpeechConfig.providerApi
                      ? AppShadow.hard(context, dy: 2, alpha: 0.20)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_outlined, size: 14, color: _ttsProvider == SpeechConfig.providerApi ? AppColors.gentlePurple : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 6),
                    Text(
                      '自定义 API',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _ttsProvider == SpeechConfig.providerApi ? FontWeight.w600 : FontWeight.normal,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemTtsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.calmGreen.withValues(alpha: 0.06),
            borderRadius: AppRadius.smB,
            border: AppStroke.all(context),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, size: 18, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '使用设备系统语音引擎，无需额外配置',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text('系统语音选择', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            TextButton.icon(
              onPressed: () async {
                await widget.speechService.refreshVoices();
                if (mounted) setState(() => _systemVoices = widget.speechService.systemVoices);
              },
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('刷新', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_systemVoices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '未检测到系统语音，点击「刷新」重试\n（Android 需安装语音引擎数据，设置 → 语言和输入 → 文字转语音）',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface, height: 1.5),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.smB,
              border: AppStroke.all(context),
            ),
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(4),
              itemCount: _systemVoices.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final voice = _systemVoices[index];
                final name = voice['name'] ?? '';
                final locale = voice['locale'] ?? '';
                final voiceId = '$name|$locale';
                final isSelected = _selectedSystemVoice == voiceId;
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor: AppColors.calmGreen.withValues(alpha: 0.06),
                  title: Text(name, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                  subtitle: locale.isNotEmpty ? Text(locale, style: const TextStyle(fontSize: 11)) : null,
                  trailing: isSelected ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.onSurface) : null,
                  onTap: () => setState(() => _selectedSystemVoice = voiceId),
                );
              },
            ),
          ),
        const SizedBox(height: 18),
        const Divider(height: 1),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (widget.isFirstLaunch)
              TextButton(
                onPressed: _skipTtsSystem,
                child: const Text('跳过', style: TextStyle(fontSize: 12)),
              )
            else
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭', style: TextStyle(fontSize: 12)),
              ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saveTtsSystem,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.calmGreen,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
              ),
              child: const Text('保存', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildApiTtsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('API 地址'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _ttsUrlCtrl,
          hintText: 'https://openspeech.bytedance.com/api/v1/tts',
          enabled: !_ttsTesting,
          onChanged: (_) => _resetTtsTest(),
        ),
        const SizedBox(height: 14),
        _buildFieldLabel('API Key / Token'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _ttsKeyCtrl,
          hintText: '请输入你的 Access Token',
          obscureText: _ttsObscureKey,
          enabled: !_ttsTesting,
          onChanged: (_) => _resetTtsTest(),
          suffixIcon: IconButton(
            icon: Icon(
              _ttsObscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: _ttsTesting ? null : () => setState(() => _ttsObscureKey = !_ttsObscureKey),
          ),
        ),
        const SizedBox(height: 14),
        _buildFieldLabel('音色名称'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _ttsModelCtrl,
          hintText: 'zh_female_vv_uranus_bigtts',
          enabled: !_ttsTesting,
          onChanged: (_) => _resetTtsTest(),
        ),

        if (_ttsError != null) ...[
          const SizedBox(height: 12),
          _buildErrorBanner(_ttsError!),
        ] else if (widget.hasTtsConfig && !_ttsTestPassed) ...[
          const SizedBox(height: 12),
          _buildHintBanner(),
        ],

        const SizedBox(height: 18),
        const Divider(height: 1),
        const SizedBox(height: 14),
        _buildActionRow(
          isTesting: _ttsTesting,
          testPassed: _ttsTestPassed,
          hasConfig: widget.hasTtsConfig,
          canSave: _canSaveTts,
          testColor: AppColors.calmGreen,
          saveColor: AppColors.gentlePurple,
          onTest: _testTts,
          onSave: _saveTtsApi,
          onReset: _skipTtsApi,
        ),
      ],
    );
  }

  // ============================================================
  // Shared Widgets
  // ============================================================

  Widget _buildFieldLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
  }

  /// API 格式二选一：OpenAI 兼容 / Anthropic 原生。
  /// 选中态用统一 2px 描边（AppStroke.all），文字一律 onSurface。
  Widget _buildApiFormatSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.textHint.withValues(alpha: 0.05),
        borderRadius: AppRadius.smB,
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(child: _buildFormatOption('openai', 'OpenAI 兼容')),
          Expanded(child: _buildFormatOption('anthropic', 'Anthropic 原生')),
        ],
      ),
    );
  }

  Widget _buildFormatOption(String value, String label) {
    final selected = _llmApiFormat == value;
    return GestureDetector(
      onTap: _llmTesting
          ? null
          : () {
              setState(() {
                _llmApiFormat = value;
                _llmTestPassed = false;
                _llmError = null;
              });
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.surface
              : Colors.transparent,
          borderRadius: AppRadius.smB,
          border: selected ? AppStroke.all(context) : null,
          boxShadow: selected
              ? AppShadow.hard(context, dy: 2, alpha: 0.20)
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    bool enabled = true,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
        isDense: true,
        filled: true,
        fillColor: enabled ? null : AppColors.textLight.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        // 继承主题：2px ink 描边 / focused hazeBlue
        suffixIcon: suffixIcon,
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.softPink.withValues(alpha: 0.08),
        borderRadius: AppRadius.smB,
        border: AppStroke.all(context),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface))),
        ],
      ),
    );
  }

  Widget _buildHintBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.softOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '修改配置后需重新测试连接通过才能保存',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required bool isTesting,
    required bool testPassed,
    required bool hasConfig,
    required bool canSave,
    required Color testColor,
    required Color saveColor,
    required VoidCallback onTest,
    required VoidCallback onSave,
    required VoidCallback onReset,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isTesting ? null : onTest,
                icon: Icon(
                  isTesting ? Icons.hourglass_top : Icons.wifi_find,
                  size: 16,
                  color: isTesting ? Theme.of(context).disabledColor : testColor,
                ),
                label: Text(
                  '测试连接',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: testColor.withValues(alpha: isTesting ? 0.15 : 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: (isTesting || !canSave) ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: saveColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: const Text('保存', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (widget.isFirstLaunch)
              TextButton(
                onPressed: isTesting ? null : onReset,
                child: const Text('跳过', style: TextStyle(fontSize: 12)),
              )
            else ...[
              TextButton(
                onPressed: (isTesting || !hasConfig) ? null : onReset,
                child: const Text('恢复默认', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: isTesting ? null : () => Navigator.pop(context),
                child: const Text('关闭', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ============================================================
  // LLM Actions
  // ============================================================

  void _resetLlmTest() => setState(() { _llmTestPassed = false; _llmError = null; });

  void _testLlm() async {
    final url = _llmUrlCtrl.text.trim();
    final key = _llmKeyCtrl.text.trim();
    final model = _llmModelCtrl.text.trim();

    if (url.isEmpty || key.isEmpty || model.isEmpty) {
      setState(() => _llmError = '请先填写 API 地址、Key 和模型名称');
      return;
    }

    setState(() { _llmTesting = true; _llmError = null; });

    _showTestingOverlay();

    final (success, message) = await widget.llmService.testConnection(
      baseUrl: url, apiKey: key, model: model, apiFormat: _llmApiFormat,
    );

    setState(() {
      _llmTesting = false;
      if (success) { _llmTestPassed = true; _llmError = null; }
    });

    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) _showTestResult(success, message);
  }

  void _saveLlm() async {
    final url = _llmUrlCtrl.text.trim();
    final key = _llmKeyCtrl.text.trim();
    final model = _llmModelCtrl.text.trim();
    await widget.storageService.setLlmBaseUrl(url);
    await widget.storageService.setLlmApiKey(key);
    await widget.storageService.setLlmModel(model);
    await widget.storageService.setLlmApiFormat(_llmApiFormat);
    await widget.storageService.setLlmConfigSubmitted(true);
    await widget.llmService.reloadConfig();
    // 同步写入配置档案（多套档案存储）
    await _syncLlmProfile(baseUrl: url, apiKey: key, model: model, apiFormat: _llmApiFormat);
    if (widget.isFirstLaunch) {
      await widget.storageService.setTtsConfigSubmitted(true);
      await widget.speechService.reloadTtsConfig();
      if (mounted) Navigator.of(context).pop();
    } else if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('大模型配置已保存'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 保存 LLM 配置时同步入档：
  /// - 不存在与当前 baseUrl+model+apiFormat 匹配的档案 → 新建一套（name 取模型名）并设为 active；
  /// - 已存在匹配的 → 直接 setActive 到它（apiKey/apiFormat 若有变化则顺带更新该档案）。
  Future<void> _syncLlmProfile({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String apiFormat,
  }) async {
    if (baseUrl.isEmpty || model.isEmpty) return; // 清空配置时不入档

    final profiles = await widget.storageService.getLlmProfiles();
    LlmProfile? matched;
    for (final p in profiles) {
      if (p.baseUrl == baseUrl && p.model == model && p.apiFormat == apiFormat) {
        matched = p;
        break;
      }
    }

    if (matched == null) {
      matched = LlmProfile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: model.isNotEmpty ? model : '当前配置',
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
        apiFormat: apiFormat,
      );
      await widget.storageService.upsertLlmProfile(matched);
    } else if (matched.apiKey != apiKey) {
      matched.apiKey = apiKey;
      await widget.storageService.upsertLlmProfile(matched);
    }

    await widget.storageService.setActiveLlmProfileId(matched.id);
  }

  void _resetLlmToDefault() async {
    if (widget.isFirstLaunch) {
      // 跳过 LLM：标记为已提交，转到 TTS 标签页
      await widget.storageService.setLlmConfigSubmitted(true);
      await widget.llmService.reloadConfig();
      _tabController.animateTo(1);
      return;
    }
    await widget.storageService.clearLlmConfig();
    await widget.llmService.reloadConfig();
    setState(() {
      _llmUrlCtrl.clear();
      _llmKeyCtrl.clear();
      _llmModelCtrl.clear();
      _llmApiFormat = 'openai';
      _llmTestPassed = true;
      _llmError = null;
    });
  }

  // ============================================================
  // TTS Actions
  // ============================================================

  void _resetTtsTest() => setState(() { _ttsTestPassed = false; _ttsError = null; });

  void _testTts() async {
    final url = _ttsUrlCtrl.text.trim();
    final key = _ttsKeyCtrl.text.trim();
    final model = _ttsModelCtrl.text.trim();

    if (url.isEmpty || key.isEmpty || model.isEmpty) {
      setState(() => _ttsError = '请先填写 API 地址、Key 和音色名称');
      return;
    }

    setState(() { _ttsTesting = true; _ttsError = null; });

    _showTestingOverlay();

    final (success, message) = await widget.speechService.testApiConnection(
      baseUrl: url, apiKey: key, model: model,
    );

    setState(() {
      _ttsTesting = false;
      if (success) { _ttsTestPassed = true; _ttsError = null; }
    });

    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) _showTestResult(success, message);
  }

  // --- 首次启动时标记双方已提交 ---
  Future<void> _markBothSubmitted() async {
    await widget.storageService.setLlmConfigSubmitted(true);
    await widget.storageService.setTtsConfigSubmitted(true);
  }

  // --- 系统 TTS 保存/跳过 ---

  void _saveTtsSystem() async {
    await widget.storageService.setTtsProvider(_ttsProvider);
    if (_selectedSystemVoice != null) {
      final voiceName = _selectedSystemVoice!.contains('|')
          ? _selectedSystemVoice!.split('|').first
          : _selectedSystemVoice!;
      await widget.speechService.setSystemVoice(voiceName);
    }
    await _markBothSubmitted();
    await widget.speechService.reloadTtsConfig();
    await widget.llmService.reloadConfig();
    if (widget.isFirstLaunch) {
      if (mounted) Navigator.of(context).pop();
    } else if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('语音配置已保存'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _skipTtsSystem() async {
    await widget.storageService.setTtsProvider(_ttsProvider);
    await _markBothSubmitted();
    await widget.speechService.reloadTtsConfig();
    await widget.llmService.reloadConfig();
    if (mounted) Navigator.of(context).pop();
  }

  // --- API TTS 保存/跳过 ---

  void _saveTtsApi() async {
    await widget.storageService.setTtsProvider(_ttsProvider);
    await widget.storageService.setTtsBaseUrl(_ttsUrlCtrl.text.trim());
    await widget.storageService.setTtsApiKey(_ttsKeyCtrl.text.trim());
    await widget.storageService.setTtsModel(_ttsModelCtrl.text.trim());
    await _markBothSubmitted();
    await widget.speechService.reloadTtsConfig();
    await widget.llmService.reloadConfig();
    if (widget.isFirstLaunch) {
      if (mounted) Navigator.of(context).pop();
    } else if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('语音配置已保存'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _skipTtsApi() async {
    if (widget.isFirstLaunch) {
      await widget.storageService.setTtsProvider(SpeechConfig.providerSystem);
      await _markBothSubmitted();
      await widget.speechService.reloadTtsConfig();
      await widget.llmService.reloadConfig();
      setState(() => _ttsProvider = SpeechConfig.providerSystem);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await widget.storageService.clearTtsConfig();
    await widget.storageService.setTtsProvider(SpeechConfig.providerSystem);
    await widget.speechService.reloadTtsConfig();
    setState(() {
      _ttsProvider = SpeechConfig.providerSystem;
      _ttsUrlCtrl.clear();
      _ttsKeyCtrl.clear();
      _ttsModelCtrl.clear();
      _ttsTestPassed = true;
      _ttsError = null;
    });
  }

  // ============================================================
  // Helpers
  // ============================================================

  void _showTestingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.hazeBlue),
              ),
              const SizedBox(width: 16),
              const Text('正在测试连接...', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  void _showTestResult(bool success, String message) {
    showDialog(
      context: context,
      builder: (resultCtx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (success ? AppColors.calmGreen : AppColors.softPink).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: success ? AppColors.calmGreen : AppColors.softPink,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              success ? '测试通过' : '测试失败',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(resultCtx),
            child: Text(
              '关闭',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
