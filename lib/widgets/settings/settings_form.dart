import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/agent_profile.dart';
import '../../config/inference_settings.dart';
import '../../config/api_config.dart';
import '../../config/remote_settings.dart';
import '../../screens/model_manager_screen.dart';
import 'crop_screen.dart';

class SettingsForm extends StatefulWidget {
  final AgentProfile initialProfile;
  final InferenceSettings initialInference;
  final Function(AgentProfile) onSave;
  final Function(InferenceSettings) onSaveInference;
  const SettingsForm({
    super.key,
    required this.initialProfile,
    required this.initialInference,
    required this.onSave,
    required this.onSaveInference,
  });
  @override State<SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<SettingsForm> {
  late TextEditingController _nameCtrl, _descCtrl, _voiceCtrl, _introCtrl, _openingCtrl, _repliesCtrl;
  late TextEditingController _ctxCtrl, _maxTokensCtrl, _threadsCtrl;
  late TextEditingController _baseUrlCtrl, _apiKeyCtrl;
  late double _temperature, _topP;
  String? _avatarDataUrl, _characterDataUrl;
  String _mode = 'local';
  final ImagePicker _picker = ImagePicker();

  @override void initState() {
    super.initState();
    _loadRemote();
    _nameCtrl = TextEditingController(text: widget.initialProfile.name);
    _descCtrl = TextEditingController(text: widget.initialProfile.personaDescription);
    _voiceCtrl = TextEditingController(text: widget.initialProfile.voice);
    _introCtrl = TextEditingController(text: widget.initialProfile.introduction);
    _openingCtrl = TextEditingController(text: widget.initialProfile.openingLine);
    _repliesCtrl = TextEditingController(text: widget.initialProfile.suggestedReplies.join('\n'));
    _ctxCtrl = TextEditingController(text: widget.initialInference.ctxSize.toString());
    _maxTokensCtrl = TextEditingController(text: widget.initialInference.maxTokens.toString());
    _threadsCtrl = TextEditingController(text: widget.initialInference.threads.toString());
    _baseUrlCtrl = TextEditingController();
    _apiKeyCtrl = TextEditingController();
    _temperature = widget.initialInference.temperature;
    _topP = widget.initialInference.topP;
    final a = widget.initialProfile.avatarPath;
    if (a != null && a.startsWith('data:')) _avatarDataUrl = a;
    final c = widget.initialProfile.characterImagePath;
    if (c != null && c.startsWith('data:')) _characterDataUrl = c;
  }

  void _loadRemote() async {
    final mode = await RemoteSettings.getMode();
    final baseUrl = await RemoteSettings.getBaseUrl();
    final apiKey = await RemoteSettings.getApiKey();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _baseUrlCtrl.text = baseUrl == ApiConfig.baseUrl ? '' : baseUrl;
      _apiKeyCtrl.text = apiKey;
    });
  }

  @override void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _voiceCtrl.dispose();
    _introCtrl.dispose(); _openingCtrl.dispose(); _repliesCtrl.dispose();
    _ctxCtrl.dispose(); _maxTokensCtrl.dispose(); _threadsCtrl.dispose();
    _baseUrlCtrl.dispose(); _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndCrop(bool isAvatar) async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    if (!mounted) return;

    final aspectRatio = isAvatar ? 1.0 : 9.0 / 16.0;
    final cropped = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(
        builder: (_) => CropScreen(
          imageBytes: bytes,
          aspectRatio: aspectRatio,
          title: isAvatar ? '裁剪头像（正方形）' : '裁剪人物形象（竖版）',
        ),
      ),
    );

    if (cropped == null) return;
    final dataUrl = 'data:image/png;base64,' + base64Encode(cropped);
    setState(() {
      if (isAvatar) _avatarDataUrl = dataUrl;
      else _characterDataUrl = dataUrl;
    });
  }

  Future<void> _save() async {
    final profile = AgentProfile(
      name: _nameCtrl.text.trim().isEmpty ? '若澜' : _nameCtrl.text.trim(),
      personaDescription: _descCtrl.text.trim(),
      voice: _voiceCtrl.text.trim().isEmpty ? '默认' : _voiceCtrl.text.trim(),
      introduction: _introCtrl.text.trim(),
      openingLine: _openingCtrl.text.trim().isEmpty ? '你好呀，我是若澜，很高兴遇见你~' : _openingCtrl.text.trim(),
      suggestedReplies: _repliesCtrl.text.split('\n').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList(),
      avatarPath: _avatarDataUrl,
      characterImagePath: _characterDataUrl,
    );

    final inference = InferenceSettings(
      ctxSize: int.tryParse(_ctxCtrl.text) ?? ApiConfig.localCtxSize,
      maxTokens: int.tryParse(_maxTokensCtrl.text) ?? ApiConfig.maxTokens,
      threads: int.tryParse(_threadsCtrl.text) ?? ApiConfig.localThreads,
      temperature: _temperature,
      topP: _topP,
    );

    // 远程模式安全（REQ-API-002）：模式/URL 存 SharedPreferences，密钥存系统密钥库。
    // 在退出设置页前先持久化，避免弹栈后写入丢失。
    await RemoteSettings.setMode(_mode);
    await RemoteSettings.setBaseUrl(_baseUrlCtrl.text.trim());
    await RemoteSettings.setApiKey(_apiKeyCtrl.text.trim());

    widget.onSave(profile);
    widget.onSaveInference(inference);
  }

  @override Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      _sec('运行模式'), const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'local', label: Text('本地推理')),
          ButtonSegment(value: 'remote', label: Text('远程 API')),
        ],
        selected: {_mode},
        onSelectionChanged: (s) => setState(() => _mode = s.first),
        style: SegmentedButton.styleFrom(
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: const Color(0xFF8B5E3C),
        ),
      ),
      const SizedBox(height: 10),
      if (_mode == 'remote') ...[
        Text('远程模式密钥存于系统密钥库（Android Keystore / iOS Keychain），不会以明文写入日志。',
          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 8),
        _fld(_baseUrlCtrl, 'API Base URL（如 http://192.168.x.x:8080/v1）', 1),
        const SizedBox(height: 12),
        TextField(
          controller: _apiKeyCtrl, obscureText: true,
          decoration: InputDecoration(
            hintText: 'API Key（留空则不带鉴权头）',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true, fillColor: const Color(0xFFF5F0EC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
        ),
        const SizedBox(height: 20),
      ],
      _sec('形象设置'), const SizedBox(height: 12),
      Row(children: [
        _img('头像（正方形）', _avatarDataUrl, ()=>_pickAndCrop(true)),
        const SizedBox(width: 24),
        _img('人物形象（竖版）', _characterDataUrl, ()=>_pickAndCrop(false)),
      ]),
      const SizedBox(height: 28),
      _sec('智能体名称'), const SizedBox(height: 8), _fld(_nameCtrl, '输入智能体名称', 1),
      const SizedBox(height: 20),
      _sec('设定描述'), Text('性格特点、与用户关系、说话风格、专业特长', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      const SizedBox(height: 8), _fld(_descCtrl, '输入设定描述...', 5),
      const SizedBox(height: 20), _sec('声音'), const SizedBox(height: 8), _fld(_voiceCtrl, '声音类型', 1),
      const SizedBox(height: 20), _sec('形象介绍'), const SizedBox(height: 8), _fld(_introCtrl, '一句话介绍', 2),
      const SizedBox(height: 20), _sec('开场白'), const SizedBox(height: 8), _fld(_openingCtrl, '第一次对话的开场白', 2),
      const SizedBox(height: 20),
      _sec('建议回复'), Text('每行一个，快捷选项', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      const SizedBox(height: 8), _fld(_repliesCtrl, '建议回复1\n建议回复2', 4),
      const SizedBox(height: 28),
      _sec('推理参数'), Text('上下文长度与线程数在重启后生效；其余参数保存后立即在下次生成生效。',
        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      const SizedBox(height: 8), _num('上下文长度 (ctxSize)', _ctxCtrl, '1024 - 8192'),
      const SizedBox(height: 12), _num('单次最大生成 (maxTokens)', _maxTokensCtrl, '64 - 4096'),
      const SizedBox(height: 12), _num('推理线程数 (threads)', _threadsCtrl, '1 - 8'),
      const SizedBox(height: 12), _slider('温度 (temperature)', _temperature, 0.0, 2.0,
        _temperature.toStringAsFixed(2), (v) => setState(() => _temperature = v)),
      const SizedBox(height: 12), _slider('Top-P', _topP, 0.0, 1.0,
        _topP.toStringAsFixed(2), (v) => setState(() => _topP = v)),
      const SizedBox(height: 20),
      if (_mode == 'local') ...[
        _sec('本地模型'), const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.model_training_outlined, color: Color(0xFF8B5E3C)),
          title: const Text('模型管理', style: TextStyle(fontSize: 15, color: Color(0xFF5C3D2E))),
          subtitle: const Text('切换 / 查看本地 GGUF 模型，切换后热重载', style: TextStyle(fontSize: 12, color: Colors.grey)),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFFC9A88C)),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ModelManagerScreen()),
          ),
        ),
        const SizedBox(height: 32),
      ] else
        const SizedBox(height: 32),
      SizedBox(height: 48, child: ElevatedButton(onPressed: _save,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5E3C), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('保存设置', style: TextStyle(fontSize: 16)))),
    ]);
  }

  Widget _sec(String t)=>Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF5C3D2E)));
  Widget _fld(TextEditingController c, String h, int m)=>TextField(controller:c,maxLines:m,decoration:InputDecoration(hintText:h,hintStyle:TextStyle(color:Colors.grey[400],fontSize:14),filled:true,fillColor:const Color(0xFFF5F0EC),border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:BorderSide.none),contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:12)));

  Widget _num(String label, TextEditingController c, String hint)=>Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
    Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF5C3D2E))),
    const SizedBox(height: 6),
    TextField(controller: c, keyboardType: TextInputType.number,
      decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        filled: true, fillColor: const Color(0xFFF5F0EC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
  ]);

  Widget _slider(String label, double value, double min, double max, String shown, ValueChanged<double> onChanged)=>Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF5C3D2E))),
      Text(shown, style: const TextStyle(fontSize: 13, color: Color(0xFF8B5E3C))),
    ]),
    const SizedBox(height: 2),
    Slider(value: value, min: min, max: max, divisions: ((max - min) * 20).toInt(),
      activeColor: const Color(0xFF8B5E3C), inactiveColor: const Color(0xFFE0CFC0), onChanged: onChanged),
  ]);

  Widget _img(String label, String? dataUrl, VoidCallback onTap)=>GestureDetector(onTap:onTap, child:Column(children:[
    ClipRRect(borderRadius:BorderRadius.circular(12),
      child:Container(width:80,height:80,color:const Color(0xFFF0E0D6),
        child:(dataUrl!=null&&dataUrl!.isNotEmpty)?_preview(dataUrl):const Icon(Icons.add_photo_alternate_outlined,color:Color(0xFFC9A88C),size:32))),
    const SizedBox(height:6),Text(label,style:TextStyle(fontSize:13,color:Colors.grey[600]))]));

  Widget _preview(String path){
    if(path.startsWith('data:image')){final b=base64Decode(path.split(',').last);return Image.memory(Uint8List.fromList(b),fit:BoxFit.cover);}
    if(kIsWeb)return Image.network(path,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.add_photo_alternate_outlined,color:Color(0xFFC9A88C),size:32));
    return Image.asset(path,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.add_photo_alternate_outlined,color:Color(0xFFC9A88C),size:32));
  }
}