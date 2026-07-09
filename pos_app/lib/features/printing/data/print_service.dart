// Ties config (company profile + printer settings) to the platform printer.
// Call sites just hand it a saved bill.
import '../../../core/config/config_store.dart';
import '../../../data/local/database.dart';
import '../domain/receipt_data.dart';
import 'receipt_printer.dart';

class PrintService {
  final ConfigStore _config;
  final ReceiptPrinter _printer;

  PrintService(this._config, this._printer);

  CompanyProfile get company {
    final raw = _config.read<Map>('company');
    return raw == null ? const CompanyProfile() : CompanyProfile.fromJson(raw.cast<String, dynamic>());
  }

  PrinterConfig get printerConfig {
    final raw = _config.read<Map>('printer');
    return raw == null ? const PrinterConfig() : PrinterConfig.fromJson(raw.cast<String, dynamic>());
  }

  Future<PrintOutcome> printBill(FullBill full, {String cashier = 'Cashier', String customer = 'Walk-in'}) {
    final data = ReceiptData.fromBill(
      company: company,
      full: full,
      cashier: cashier,
      customer: customer,
    );
    return _printer.printReceipt(data, config: printerConfig);
  }
}
