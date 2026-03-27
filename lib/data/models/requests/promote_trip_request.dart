/// Request to promote a trip
class PromoteTripRequest {
  final String? donationLink;
  final bool isPreAnnounced;
  final DateTime? countdownStartDate;

  PromoteTripRequest({
    this.donationLink,
    this.isPreAnnounced = false,
    this.countdownStartDate,
  });

  Map<String, dynamic> toJson() => {
        if (donationLink != null && donationLink!.isNotEmpty)
          'donationLink': donationLink,
        'isPreAnnounced': isPreAnnounced,
        if (countdownStartDate != null)
          'countdownStartDate': countdownStartDate!.toIso8601String(),
      };
}
