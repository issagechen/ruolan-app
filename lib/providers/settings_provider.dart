import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agent_profile.dart';
import '../config/inference_settings.dart';

class SettingsProvider extends ChangeNotifier {
  AgentProfile _profile = AgentProfile();
  AgentProfile get profile => _profile;

  InferenceSettings _inference = const InferenceSettings();
  InferenceSettings get inference => _inference;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _profile = AgentProfile(
      name: prefs.getString('agent_name') ?? '若澜',
      personaDescription: prefs.getString('persona_description') ?? '',
      voice: prefs.getString('voice') ?? '默认',
      introduction: prefs.getString('introduction') ?? '',
      openingLine: prefs.getString('opening_line') ?? '你好呀，我是若澜，很高兴遇见你~',
      suggestedReplies: prefs.getStringList('suggested_replies') ?? [],
      avatarPath: prefs.getString('avatar_path'),
      characterImagePath: prefs.getString('character_image_path'),
    );
    _inference = await InferenceSettings.load();
    notifyListeners();
  }

  Future<void> saveInference(InferenceSettings settings) async {
    _inference = settings;
    await settings.save();
    notifyListeners();
  }

  Future<void> save(AgentProfile profile) async {
    _profile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('agent_name', profile.name);
    await prefs.setString('persona_description', profile.personaDescription);
    await prefs.setString('voice', profile.voice);
    await prefs.setString('introduction', profile.introduction);
    await prefs.setString('opening_line', profile.openingLine);
    await prefs.setStringList('suggested_replies', profile.suggestedReplies);
    if (profile.avatarPath != null) {
      await prefs.setString('avatar_path', profile.avatarPath!);
    }
    if (profile.characterImagePath != null) {
      await prefs.setString('character_image_path', profile.characterImagePath!);
    }
    notifyListeners();
  }
}
