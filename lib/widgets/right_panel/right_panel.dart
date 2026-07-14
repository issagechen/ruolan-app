import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class RightPanel extends StatelessWidget {
  const RightPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final imagePath = settings.profile.characterImagePath;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFDF4F0), Color(0xFFF8E8E0)],
            ),
          ),
          child: (imagePath != null && imagePath.isNotEmpty)
              ? _buildImage(imagePath)
              : _buildPlaceholder(),
        );
      },
    );
  }

  Widget _buildImage(String path) {
    if (path.startsWith('data:image')) {
      final bytes = base64Decode(path.split(',').last);
      return ClipRRect(
        child: Image.memory(
          Uint8List.fromList(bytes),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        ),
      );
    }
    if (kIsWeb) {
      return ClipRRect(
        child: Image.network(
          path,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        ),
      );
    }
    return ClipRRect(
      child: Image.asset(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 80, color: Color(0xFFC9A88C)),
          SizedBox(height: 12),
          Text('若澜', style: TextStyle(fontSize: 20, color: Color(0xFF8B5E3C), fontWeight: FontWeight.w300)),
        ],
      ),
    );
  }
}
