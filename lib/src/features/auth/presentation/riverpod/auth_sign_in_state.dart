import 'package:equatable/equatable.dart';
import 'package:keepsyn_app/src/core/error/failures.dart';

enum AuthSignInStatus {
  idle,
  loading,
  error,
}

class AuthSignInState extends Equatable {
  final AuthSignInStatus status;
  final Failure? failure;

  const AuthSignInState._({
    required this.status,
    this.failure,
  });

  const AuthSignInState.idle()
      : this._(
    status: AuthSignInStatus.idle,
  );

  const AuthSignInState.loading()
      : this._(
    status: AuthSignInStatus.loading,
  );

  const AuthSignInState.error(Failure failure)
      : this._(
    status: AuthSignInStatus.error,
    failure: failure,
  );

  bool get isIdle => status == AuthSignInStatus.idle;
  bool get isLoading => status == AuthSignInStatus.loading;
  bool get hasError => status == AuthSignInStatus.error && failure != null;

  @override
  List<Object?> get props => [status, failure];
}
