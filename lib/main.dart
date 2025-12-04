import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';

import 'data/local/database_helper.dart';
import 'data/services/api_service.dart';
import 'data/repositories/weighing_repository.dart';
import 'logic/blocs/weighing_bloc.dart';

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
  final weighingRepository = WeighingRepository(apiService, dbHelper);

  runApp(SmartWeightApp(
    weighingRepository: weighingRepository,
  ));
}

class SmartWeightApp extends StatelessWidget {
  final WeighingRepository weighingRepository;

  const SmartWeightApp({
    Key? key,
    required this.weighingRepository,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
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
        initialRoute: '/',
        routes: {
          '/': (context) => HomeDashboard(),
          '/weighing': (context) => WeighingScreen(),
          '/history': (context) => HistoryScreen(),
          '/search': (context) => SearchScreen(),
          '/settings': (context) => SettingsScreen(),
        },
      ),
    );
  }
}
