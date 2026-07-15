import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agent_profile.dart';
import '../config/inference_settings.dart';
import '../config/persona_config.dart';

class SettingsProvider extends ChangeNotifier {
  List<AgentProfile> _profiles = [];
  String _activeId = 'default';
  InferenceSettings _inference = const InferenceSettings();

  /// 所有已配置角色。
  List<AgentProfile> get profiles => List.unmodifiable(_profiles);

  /// 当前激活角色 id。
  String get activeId => _activeId;

  /// 当前激活角色；列表为空时返回默认占位（理论上 load 后不会为空）。
  AgentProfile get profile {
    if (_profiles.isEmpty) return AgentProfile(id: 'default');
    for (final p in _profiles) {
      if (p.id == _activeId) return p;
    }
    return _profiles.first;
  }

  InferenceSettings get inference => _inference;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    await _loadProfiles(prefs);
    _inference = await InferenceSettings.load();
    notifyListeners();
  }

  Future<void> _loadProfiles(SharedPreferences prefs) async {
    final raw = prefs.getString('persona_profiles');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _profiles = list
            .map((e) => AgentProfile.fromJson(e as Map<String, dynamic>))
            .toList();
        _activeId = prefs.getString('active_persona_id') ??
            (_profiles.isNotEmpty ? _profiles.first.id : 'default');
        if (_profiles.isNotEmpty) return;
      } catch (_) {
        // JSON 损坏则走迁移分支重建
      }
    }
    // 从旧的单键存储迁移出默认角色（兼容升级前数据）。
    _seedDefault(prefs);
    await _persistProfiles(prefs);
  }

  void _seedDefault(SharedPreferences prefs) {
    final legacyDesc = prefs.getString('persona_description') ?? '';
    const base = PersonaConfig.defaultPersona;
    // 复现旧逻辑：旧描述非空时作为「补充设定」拼接在默认人设之后，保证体验不变。
    final persona = legacyDesc.trim().isEmpty
        ? base
        : '$base\n\n补充设定：$legacyDesc';
    _profiles = [
      AgentProfile(
        id: 'default',
        name: prefs.getString('agent_name') ?? '若澜',
        personaDescription: persona,
        voice: prefs.getString('voice') ?? '默认',
        introduction: prefs.getString('introduction') ?? '',
        openingLine:
            prefs.getString('opening_line') ?? '你好呀，我是若澜，很高兴遇见你~',
        suggestedReplies: prefs.getStringList('suggested_replies') ?? [],
        avatarPath: prefs.getString('avatar_path'),
        characterImagePath: prefs.getString('character_image_path'),
      ),
    ];
    _activeId = 'default';
  }

  Future<void> _persistProfiles([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      'persona_profiles',
      jsonEncode(_profiles.map((e) => e.toJson()).toList()),
    );
    await p.setString('active_persona_id', _activeId);
  }

  /// 保存（更新）当前激活角色。表单传来的 profile 不带稳定 id，这里用 _activeId 对齐。
  Future<void> updateActive(AgentProfile profile) async {
    final withId = profile.copyWith(id: _activeId);
    final idx = _profiles.indexWhere((e) => e.id == _activeId);
    if (idx != -1) {
      _profiles[idx] = withId;
    } else {
      _profiles.add(withId);
    }
    _activeId = withId.id;
    await _persistProfiles();
    notifyListeners();
  }

  /// 切换到指定角色（不清除对话历史，新消息自动采用新角色人设）。
  Future<void> setActive(String id) async {
    if (_profiles.any((e) => e.id == id)) {
      _activeId = id;
      await _persistProfiles();
      notifyListeners();
    }
  }

  /// 新建空白角色并设为激活（UI 随后以空表单供编辑）。
  Future<String> createProfile() async {
    final id = 'p_${DateTime.now().microsecondsSinceEpoch}';
    final newProfile = AgentProfile(
      id: id,
      name: '新角色',
      openingLine: '你好呀，我是新角色，很高兴遇见你~',
    );
    _profiles.add(newProfile);
    _activeId = id;
    await _persistProfiles();
    notifyListeners();
    return id;
  }

  /// 删除角色；仅剩一个时拒绝删除（至少保留一个）。
  Future<void> deleteProfile(String id) async {
    if (_profiles.length <= 1) return;
    _profiles.removeWhere((e) => e.id == id);
    if (_activeId == id) {
      _activeId = _profiles.first.id;
    }
    await _persistProfiles();
    notifyListeners();
  }

  Future<void> saveInference(InferenceSettings settings) async {
    _inference = settings;
    await settings.save();
    notifyListeners();
  }
}
