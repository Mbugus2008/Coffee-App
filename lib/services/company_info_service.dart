import '../data/company_info_api.dart';
import '../data/company_info_model.dart';
import '../data/user_database.dart';

class CompanyInfoService {
  CompanyInfoService._();

  static final CompanyInfoService instance = CompanyInfoService._();

  final CompanyInfoApi _api = CompanyInfoApi();

  Future<CompanyInfo> loadLocal() {
    return UserDatabase.instance.getCompanyInfo();
  }

  Future<void> saveLocal(CompanyInfo value) {
    return UserDatabase.instance.saveCompanyInfo(value);
  }

  Future<CompanyInfo> syncFromServer() async {
    try {
      final remote = await _api.fetchCompanyInfo();
      if (remote != null) {
        await saveLocal(remote);
      }
    } catch (_) {
      // Keep local copy when BC is unreachable.
    }

    return loadLocal();
  }
}
