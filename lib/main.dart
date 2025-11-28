import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart'; // Bắt buộc

import 'data/local/database_helper.dart';
import 'data/services/api_service.dart';
import 'data/repositories/weighing_repository.dart';
import 'logic/blocs/weighing_bloc.dart';

// --- IMPORT MÀN HÌNH MỚI ---
import 'ui/screens/home_dashboard.dart'; 
// import 'ui/screens/weighing_screen.dart'; // Không cần import ở đây nữa vì HomeDashboard sẽ gọi nó

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // Khởi tạo thư viện Native
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Khởi tạo Dependency Injection (DI)
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => ApiService()),
        RepositoryProvider(create: (_) => DatabaseHelper.instance),
        RepositoryProvider(
          create: (context) => WeighingRepository(
            context.read<ApiService>(),
            context.read<DatabaseHelper>(),
          ),
        ),
      ],
      // --- BƯỚC QUAN TRỌNG: Bọc BlocProvider ở đây ---
      // Để Bloc sống toàn cục, không bị mất khi chuyển màn hình
      child: BlocProvider(
        create: (context) => WeighingBloc(
          context.read<WeighingRepository>()
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Smart Weight',
          theme: ThemeData(
            primarySwatch: Colors.blue, 
            useMaterial3: false
          ),
          // --- ĐỔI MÀN HÌNH CHÍNH VỀ DASHBOARD ---
          home: HomeDashboard(), 
        ),
      ),
    );
  }
}