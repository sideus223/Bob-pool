class AppConfig {
  /// A fresh checkout can demonstrate recommendation without a Firebase project.
  static const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);

  /// Record feedback normally while optionally comparing with the V2 baseline.
  static const learningEnabled = bool.fromEnvironment(
    'LEARNING_ENABLED',
    defaultValue: true,
  );
}
