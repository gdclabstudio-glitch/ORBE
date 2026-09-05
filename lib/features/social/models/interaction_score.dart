class InteractionScore {
  const InteractionScore({
    this.socialRelevance = 0,
    this.interactionFrequency = 0,
    this.relationshipStrength = 0,
    this.activity = 0,
    this.recency = 0,
    this.presence = 0,
    this.maxScore = 100,
  });

  final double socialRelevance;
  final double interactionFrequency;
  final double relationshipStrength;
  final double activity;
  final double recency;
  final double presence;
  final double maxScore;

  double get total => (socialRelevance +
          interactionFrequency +
          relationshipStrength +
          activity +
          recency +
          presence)
      .clamp(0, maxScore)
      .toDouble();

  double get normalized => maxScore <= 0 ? 0 : (total / maxScore).clamp(0, 1);

  double get priority => normalized;
}
