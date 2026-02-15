// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payout.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Payout _$PayoutFromJson(Map<String, dynamic> json) {
  return _Payout.fromJson(json);
}

/// @nodoc
mixin _$Payout {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'author_id')
  String get authorId => throw _privateConstructorUsedError;
  @JsonKey(name: 'token_amount')
  int get tokenAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'cash_amount')
  double get cashAmount => throw _privateConstructorUsedError;
  PayoutStatus get status => throw _privateConstructorUsedError;
  String get iban => throw _privateConstructorUsedError;

  /// Serializes this Payout to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Payout
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PayoutCopyWith<Payout> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PayoutCopyWith<$Res> {
  factory $PayoutCopyWith(Payout value, $Res Function(Payout) then) =
      _$PayoutCopyWithImpl<$Res, Payout>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'author_id') String authorId,
    @JsonKey(name: 'token_amount') int tokenAmount,
    @JsonKey(name: 'cash_amount') double cashAmount,
    PayoutStatus status,
    String iban,
  });
}

/// @nodoc
class _$PayoutCopyWithImpl<$Res, $Val extends Payout>
    implements $PayoutCopyWith<$Res> {
  _$PayoutCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Payout
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? authorId = null,
    Object? tokenAmount = null,
    Object? cashAmount = null,
    Object? status = null,
    Object? iban = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            authorId: null == authorId
                ? _value.authorId
                : authorId // ignore: cast_nullable_to_non_nullable
                      as String,
            tokenAmount: null == tokenAmount
                ? _value.tokenAmount
                : tokenAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            cashAmount: null == cashAmount
                ? _value.cashAmount
                : cashAmount // ignore: cast_nullable_to_non_nullable
                      as double,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as PayoutStatus,
            iban: null == iban
                ? _value.iban
                : iban // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PayoutImplCopyWith<$Res> implements $PayoutCopyWith<$Res> {
  factory _$$PayoutImplCopyWith(
    _$PayoutImpl value,
    $Res Function(_$PayoutImpl) then,
  ) = __$$PayoutImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'author_id') String authorId,
    @JsonKey(name: 'token_amount') int tokenAmount,
    @JsonKey(name: 'cash_amount') double cashAmount,
    PayoutStatus status,
    String iban,
  });
}

/// @nodoc
class __$$PayoutImplCopyWithImpl<$Res>
    extends _$PayoutCopyWithImpl<$Res, _$PayoutImpl>
    implements _$$PayoutImplCopyWith<$Res> {
  __$$PayoutImplCopyWithImpl(
    _$PayoutImpl _value,
    $Res Function(_$PayoutImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Payout
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? authorId = null,
    Object? tokenAmount = null,
    Object? cashAmount = null,
    Object? status = null,
    Object? iban = null,
  }) {
    return _then(
      _$PayoutImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        authorId: null == authorId
            ? _value.authorId
            : authorId // ignore: cast_nullable_to_non_nullable
                  as String,
        tokenAmount: null == tokenAmount
            ? _value.tokenAmount
            : tokenAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        cashAmount: null == cashAmount
            ? _value.cashAmount
            : cashAmount // ignore: cast_nullable_to_non_nullable
                  as double,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as PayoutStatus,
        iban: null == iban
            ? _value.iban
            : iban // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PayoutImpl implements _Payout {
  const _$PayoutImpl({
    required this.id,
    @JsonKey(name: 'author_id') required this.authorId,
    @JsonKey(name: 'token_amount') required this.tokenAmount,
    @JsonKey(name: 'cash_amount') required this.cashAmount,
    this.status = PayoutStatus.pending,
    this.iban = '',
  });

  factory _$PayoutImpl.fromJson(Map<String, dynamic> json) =>
      _$$PayoutImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'author_id')
  final String authorId;
  @override
  @JsonKey(name: 'token_amount')
  final int tokenAmount;
  @override
  @JsonKey(name: 'cash_amount')
  final double cashAmount;
  @override
  @JsonKey()
  final PayoutStatus status;
  @override
  @JsonKey()
  final String iban;

  @override
  String toString() {
    return 'Payout(id: $id, authorId: $authorId, tokenAmount: $tokenAmount, cashAmount: $cashAmount, status: $status, iban: $iban)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayoutImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.authorId, authorId) ||
                other.authorId == authorId) &&
            (identical(other.tokenAmount, tokenAmount) ||
                other.tokenAmount == tokenAmount) &&
            (identical(other.cashAmount, cashAmount) ||
                other.cashAmount == cashAmount) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.iban, iban) || other.iban == iban));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    authorId,
    tokenAmount,
    cashAmount,
    status,
    iban,
  );

  /// Create a copy of Payout
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PayoutImplCopyWith<_$PayoutImpl> get copyWith =>
      __$$PayoutImplCopyWithImpl<_$PayoutImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PayoutImplToJson(this);
  }
}

abstract class _Payout implements Payout {
  const factory _Payout({
    required final String id,
    @JsonKey(name: 'author_id') required final String authorId,
    @JsonKey(name: 'token_amount') required final int tokenAmount,
    @JsonKey(name: 'cash_amount') required final double cashAmount,
    final PayoutStatus status,
    final String iban,
  }) = _$PayoutImpl;

  factory _Payout.fromJson(Map<String, dynamic> json) = _$PayoutImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'author_id')
  String get authorId;
  @override
  @JsonKey(name: 'token_amount')
  int get tokenAmount;
  @override
  @JsonKey(name: 'cash_amount')
  double get cashAmount;
  @override
  PayoutStatus get status;
  @override
  String get iban;

  /// Create a copy of Payout
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PayoutImplCopyWith<_$PayoutImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
