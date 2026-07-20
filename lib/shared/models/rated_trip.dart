/// A single rated order shown on the Ratings screen.
///
/// Previously the wallet service abused the order model (`Parcel`) as a
/// generic "rated item" DTO — constructing one with most fields hardcoded
/// empty just to carry an id/date/rating through to the UI. `/me/ratings`
/// returns its own shape (`parcelId`/`date`/`rating`/`comment`), unrelated
/// to a booking's full JSON, so it gets its own small type instead.
class RatedTrip {
  final String orderId;
  final DateTime date;
  final int? rating;
  final String? comment;

  const RatedTrip({
    required this.orderId,
    required this.date,
    this.rating,
    this.comment,
  });

  factory RatedTrip.fromJson(Map<String, dynamic> json) => RatedTrip(
        orderId: json['parcelId'] as String,
        date: DateTime.parse(json['date'] as String),
        rating: json['rating'] as int?,
        comment: json['comment'] as String?,
      );
}
