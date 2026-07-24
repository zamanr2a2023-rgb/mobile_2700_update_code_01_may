import 'package:flutter/foundation.dart';

import '../../../data/models/company_invite.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/services/users_api_service.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';

/// Mechanic inbox for company invitations (`GET/POST .../users/me/company-invites`).
class CompanyInvitesViewModel extends ChangeNotifier {
  CompanyInvitesViewModel({
    required AuthRepository auth,
    required AuthViewModel authViewModel,
    UsersApiService? usersApi,
  })  : _auth = auth,
        _authViewModel = authViewModel,
        _usersApi = usersApi ?? UsersApiService();

  final AuthRepository _auth;
  final AuthViewModel _authViewModel;
  final UsersApiService _usersApi;

  List<CompanyInvite> invites = const [];
  bool loading = false;
  String? error;
  String? actionInviteId;
  String? actionError;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken?.trim();
      if (token == null || token.isEmpty) {
        throw Exception('Not signed in');
      }
      final body = await _usersApi.fetchCompanyInvites(accessToken: token);
      invites = CompanyInvite.listFromEnvelope(body);
      error = null;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      if (!silent) invites = const [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Returns `true` when accept succeeded and session was refreshed to employee.
  Future<bool> accept(String inviteId) async {
    final id = inviteId.trim();
    if (id.isEmpty || actionInviteId != null) return false;
    actionInviteId = id;
    actionError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken?.trim();
      if (token == null || token.isEmpty) {
        throw Exception('Not signed in');
      }
      final body = await _usersApi.acceptCompanyInvite(accessToken: token, inviteId: id);
      await _authViewModel.applyInviteAcceptResponse(body);
      invites = invites.where((e) => e.id != id).toList(growable: false);
      return true;
    } catch (e) {
      actionError = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      actionInviteId = null;
      notifyListeners();
    }
  }

  Future<bool> decline(String inviteId) async {
    final id = inviteId.trim();
    if (id.isEmpty || actionInviteId != null) return false;
    actionInviteId = id;
    actionError = null;
    notifyListeners();
    try {
      final session = await _auth.getSession();
      final token = session?.accessToken?.trim();
      if (token == null || token.isEmpty) {
        throw Exception('Not signed in');
      }
      await _usersApi.declineCompanyInvite(accessToken: token, inviteId: id);
      invites = invites.where((e) => e.id != id).toList(growable: false);
      return true;
    } catch (e) {
      actionError = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      actionInviteId = null;
      notifyListeners();
    }
  }
}
