// Dependency injection composition root (get_it service locator).
// Registered once at startup in main(). Later parts extend registerCore with
// the Drift database (Part 4), repositories, and Cubits.
import 'package:get_it/get_it.dart';

import '../../data/local/database.dart';
import '../config/config_store.dart';
import '../network/connectivity_service.dart';
import '../network/dio_client.dart';
import '../network/token_store.dart';

final GetIt sl = GetIt.instance;

Future<void> registerCore() async {
  // Config store (platform-specific, initialised eagerly).
  final config = createConfigStore();
  await config.init();
  sl.registerSingleton<ConfigStore>(config);

  // Local Drift database (offline source of truth).
  sl.registerSingleton<AppDatabase>(AppDatabase());

  // Token storage + HTTP client.
  final tokenStore = await TokenStore.create();
  sl.registerSingleton<TokenStore>(tokenStore);
  sl.registerSingleton<DioClient>(DioClient(tokenStore));

  // Connectivity.
  final connectivity = ConnectivityService();
  await connectivity.init();
  sl.registerSingleton<ConnectivityService>(connectivity);
}
