// Dependency injection composition root (get_it service locator).
// Registered once at startup in main(). Later parts extend registerCore with
// the Drift database (Part 4), repositories, and Cubits.
import 'package:get_it/get_it.dart';

import '../../data/local/database.dart';
import '../../features/billing/data/sales_repository.dart';
import '../../features/products/data/products_remote_ds.dart';
import '../../features/products/data/products_repository.dart';
import '../../features/sync/data/sync_engine.dart';
import '../../features/sync/data/sync_remote_ds.dart';
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

  // Feature repositories.
  sl.registerSingleton<ProductsRemoteDataSource>(ProductsRemoteDataSource(sl<DioClient>()));
  sl.registerSingleton<ProductsRepository>(
    ProductsRepository(sl<AppDatabase>(), sl<ProductsRemoteDataSource>(), sl<ConnectivityService>()),
  );
  sl.registerSingleton<SalesRepository>(SalesRepository(sl<AppDatabase>()));

  // Sync engine (started from main after DI is ready).
  sl.registerSingleton<SyncRemoteDataSource>(SyncRemoteDataSource(sl<DioClient>()));
  sl.registerSingleton<SyncEngine>(
    SyncEngine(sl<AppDatabase>(), sl<SyncRemoteDataSource>(), sl<ConnectivityService>()),
  );
}
