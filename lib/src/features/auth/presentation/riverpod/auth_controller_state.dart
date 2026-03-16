import 'package:equatable/equatable.dart';
import 'package:keepsyn_app/src/core/error/failures.dart';
import 'package:keepsyn_app/src/features/auth/domain/entities/user.dart' as app;

enum AuthSessionStatus {
  loading,
  authenticated,
  unauthenticated,
}

class AuthControllerState extends Equatable {
  final AuthSessionStatus status;
  final app.User? user;
  final Failure? failure;
  final bool isSubmitting;

  const AuthControllerState({
    required this.status,
    this.user,
    this.failure,
    this.isSubmitting = false,
  });

  const AuthControllerState.loading()
      : this(status: AuthSessionStatus.loading);

  const AuthControllerState.authenticated(app.User user)
      : this(status: AuthSessionStatus.authenticated, user: user);

  const AuthControllerState.unauthenticated({
    Failure? failure,
    bool isSubmitting = false,
  }) : this(
    status: AuthSessionStatus.unauthenticated,
    failure: failure,
    isSubmitting: isSubmitting,
  );

  bool get isLoggedIn =>
      status == AuthSessionStatus.authenticated && user != null;
  bool get isBootstrapping => status == AuthSessionStatus.loading;
  bool get hasError => failure != null;

  AuthControllerState copyWith({
    AuthSessionStatus? status,
    app.User? user,
    Failure? failure,
    bool clearFailure = false,
    bool? isSubmitting,
  }) {
    return AuthControllerState(
      status: status ?? this.status,
      user: user ?? this.user,
      failure: clearFailure ? null : (failure ?? this.failure),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  List<Object?> get props => [status, user, failure, isSubmitting];
}
