import 'package:flutter/material.dart';
import '../app/styles/app_styles.dart';
import '../app/themes/app_colors.dart';
import '../models/llm_profile.dart';
import '../services/llm_service.dart';
import '../services/storage_service.dart';

/// 「模型配置」管理界面：多套大模型配置档案的新增 / 编辑 / 删除 / 随时切换。
///
/// AlertDialog + StatefulBuilder 实现，不引入新的页面路由。
/// 切换/应用档案时通过 legacy 三键写回 + `LlmService.reloadConfig()`，
/// 使现有读取方零改动即生效。
Future<void> showLlmProfileManagerDialog(BuildContext context) async {
  final storage = StorageService();
  final llmService = LlmService();

  Future<({List<LlmProfile> profiles, String? activeId})> loadAll() async {
    final profiles = await storage.getLlmProfiles(); // 内含惰性迁移
    final activeId = await storage.getActiveLlmProfileId();
    return (profiles: profiles, activeId: activeId);
  }

  var dataFuture = loadAll();

  await showDialog<void>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (dialogCtx, set) {
        void refresh() => set(() => dataFuture = loadAll());

        void snack(String message, {Color background = AppColors.calmGreen}) {
          if (!dialogCtx.mounted) return;
          ScaffoldMessenger.of(dialogCtx).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: background,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // ---- 切换：setActive + apply 写回 legacy 三键 + reload ----
        Future<void> switchTo(LlmProfile p) async {
          await storage.setActiveLlmProfileId(p.id);
          await storage.applyLlmProfile(p);
          await llmService.reloadConfig();
          if (!dialogCtx.mounted) return;
          refresh();
          snack('已切换到 ${p.name}');
        }

        // ---- 删除 ----
        Future<void> deleteProfile(LlmProfile p) async {
          final list = await storage.getLlmProfiles();
          if (list.length <= 1) {
            snack('至少保留一套配置', background: AppColors.softOrange);
            return;
          }
          final active = await storage.getActiveLlmProfileId();
          final remaining = list.where((e) => e.id != p.id).toList();
          await storage.saveLlmProfiles(remaining);
          if (active == p.id) {
            // 删除的是当前生效档案：自动切换到剩余第一条
            final next = remaining.first;
            await storage.setActiveLlmProfileId(next.id);
            await storage.applyLlmProfile(next);
            await llmService.reloadConfig();
          }
          if (!dialogCtx.mounted) return;
          refresh();
          snack('已删除 ${p.name}');
        }

        // ---- 新增 ----
        Future<void> openAddForm() async {
          final existing = await storage.getLlmProfiles();
          var n = existing.length + 1;
          final names = existing.map((e) => e.name).toSet();
          while (names.contains('配置$n')) {
            n++;
          }
          final seed = LlmProfile(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: '配置$n',
            baseUrl: '',
            apiKey: '',
            model: '',
          );
          final saved = await _showProfileFormDialog(
            dialogCtx,
            initial: seed,
            isEdit: false,
          );
          if (saved == null || !dialogCtx.mounted) return;
          await storage.upsertLlmProfile(saved);
          await storage.setActiveLlmProfileId(saved.id);
          await storage.applyLlmProfile(saved);
          await llmService.reloadConfig();
          if (!dialogCtx.mounted) return;
          refresh();
          snack('已新增并切换到 ${saved.name}');
        }

        // ---- 编辑 ----
        Future<void> openEditForm(LlmProfile p) async {
          final saved = await _showProfileFormDialog(
            dialogCtx,
            initial: p,
            isEdit: true,
          );
          if (saved == null || !dialogCtx.mounted) return;
          await storage.upsertLlmProfile(saved);
          final active = await storage.getActiveLlmProfileId();
          if (active == saved.id) {
            // 编辑的是当前生效档案：重新 apply + reload
            await storage.applyLlmProfile(saved);
            await llmService.reloadConfig();
          }
          if (!dialogCtx.mounted) return;
          refresh();
          snack('已保存 ${saved.name}');
        }

        return AlertDialog(
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
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
                  child: const Icon(Icons.tune, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '模型配置',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '管理多套大模型配置档案，点击即可切换',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: 420,
            height: 400,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                children: [
                  Expanded(
                    child: FutureBuilder<
                        ({List<LlmProfile> profiles, String? activeId})>(
                      future: dataFuture,
                      builder: (bCtx, snap) {
                        final data = snap.data;
                        if (data == null) {
                          // 首次加载中 / 首次加载失败
                          if (snap.hasError) {
                            return Center(
                              child: Text(
                                '配置加载失败，请重试',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            );
                          }
                          return Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.hazeBlue,
                              ),
                            ),
                          );
                        }
                        // 刷新期间（新 future 尚未完成）沿用上一次快照，避免闪烁
                        final list = data.profiles;
                        final active = data.activeId;
                        if (list.isEmpty) {
                          return Center(
                            child: Text(
                              '暂无配置档案\n点击下方「新增配置」创建第一套',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.6,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (rowCtx, i) {
                            final p = list[i];
                            final isActive = p.id == active;
                            return Container(
                              padding: const EdgeInsets.only(left: 4, right: 4),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.hazeBlue.withValues(alpha: 0.08)
                                    : AppColors.textLight.withValues(alpha: 0.06),
                                borderRadius: AppRadius.smB,
                                border: Border.all(
                                  color: AppStroke.inkOf(context),
                                  width: AppStroke.thin,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => switchTo(p),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 10),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      p.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: isActive
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                        color: isActive
                                                            ? Theme.of(context).colorScheme.onSurface
                                                            : AppColors
                                                                .textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${p.model} · ${p.baseUrl}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Theme.of(context).colorScheme.onSurface
                                                            .withValues(
                                                                alpha: 0.9),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // API 格式徽标
                                              Container(
                                                margin: const EdgeInsets.only(left: 6),
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      AppRadius.xsB,
                                                  border:
                                                      AppStroke.all(context),
                                                ),
                                                child: Text(
                                                  p.apiFormat == 'anthropic'
                                                      ? 'Anthropic'
                                                      : 'OpenAI',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                              ),
                                              if (isActive) ...[
                                                const SizedBox(width: 6),
                                                Icon(
                                                  Icons.check,
                                                  size: 18,
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    tooltip: '编辑',
                                    onPressed: () => openEditForm(p),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    tooltip: '删除',
                                    onPressed: () => deleteProfile(p),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: openAddForm,
                      icon: const Icon(Icons.add, size: 18, color: Colors.white),
                      label: const Text(
                        '+ 新增配置',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.hazeBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// 打开档案编辑表单；用户保存则返回（新/改）档案，取消返回 null。
Future<LlmProfile?> _showProfileFormDialog(
  BuildContext context, {
  required LlmProfile initial,
  required bool isEdit,
}) {
  return showDialog<LlmProfile>(
    context: context,
    builder: (_) => _ProfileFormDialog(initial: initial, isEdit: isEdit),
  );
}

class _ProfileFormDialog extends StatefulWidget {
  final LlmProfile initial;
  final bool isEdit;

  const _ProfileFormDialog({required this.initial, required this.isEdit});

  @override
  State<_ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends State<_ProfileFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _modelCtrl;
  // API 格式：'openai'（OpenAI 兼容）| 'anthropic'（Anthropic 原生）
  late String _apiFormat;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial.name);
    _urlCtrl = TextEditingController(text: widget.initial.baseUrl);
    _keyCtrl = TextEditingController(text: widget.initial.apiKey);
    _modelCtrl = TextEditingController(text: widget.initial.model);
    _apiFormat = widget.initial.apiFormat;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      LlmProfile(
        id: widget.initial.id, // 编辑沿用原 id，新增用调用方生成的时间戳 id
        name: _nameCtrl.text.trim(),
        baseUrl: _urlCtrl.text.trim(),
        apiKey: _keyCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        apiFormat: _apiFormat,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      title: Text(
        widget.isEdit ? '编辑配置' : '新增配置',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel('名称'),
                const SizedBox(height: 6),
                _buildField(
                  controller: _nameCtrl,
                  hintText: '如 DeepSeek',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '请输入名称' : null,
                ),
                const SizedBox(height: 14),
                _buildFieldLabel('API 格式'),
                const SizedBox(height: 6),
                _buildFormatSelector(),
                const SizedBox(height: 14),
                _buildFieldLabel('Base URL'),
                const SizedBox(height: 6),
                _buildField(
                  controller: _urlCtrl,
                  hintText: _apiFormat == 'anthropic'
                      ? 'https://api.anthropic.com'
                      : 'https://api.deepseek.com/v1',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '请输入 Base URL' : null,
                ),
                const SizedBox(height: 14),
                _buildFieldLabel('API Key'),
                const SizedBox(height: 6),
                _buildField(
                  controller: _keyCtrl,
                  hintText: '请输入 API Key',
                  obscureText: _obscureKey,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () =>
                        setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
                const SizedBox(height: 14),
                _buildFieldLabel('模型名'),
                const SizedBox(height: 6),
                _buildField(
                  controller: _modelCtrl,
                  hintText: _apiFormat == 'anthropic'
                      ? 'claude-sonnet-4-5'
                      : 'deepseek-chat / gpt-4o',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '请输入模型名' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消', style: TextStyle(fontSize: 12)),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.hazeBlue,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            elevation: 0,
          ),
          child: const Text(
            '保存',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  /// API 格式二选一：OpenAI 兼容 / Anthropic 原生。
  /// 选中态用统一 2px 描边（AppStroke.all），文字一律 onSurface。
  Widget _buildFormatSelector() {
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
    final selected = _apiFormat == value;
    return GestureDetector(
      onTap: () => setState(() => _apiFormat = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.surface
              : Colors.transparent,
          borderRadius: AppRadius.smB,
          border: selected ? AppStroke.all(context) : null,
          boxShadow:
              selected ? AppShadow.hard(context, dy: 2, alpha: 0.20) : null,
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

  Widget _buildField({
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        isDense: true,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        // 继承主题：2px ink 描边 / focused hazeBlue / error angerRed
        suffixIcon: suffixIcon,
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}
