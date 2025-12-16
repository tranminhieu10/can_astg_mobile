import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/auth_service.dart';

// === EVENTS ===
abstract class AuthEvent {}

class CheckAuthStatus extends AuthEvent {}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;

  LoginEvent({required this.email, required this.password});
}

class LogoutEvent extends AuthEvent {}

// === STATE ===
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? userName;
  final String? email;
  final String? token;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.userId,
    this.userName,
    this.email,
    this.token,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? userName,
    String? email,
    String? token,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      token: token ?? this.token,
      errorMessage: errorMessage,
    );
  }
}

// === BLOC ===
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;

  AuthBloc(this._authService) : super(const AuthState()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginEvent>(_onLogin);
    on<LogoutEvent>(_onLogout);
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getString('user_id');
      final userName = prefs.getString('user_name');
      final email = prefs.getString('user_email');

      if (token != null && token.isNotEmpty) {
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          token: token,
          userId: userId,
          userName: userName,
          email: email,
        ));
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _onLogin(
    LoginEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final result = await _authService.login(event.email, event.password);

      if (result['success'] == true) {
        // Lưu thông tin vào SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', result['token'] ?? '');
        await prefs.setString('user_id', result['userId'] ?? '');
        await prefs.setString('user_name', result['userName'] ?? '');
        await prefs.setString('user_email', event.email);

        emit(state.copyWith(
          status: AuthStatus.authenticated,
          token: result['token'],
          userId: result['userId'],
          userName: result['userName'],
          email: event.email,
        ));
      } else {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: result['message'] ?? 'Đăng nhập thất bại',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Lỗi kết nối: $e',
      ));
    }
  }

  Future<void> _onLogout(
    LogoutEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('user_email');

      emit(const AuthState(status: AuthStatus.unauthenticated));
    } catch (e) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }
}
