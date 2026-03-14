import '../services/bc/bc_odata_client.dart';
import '../services/bc/bc_settings_store.dart';
import 'user_model.dart';

class UserApi {
  final BcODataClient _client;

  UserApi({BcODataClient? client}) : _client = client ?? BcODataClient();

  Future<List<User>> fetchUsers() async {
    final settings = await BcSettingsStore.instance.load();
    if (settings.username.trim().isEmpty || settings.password.isEmpty) {
      return [];
    }

    final rows = await _client.getAll(settings, 'Users', top: 2000);
    return rows.map(_mapToUser).toList();
  }

  Future<User?> fetchUserByName(String username) async {
    final settings = await BcSettingsStore.instance.load();
    if (settings.username.trim().isEmpty || settings.password.isEmpty) {
      return null;
    }

    final safeUser = username.trim().replaceAll("'", "''");
    if (safeUser.isEmpty) return null;

    final rows = await _client.getAll(
      settings,
      'Users',
      top: 1,
      query: {'\$filter': "Name eq '$safeUser'"},
    );

    if (rows.isEmpty) return null;
    return _mapToUser(rows.first);
  }

  Future<bool> authenticate(String username, String password) async {
    final settings = await BcSettingsStore.instance.load();
    if (settings.username.trim().isEmpty || settings.password.isEmpty) {
      return false;
    }

    final safeUser = username.replaceAll("'", "''");
    final safePass = password.replaceAll("'", "''");

    final rows = await _client.getAll(
      settings,
      'Users',
      top: 1,
      query: {
        // BC OData service fields are usually the same as captions/names.
        '\$filter': "Name eq '$safeUser' and Password eq '$safePass'",
      },
    );

    return rows.isNotEmpty;
  }

  Future<void> setPassword({
    required String username,
    required String password,
  }) async {
    final settings = await BcSettingsStore.instance.load();
    if (settings.username.trim().isEmpty || settings.password.isEmpty) {
      return;
    }

    final safeUser = username.trim().replaceAll("'", "''");
    if (safeUser.isEmpty) return;

    final rows = await _client.getAll(
      settings,
      'Users',
      top: 1,
      query: {'\$filter': "Name eq '$safeUser'"},
    );

    if (rows.isEmpty) return;

    final row = rows.first;
    final etag = row['@odata.etag'];
    await _client.patchBySingleKey(settings, 'Users', safeUser, {
      'Password': password,
    }, etag: etag is String ? etag : null);
  }

  Future<void> createUser(User user) async {
    final settings = await BcSettingsStore.instance.load();
    if (settings.username.trim().isEmpty || settings.password.isEmpty) {
      throw StateError('Business Central is not configured.');
    }

    final username = user.username.trim();
    final rights = user.rights.trim();
    if (username.isEmpty) {
      throw StateError('Username is required.');
    }
    if (rights.isEmpty) {
      throw StateError('Rights are required.');
    }

    await _client.create(settings, 'Users', {
      'Name': username,
      'Password': user.password,
      'Type': rights,
    });
  }

  Future<void> updateUser(User user) async {
    final settings = await BcSettingsStore.instance.load();
    if (settings.username.trim().isEmpty || settings.password.isEmpty) {
      throw StateError('Business Central is not configured.');
    }

    final username = user.username.trim();
    final rights = user.rights.trim();
    if (username.isEmpty) {
      throw StateError('Username is required.');
    }
    if (rights.isEmpty) {
      throw StateError('Rights are required.');
    }

    final rows = await _client.getAll(
      settings,
      'Users',
      top: 1,
      query: {'\$filter': "Name eq '${username.replaceAll("'", "''")}'"},
    );
    if (rows.isEmpty) {
      throw StateError('User "$username" was not found in Business Central.');
    }

    final row = rows.first;
    final etag = row['@odata.etag'];
    await _client.patchBySingleKey(settings, 'Users', username, {
      'Password': user.password,
      'Type': rights,
    }, etag: etag is String ? etag : null);
  }

  User _mapToUser(Map<String, Object?> json) {
    String s(String key) => (json[key] as String?)?.trim() ?? '';

    // BC "Users" service provides Name/Password/Type/Date Created.
    // Map to app's local User model (username == name; email/phone optional).
    final name = s('Name');
    final pass = s('Password');

    return User(
      name: name,
      username: name,
      password: pass,
      rights: s('Type'),
      email: '',
      phone: '',
    );
  }
}
