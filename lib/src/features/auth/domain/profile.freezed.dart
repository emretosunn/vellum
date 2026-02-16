// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Profile _$ProfileFromJson(Map<String, dynamic> json) {
  return _Profile.fromJson(json);
}

/// @nodoc
mixin _$Profile {
  String get id => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  UserRole get role => throw _privateConstructorUsedError;
  @JsonKey(name: 'token_balance')
  int get tokenBalance => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_verified_author')
  bool get isVerifiedAuthor => throw _privateConstructorUsedError;
  @JsonKey(
    name: 'notification_preferences',
    readValue: _readNotificationPreferences,
  )
  Map<String, dynamic> get notificationPreferences =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Profile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Profile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProfileCopyWith<Profile> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProfileCopyWith<$Res> {
  factory $ProfileCopyWith(Profile value, $Res Function(Profile) then) =
      _$ProfileCopyWithImpl<$Res, Profile>;
  @useResult
  $Res call({
    String id,
    String username,
    UserRole role,
    @JsonKey(name: 'token_balance') int tokenBalance,
    @JsonKey(name: 'is_verified_author') bool isVerifiedAuthor,
    @JsonKey(
      name: 'notification_preferences',
      readValue: _readNotificationPreferences,
    )
    Map<String, dynamic> notificationPreferences,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class _$ProfileCopyWithImpl<$Res, $Val extends Profile>
    implements $ProfileCopyWith<$Res> {
  _$ProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Profile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? role = null,
    Object? tokenBalance = null,
    Object? isVerifiedAuthor = null,
    Object? notificationPreferences = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            username: null == username
                ? _value.username
                : username // ignore: cast_nullable_to_non_nullable
                      as String,
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as UserRole,
            tokenBalance: null == tokenBalance
                ? _value.tokenBalance
                : tokenBalance // ignore: cast_nullable_to_non_nullable
                      as int,
            isVerifiedAuthor: null == isVerifiedAuthor
                ? _value.isVerifiedAuthor
                : isVerifiedAuthor // ignore: cast_nullable_to_non_nullable
                      as bool,
            notificationPreferences: null == notificationPreferences
                ? _value.notificationPreferences
                : notificationPreferences // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProfileImplCopyWith<$Res> implements $ProfileCopyWith<$Res> {
  factory _$$ProfileImplCopyWith(
    _$ProfileImpl value,
    $Res Function(_$ProfileImpl) then,
  ) = __$$ProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String username,
    UserRole role,
    @JsonKey(name: 'token_balance') int tokenBalance,
    @JsonKey(name: 'is_verified_author') bool isVerifiedAuthor,
    @JsonKey(
      name: 'notification_preferences',
      readValue: _readNotificationPreferences,
    )
    Map<String, dynamic> notificationPreferences,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  });
}

/// @nodoc
class __$$ProfileImplCopyWithImpl<$Res>
    extends _$ProfileCopyWithImpl<$Res, _$ProfileImpl>
    implements _$$ProfileImplCopyWith<$Res> {
  __$$ProfileImplCopyWithImpl(
    _$ProfileImpl _value,
    $Res Function(_$ProfileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Profile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? username = null,
    Object? role = null,
    Object? tokenBalance = null,
    Object? isVerifiedAuthor = null,
    Object? notificationPreferences = null,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$ProfileImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        username: null == username
            ? _value.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String,
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as UserRole,
        tokenBalance: null == tokenBalance
            ? _value.tokenBalance
            : tokenBalance // ignore: cast_nullable_to_non_nullable
                  as int,
        isVerifiedAuthor: null == isVerifiedAuthor
            ? _value.isVerifiedAuthor
            : isVerifiedAuthor // ignore: cast_nullable_to_non_nullable
                  as bool,
        notificationPreferences: null == notificationPreferences
            ? _value._notificationPreferences
            : notificationPreferences // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProfileImpl implements _Profile {
  const _$ProfileImpl({
    required this.id,
    required this.username,
    this.role = UserRole.reader,
    @JsonKey(name: 'token_balance') this.tokenBalance = 0,
    @JsonKey(name: 'is_verified_author') this.isVerifiedAuthor = false,
    @JsonKey(
      name: 'notification_preferences',
      readValue: _readNotificationPreferences,
    )
    final Map<String, dynamic> notificationPreferences =
        const <String, dynamic>{
          'newChapter': true,
          'comments': true,
          'promotions': false,
          'weeklyDigest': true,
        },
    @JsonKey(name: 'created_at') this.createdAt,
  }) : _notificationPreferences = notificationPreferences;

  factory _$ProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProfileImplFromJson(json);

  @override
  final String id;
  @override
  final String username;
  @override
  @JsonKey()
  final UserRole role;
  @override
  @JsonKey(name: 'token_balance')
  final int tokenBalance;
  @override
  @JsonKey(name: 'is_verified_author')
  final bool isVerifiedAuthor;
  final Map<String, dynamic> _notificationPreferences;
  @override
  @JsonKey(
    name: 'notification_preferences',
    readValue: _readNotificationPreferences,
  )
  Map<String, dynamic> get notificationPreferences {
    if (_notificationPreferences is EqualUnmodifiableMapView)
      return _notificationPreferences;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_notificationPreferences);
  }

  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @override
  String toString() {
    return 'Profile(id: $id, username: $username, role: $role, tokenBalance: $tokenBalance, isVerifiedAuthor: $isVerifiedAuthor, notificationPreferences: $notificationPreferences, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProfileImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.tokenBalance, tokenBalance) ||
                other.tokenBalance == tokenBalance) &&
            (identical(other.isVerifiedAuthor, isVerifiedAuthor) ||
                other.isVerifiedAuthor == isVerifiedAuthor) &&
            const DeepCollectionEquality().equals(
              other._notificationPreferences,
              _notificationPreferences,
            ) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    username,
    role,
    tokenBalance,
    isVerifiedAuthor,
    const DeepCollectionEquality().hash(_notificationPreferences),
    createdAt,
  );

  /// Create a copy of Profile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProfileImplCopyWith<_$ProfileImpl> get copyWith =>
      __$$ProfileImplCopyWithImpl<_$ProfileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProfileImplToJson(this);
  }
}

abstract class _Profile implements Profile {
  const factory _Profile({
    required final String id,
    required final String username,
    final UserRole role,
    @JsonKey(name: 'token_balance') final int tokenBalance,
    @JsonKey(name: 'is_verified_author') final bool isVerifiedAuthor,
    @JsonKey(
      name: 'notification_preferences',
      readValue: _readNotificationPreferences,
    )
    final Map<String, dynamic> notificationPreferences,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
  }) = _$ProfileImpl;

  factory _Profile.fromJson(Map<String, dynamic> json) = _$ProfileImpl.fromJson;

  @override
  String get id;
  @override
  String get username;
  @override
  UserRole get role;
  @override
  @JsonKey(name: 'token_balance')
  int get tokenBalance;
  @override
  @JsonKey(name: 'is_verified_author')
  bool get isVerifiedAuthor;
  @override
  @JsonKey(
    name: 'notification_preferences',
    readValue: _readNotificationPreferences,
  )
  Map<String, dynamic> get notificationPreferences;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of Profile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProfileImplCopyWith<_$ProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
