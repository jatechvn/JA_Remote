part of 'glass_widgets.dart';

/// A universal, plug-and-play Glassmorphic Scaffold for Flutter Desktop & Mobile.
///
/// Wraps any custom view with the complete multi-layered Liquid Glass architecture:
/// 1. Translucent ambient gradient tint ([AppColors.bgSecondary]).
/// 2. GPU-composited floating [MeshBackground] with luminous [MeshOrb]s.
/// 3. Fully transparent scaffold background ensuring DWM Aero / Mica desktop backdrop shines through.
///
/// Example usage for any custom app:
/// ```dart
/// GlassScaffold(
///   header: MyTopBar(), // Optional
///   body: Center(
///     child: BentoCard(
///       colors: context.appColors,
///       child: Text('Hello Liquid Glass!'),
///     ),
///   ),
/// )
/// ```
class GlassScaffold extends StatelessWidget {
  final Widget body;
  final Widget? header;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final AppColors? colors;
  final bool enableMeshOrbs;
  final bool enableGradientTint;
  final bool resizeToAvoidBottomInset;
  final EdgeInsetsGeometry? padding;

  const GlassScaffold({
    super.key,
    required this.body,
    this.header,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.colors,
    this.enableMeshOrbs = true,
    this.enableGradientTint = true,
    this.resizeToAvoidBottomInset = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColors = colors ?? _resolveColors(context);

    return Scaffold(
      backgroundColor: resolvedColors.bgPrimary, // Colors.transparent
      appBar: appBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        children: [
          // 1. Mesh Gradient Base Tint (Translucent)
          if (enableGradientTint)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      resolvedColors.bgSecondary,
                      resolvedColors.bgSecondary.withValues(alpha: 0.5),
                      resolvedColors.bgSecondary.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
            ),

          // 2. GPU-Composited Floating Mesh Orbs (Animated ambient backdrop)
          if (enableMeshOrbs)
            Positioned.fill(child: MeshBackground(colors: resolvedColors)),

          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?header,
                Expanded(
                  child: padding != null
                      ? Padding(padding: padding!, child: body)
                      : body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static AppColors _resolveColors(BuildContext context) {
    try {
      final theme = context.watch<ThemeProvider>();
      return theme.colors;
    } catch (_) {
      try {
        return context.appColors;
      } catch (_) {
        return win10DarkColors;
      }
    }
  }
}
