// Dependency injection composition root (get_it service locator).
// Registered once at startup in main(). Later parts extend registerCore with
// the Drift database (Part 4), repositories, and Cubits.
import 'package:get_it/get_it.dart';

import '../../data/local/database.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/billing/data/sales_repository.dart';
import '../../features/customers/data/customers_repository.dart';
import '../../features/printing/data/print_service.dart';
import '../../features/printing/data/receipt_printer.dart';
import '../../features/reports/data/reports_api.dart';
import '../../features/products/data/products_remote_ds.dart';
import '../../features/products/data/products_repository.dart';
import '../../features/sync/data/sync_engine.dart';
import '../../features/sync/data/sync_remote_ds.dart';
import '../../app/theme_controller.dart';
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
  sl.registerSingleton<ThemeController>(ThemeController(config));

  // Local Drift database (offline source of truth).
  sl.registerSingleton<AppDatabase>(AppDatabase());

  // Token storage + HTTP client.
  final tokenStore = await TokenStore.create();
  sl.registerSingleton<TokenStore>(tokenStore);
  sl.registerSingleton<DioClient>(DioClient(tokenStore));

  // Authentication (session state shared by router guard + UI).
  sl.registerSingleton<AuthRepository>(AuthRepository(sl<DioClient>(), tokenStore));
  sl.registerSingleton<AuthCubit>(AuthCubit(sl<AuthRepository>()));

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
  sl.registerSingleton<CustomersRepository>(CustomersRepository(sl<AppDatabase>()));

  // Sync engine (started from main after DI is ready).
  sl.registerSingleton<SyncRemoteDataSource>(SyncRemoteDataSource(sl<DioClient>()));
  sl.registerSingleton<SyncEngine>(
    SyncEngine(sl<AppDatabase>(), sl<SyncRemoteDataSource>(), sl<ConnectivityService>()),
  );

  // Printing (platform-specific implementation selected via conditional import).
  sl.registerSingleton<PrintService>(PrintService(sl<ConfigStore>(), createReceiptPrinter()));

  // Reports.
  sl.registerSingleton<ReportsApi>(ReportsApi(sl<DioClient>()));
}
