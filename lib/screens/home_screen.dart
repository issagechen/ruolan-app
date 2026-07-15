import 'package:flutter/material.dart';
import '../widgets/left_panel/left_panel.dart';
import '../widgets/right_panel/right_panel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 13" tablet: ~2560px wide, excellent for side-by-side
            final isWide = constraints.maxWidth > 1200;
            final isMedium = constraints.maxWidth > 800;

            return Row(
              children: [
                Expanded(
                  // Wide: chat uses ~60% for comfortable reading width
                  // Medium: 65%, Small: 60%
                  flex: isWide ? 6 : (isMedium ? 13 : 6),
                  child: const LeftPanel(),
                ),
                if (isMedium || constraints.maxWidth > 500)
                  Expanded(
                    flex: isWide ? 4 : (isMedium ? 7 : 4),
                    child: const RightPanel(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
