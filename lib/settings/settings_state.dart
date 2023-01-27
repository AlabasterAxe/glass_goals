class GlassGoalsSettings {
  final Duration screenTimeout;
  final bool backgroundFlashEnabled;
  final Duration backgroundFlashForwardDuration;
  final Duration backgroundFlashBackwardDuration;

  GlassGoalsSettings(
      {required this.screenTimeout,
      required this.backgroundFlashEnabled,
      required this.backgroundFlashForwardDuration,
      required this.backgroundFlashBackwardDuration});
}
