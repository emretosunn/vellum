import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

/// İşlem tipi enum'u.
enum TransactionType {
  @JsonValue('deposit')
  deposit,
  @JsonValue('purchase')
  purchase,
  @JsonValue('author_fee')
  authorFee,
  @JsonValue('payout')
  payout,
}

/// Finansal işlem modeli.
@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required TransactionType type,
    required int amount,
    @JsonKey(name: 'related_book_id') String? relatedBookId,
    @Default('') String description,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}
