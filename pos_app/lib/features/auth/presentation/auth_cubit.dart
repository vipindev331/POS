// AuthCubit — owns session state and drives the router's redirect guard.
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  final AuthStatus status;
  final AuthUser? user;
  final bool loading;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.loading = false,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, AuthUser? user, bool? loading, String? error, bool clearError = false}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [status, user, loading, error];
}

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repo;
  AuthCubit(this._repo) : super(const AuthState());

  /// Called at startup. Uses the cached session immediately, then validates.
  Future<void> bootstrap() async {
    if (!_repo.hasSession) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }
    emit(AuthState(status: AuthStatus.authenticated, user: _repo.cachedUser));
    final user = await _repo.me();
    if (user != null) {
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } else {
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  Future<bool> login(String username, String password) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final user = await _repo.login(username, password);
      emit(AuthState(status: AuthStatus.authenticated, user: user));
      return true;
    } on AuthException catch (e) {
      emit(state.copyWith(loading: false, status: AuthStatus.unauthenticated, error: e.message));
      return false;
    } catch (e) {
      emit(state.copyWith(loading: false, status: AuthStatus.unauthenticated, error: 'Cannot reach server'));
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
