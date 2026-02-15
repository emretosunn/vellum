// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payout.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PayoutImpl _$$PayoutImplFromJson(Map<String, dynamic> json) => _$PayoutImpl(
  id: json['id'] as String,
  authorId: json['author_id'] as String,
  tokenAmount: (json['token_amount'] as num).toInt(),
  cashAmount: (json['cash_amount'] as num).toDouble(),
  status:
      $enumDecodeNullable(_$PayoutStatusEnumMap, json['status']) ??
      PayoutStatus.pending,
  iban: json['iban'] as String? ?? '',
);

Map<String, dynamic> _$$PayoutImplToJson(_$PayoutImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'author_id': instance.authorId,
      'token_amount': instance.tokenAmount,
      'cash_amount': instance.cashAmount,
      'status': _$PayoutStatusEnumMap[instance.status]!,
      'iban': instance.iban,
    };

const _$PayoutStatusEnumMap = {
  PayoutStatus.pending: 'pending',
  PayoutStatus.paid: 'paid',
  PayoutStatus.rejected: 'rejected',
};
