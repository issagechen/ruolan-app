import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruolan_app/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load 从旧单键存储迁移出默认角色，且保留补充设定', () async {
    SharedPreferences.setMockInitialValues({
      'agent_name': '若澜',
      'persona_description': '喜欢猫',
      'voice': '默认',
      'introduction': 'intro',
      'opening_line': 'hi',
      'suggested_replies': ['a', 'b'],
    });
    final sp = SettingsProvider();
    await sp.load();
    expect(sp.profiles.length, 1);
    expect(sp.profile.name, '若澜');
    // 旧描述作为「补充设定」拼接在默认人设之后，体验不变。
    expect(sp.profile.personaDescription, contains('补充设定：喜欢猫'));
    expect(sp.profile.suggestedReplies, ['a', 'b']);
  });

  test('createProfile/setActive/deleteProfile 多角色流转正确', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = SettingsProvider();
    await sp.load();

    // 初始仅默认角色。
    expect(sp.profiles.length, 1);
    expect(sp.activeId, 'default');

    // 新建角色并自动激活。
    final id = await sp.createProfile();
    expect(sp.profiles.length, 2);
    expect(sp.activeId, id);
    expect(sp.profile.name, '新角色');

    // 切换到默认角色。
    await sp.setActive('default');
    expect(sp.activeId, 'default');

    // 删除新角色。
    await sp.deleteProfile(id);
    expect(sp.profiles.length, 1);

    // 仅剩一个时删除无效（至少保留一个）。
    await sp.deleteProfile('default');
    expect(sp.profiles.length, 1);
  });

  test('updateActive 用激活 id 覆盖保存当前角色配置', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = SettingsProvider();
    await sp.load();
    await sp.updateActive(
      sp.profile.copyWith(name: '改名后的若澜', personaDescription: '全新人设'),
    );
    expect(sp.profile.name, '改名后的若澜');
    expect(sp.profile.personaDescription, '全新人设');
    // 持久化后重新 load 仍有效。
    final sp2 = SettingsProvider();
    await sp2.load();
    expect(sp2.profile.name, '改名后的若澜');
  });
}
