import 'dart:convert';
import '../../theme/ruolan_colors.dart';
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [RuolanColors.of(context).surface, RuolanColors.of(context).surface],
            ),
          ),
          child: (imagePath != null && imagePath.isNotEmpty)
              ? _buildImage(imagePath)
              : _buildPlaceholder(context),
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
          errorBuilder: (ctx, __, ___) => _buildPlaceholder(ctx),
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
          errorBuilder: (ctx, __, ___) => _buildPlaceholder(ctx),
        ),
      );
    }
    return ClipRRect(
      child: Image.asset(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (ctx, __, ___) => _buildPlaceholder(ctx),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 80, color: RuolanColors.of(context).primaryFg),
          const SizedBox(height: 12),
          Text('若澜', style: TextStyle(fontSize: 20, color: RuolanColors.of(context).primaryFg, fontWeight: FontWeight.w300)),
        ],
      ),
    );
  }
}
