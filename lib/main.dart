import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart'; 

import 'data/local/database_helper.dart';
import 'data/services/api_service.dart';
import 'data/repositories/weighing_repository.dart';
import 'logic/blocs/weighing_bloc.dart';

// Đảm bảo import đúng đường dẫn 2 file cũ bạn đã có
import 'ui/screens/home_dashboard.dart';
import 'ui/screens/weighing_screen.dart';
import 'ui/screens/history_screen.dart';
// import 'ui/screens/search_screen.dart'; // Uncomment nếu bạn có file này
// import 'ui/screens/settings_screen.dart'; // Uncomment nếu bạn có file này

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
          initialRoute: '/',
          routes: {
            '/': (context) => HomeDashboard(),
            '/weighing': (context) => WeighingScreen(),
            '/history': (context) => HistoryScreen(),
            // '/search': (context) => SearchScreen(),
            // '/settings': (context) => SettingsScreen(),
          },
        ),
      ),
    );
  }
}