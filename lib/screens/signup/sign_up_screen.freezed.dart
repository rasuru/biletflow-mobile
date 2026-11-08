// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sign_up_screen.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SignUpModel {


/// Create a copy of SignUpModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SignUpModelCopyWith<SignUpModel> get copyWith => _$SignUpModelCopyWithImpl<SignUpModel>(this as SignUpModel, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SignUpModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SignUpModel&&(identical(other.login, _this.login) || other.login == _this.login)&&(identical(other.email, _this.email) || other.email == _this.email)&&(identical(other.password, _this.password) || other.password == _this.password)&&(identical(other.repeatedPassword, _this.repeatedPassword) || other.repeatedPassword == _this.repeatedPassword)&&const DeepCollectionEquality().equals(other.failures, _this.failures)&&(identical(other.isCreatingAccount, _this.isCreatingAccount) || other.isCreatingAccount == _this.isCreatingAccount));
}


@override
int get hashCode {
  final _this = this as SignUpModel;
  return Object.hash(runtimeType,_this.login,_this.email,_this.password,_this.repeatedPassword,const DeepCollectionEquality().hash(_this.failures),_this.isCreatingAccount);
}

@override
String toString() {
  final _this = this as SignUpModel;
  return 'SignUpModel(login: ${_this.login}, email: ${_this.email}, password: ${_this.password}, repeatedPassword: ${_this.repeatedPassword}, failures: ${_this.failures}, isCreatingAccount: ${_this.isCreatingAccount})';
}


}

/// @nodoc
abstract mixin class $SignUpModelCopyWith<$Res>  {
  factory $SignUpModelCopyWith(SignUpModel value, $Res Function(SignUpModel) _then) = _$SignUpModelCopyWithImpl;
@useResult
$Res call({
 String login, String email, String password, String repeatedPassword, Iterable<SignUpFailure> failures, bool isCreatingAccount
});




}
/// @nodoc
class _$SignUpModelCopyWithImpl<$Res>
    implements $SignUpModelCopyWith<$Res> {
  _$SignUpModelCopyWithImpl(this._self, this._then);

  final SignUpModel _self;
  final $Res Function(SignUpModel) _then;

/// Create a copy of SignUpModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? login = null,Object? email = null,Object? password = null,Object? repeatedPassword = null,Object? failures = null,Object? isCreatingAccount = null,}) {
  return _then(SignUpModel(
login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,repeatedPassword: null == repeatedPassword ? _self.repeatedPassword : repeatedPassword // ignore: cast_nullable_to_non_nullable
as String,failures: null == failures ? _self.failures : failures // ignore: cast_nullable_to_non_nullable
as Iterable<SignUpFailure>,isCreatingAccount: null == isCreatingAccount ? _self.isCreatingAccount : isCreatingAccount // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SignUpModel].
extension SignUpModelPatterns on SignUpModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({required TResult orElse(),}){
final _that = this;
switch (_that) {
case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({required TResult orElse(),}) {final _that = this;
switch (_that) {
case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
  return null;

}
}

}

// dart format on
