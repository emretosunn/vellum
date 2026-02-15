import 'package:freezed_annotation/freezed_annotation.dart';

part 'payout.freezed.dart';
part 'payout.g.dart';

/// Ödeme durumu enum'u.
enum PayoutStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('paid')
  paid,
  @JsonValue('rejected')
  rejected,
}

/// Yazar ödeme modeli.
@freezed
class Payout with _$Payout {
  const factory Payout({
    required String id,
    @JsonKey(name: 'author_id') required String authorId,
    @JsonKey(name: 'token_amount') required int tokenAmount,
    @JsonKey(name: 'cash_amount') required double cashAmount,
    @Default(PayoutStatus.pending) PayoutStatus status,
    @Default('') String iban,
  }) = _Payout;

  factory Payout.fromJson(Map<String, dynamic> json) =>
      _$PayoutFromJson(json);
}
