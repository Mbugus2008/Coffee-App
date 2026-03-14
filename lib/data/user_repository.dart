import 'package:flutter/foundation.dart';

import 'user_api.dart';
import 'user_database.dart';
import 'user_model.dart';

class UserRepository extends ChangeNotifier {
  UserRepository(this._db, {UserApi? api}) : _api = api ?? UserApi();

  final UserDatabase _db;
  final UserApi _api;
  final List<User> _users = [];

  List<User> get users => List.unmodifiable(_users);

  Future<bool> hasAnyUsers() async {
    final loaded = await _db.getUsers();
    return loaded.any((user) => user.username.trim().isNotEmpty);
  }

  Future<void> loadUsers() async {
    final loaded = await _db.getUsers();
    _users
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  Future<void> refreshFromServer() async {
    try {
      final users = await _api.fetchUsers();
      if (users.isNotEmpty) {
        await syncFromServer(users);
        await retryPendingPasswordSyncs();
        return;
      }
    } catch (_) {}

    await loadUsers();
  }

  Future<void> addUser(User user) async {
    await _assertUsernameAvailable(user.username);
    await _api.createUser(user);
    final id = await _db.insertUser(user.copyWith(updated: false));
    _users.insert(0, user.copyWith(id: id, updated: false));
    notifyListeners();
  }

  Future<void> updateUser(User user) async {
    final id = user.id;
    if (id == null) {
      throw StateError('Cannot update a user without an id.');
    }
    await _assertUsernameAvailable(user.username, excludeId: id);
    await _api.updateUser(user);
    await _db.updateUser(user.copyWith(updated: false));
    await loadUsers();
  }

  Future<void> deleteUser(User user) async {
    final id = user.id;
    if (id == null) {
      throw StateError('Cannot delete a user without an id.');
    }
    await _db.deleteUser(id);
    _users.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  Future<void> syncFromServer(List<User> users) async {
    // Preserve locally changed passwords (Updated=1) so a server refresh
    // doesn't wipe a password that was set on-device.
    final local = await _db.getUsers();
    final localByUsername = <String, User>{
      for (final u in local) u.username.trim().toLowerCase(): u,
    };

    final merged = <User>[];
    final seen = <String>{};
    for (final remote in users) {
      final key = remote.username.trim().toLowerCase();
      seen.add(key);
      final localUser = localByUsername[key];
      final localDirty = (localUser?.updated ?? false) == true;
      if (localDirty) {
        merged.add(
          remote.copyWith(
            name: localUser!.name,
            username: localUser.username,
            password: localUser.password,
            rights: localUser.rights,
            email: localUser.email,
            phone: localUser.phone,
            updated: true,
          ),
        );
      } else {
        merged.add(remote.copyWith(updated: false));
      }
    }

    // Keep local-only dirty users too.
    for (final localUser in local) {
      final key = localUser.username.trim().toLowerCase();
      if (!seen.contains(key) && (localUser.updated ?? false) == true) {
        merged.add(localUser);
      }
    }

    await _db.replaceUsers(merged);
    await loadUsers();
  }

  Future<User?> getLocalUserByUsername(String username) async {
    final u = username.trim();
    if (u.isEmpty) return null;
    return _db.getUserByUsername(u);
  }

  Future<bool> userIsAdmin(String username) async {
    final user = await getLocalUserByUsername(username);
    if (user == null) return false;
    return user.rights.trim().toLowerCase() == 'admin';
  }

  Future<bool> userNeedsPasswordSetupLocal(String username) async {
    final local = await getLocalUserByUsername(username);
    if (local == null) return false;
    return local.password.trim().isEmpty;
  }

  Future<void> setPasswordLocal({
    required String username,
    required String password,
  }) async {
    final u = username.trim();
    final p = password;
    if (u.isEmpty || p.isEmpty) return;

    final updated = await _db.updateUserPasswordMarkUpdated(
      username: u,
      password: p,
    );
    if (updated == 0) {
      await _db.insertUser(
        User(
          name: u,
          username: u,
          password: p,
          rights: '',
          email: '',
          phone: '',
          updated: true,
        ),
      );
    }

    await loadUsers();
  }

  Future<List<User>> getPendingPasswordSyncUsers() async {
    return _db.getUsersWithPendingPasswordSync();
  }

  Future<void> retryPendingPasswordSyncs() async {
    final pendingUsers = await getPendingPasswordSyncUsers();
    for (final user in pendingUsers) {
      final username = user.username.trim();
      final password = user.password;
      if (username.isEmpty || password.isEmpty) {
        continue;
      }

      try {
        await _api.setPassword(username: username, password: password);
        await _db.clearUserUpdatedFlag(username);
      } catch (error, stackTrace) {
        debugPrint(
          'Retry BC password sync failed for user "$username": $error\n$stackTrace',
        );
      }
    }

    await loadUsers();
  }

  Future<bool> authenticateLocal(String username, String password) async {
    final u = username.trim();
    if (u.isEmpty || password.isEmpty) return false;
    final user = await _db.getUserByCredentials(u, password);
    return user != null;
  }

  Future<bool> userNeedsPasswordSetup(String username) async {
    final u = username.trim();
    if (u.isEmpty) return false;

    final local = await _db.getUserByUsername(u);
    if (local != null) {
      return local.password.trim().isEmpty;
    }

    // Not in local cache yet: check Business Central directly.
    try {
      final remote = await _api.fetchUserByName(u);
      if (remote == null) return false;
      final remoteBlank = remote.password.trim().isEmpty;
      if (remoteBlank) {
        // Insert a placeholder locally so setPassword can update it.
        await _db.insertUser(
          User(
            name: remote.name.isEmpty ? u : remote.name,
            username: u,
            password: '',
            rights: remote.rights,
            email: remote.email,
            phone: remote.phone,
          ),
        );
        await loadUsers();
      }
      return remoteBlank;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPassword({
    required String username,
    required String password,
  }) async {
    final u = username.trim();
    final p = password;
    if (u.isEmpty || p.isEmpty) return;

    final updated = await _db.updateUserPasswordMarkUpdated(
      username: u,
      password: p,
    );
    if (updated == 0) {
      await _db.insertUser(
        User(
          name: u,
          username: u,
          password: p,
          rights: '',
          email: '',
          phone: '',
          updated: true,
        ),
      );
    }

    var syncedToBc = false;
    try {
      await _api.setPassword(username: u, password: p);
      syncedToBc = true;
    } catch (error, stackTrace) {
      debugPrint(
        'BC password update failed for user "$u": $error\n$stackTrace',
      );
    }

    if (syncedToBc) {
      await _db.clearUserUpdatedFlag(u);
    }

    await loadUsers();
  }

  Future<bool> authenticate(String username, String password) async {
    try {
      final ok = await _api.authenticate(username, password);
      if (ok) {
        // Keep local list updated for the Users screen.
        await refreshFromServer();
        return true;
      }
    } catch (_) {}

    final user = await _db.getUserByCredentials(username, password);
    return user != null;
  }

  Future<void> _assertUsernameAvailable(
    String username, {
    int? excludeId,
  }) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw StateError('Username is required.');
    }

    for (final user in _users) {
      if (user.username.trim().toLowerCase() != normalized) {
        continue;
      }
      if (excludeId != null && user.id == excludeId) {
        continue;
      }
      throw StateError('A user with that username already exists.');
    }
  }
}
