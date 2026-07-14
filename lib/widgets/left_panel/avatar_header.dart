import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class AvatarHeader extends StatelessWidget {
  const AvatarHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final profile = settings.profile;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E0D6),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: (profile.avatarPath != null && profile.avatarPath!.isNotEmpty)
                      ? _buildAvatarImage(profile.avatarPath!)
                      : _defaultAvatar(),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                profile.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Color(0xFF5C3D2E)),
              ),
              if (profile.introduction.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    profile.introduction,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarImage(String path) {
    if (path.startsWith('data:image')) {
      final bytes = base64Decode(path.split(',').last);
      return Image.memory(Uint8List.fromList(bytes), fit: BoxFit.cover);
    }
    if (kIsWeb) {
      return Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultAvatar());
    }
    return Image.asset(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultAvatar());
  }

  Widget _defaultAvatar() {
    return const Icon(Icons.auto_awesome, size: 36, color: Color(0xFFC9A88C));
  }
}
