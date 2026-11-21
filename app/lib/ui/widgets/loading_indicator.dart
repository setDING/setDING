import 'package:material_ui/material_ui.dart';

/// The indicator shown while something loads: a spinner in the middle of
/// the available space.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
