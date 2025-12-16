import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';

import 'data/local/database_helper.dart';
import 'data/services/api_service.dart';
import 'data/services/auth_service.dart';
import 'data/repositories/weighing_repository.dart';
import 'logic/blocs/weighing_bloc.dart';
import 'logic/blocs/auth_bloc.dart';

import 'ui/screens/login_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/home_dashboard.dart';
import 'ui/screens/weighing_screen.dart';
import 'ui/screens/search_screen.dart';
import 'ui/screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hàm này trả về void, KHÔNG dùng await
  MediaKit.ensureInitialized();

  final dbHelper = DatabaseHelper.instance;
  final apiService = ApiService();
  final authService = AuthService();
  final weighingRepository = WeighingRepository(apiService, dbHelper);

  runApp(SmartWeightApp(
    weighingRepository: weighingRepository,
    authService: authService,
  ));
}

class SmartWeightApp extends StatelessWidget {
  final WeighingRepository weighingRepository;
  final AuthService authService;

  const SmartWeightApp({
    Key? key,
    required this.weighingRepository,
    required this.authService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(authService)..add(CheckAuthStatus()),
        ),
        BlocProvider<WeighingBloc>(
          create: (_) => WeighingBloc(weighingRepository)..add(InitSignalR()),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Smart Weight',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: false,
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => HomeDashboard(),
          '/weighing': (context) => const WeighingScreen(),
          '/history': (context) => HistoryScreen(),
          '/search': (context) => SearchScreen(),
          '/settings': (context) => SettingsScreen(),
        },
      ),
    );
  }
}

/// Widget kiểm tra trạng thái đăng nhập và điều hướng
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.initial:
          case AuthStatus.loading:
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          case AuthStatus.authenticated:
            return HomeDashboard();
          case AuthStatus.unauthenticated:
          case AuthStatus.error:
            return const LoginScreen();
        }
      },
    );
  }
}

