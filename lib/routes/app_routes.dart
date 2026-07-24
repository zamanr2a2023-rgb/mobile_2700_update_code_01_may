/// Route paths (aligned with React prototype screen ids where helpful).
abstract final class AppRoutes {
  static const introLoader = '/intro';
  static const splash = '/splash';
  static const login = '/login';
  static const forgot = '/forgot';
  static const register = '/register';
  static const roleSelect = '/role-select';
  static const fleetRegister = '/fleet-register';
  static const mechanicRegister = '/mechanic-register';
  static const termsFleet = '/terms/fleet';
  static const termsMechanic = '/terms/mechanic';
  static const pending = '/pending';

  static const fleetHome = '/fleet';
  static const mechanicHome = '/mechanic';
  static const companyHome = '/company';
  static const employeeHome = '/employee';

  /// Independent mechanic — pending company invitations inbox.
  static const companyInvites = '/mechanic/company-invites';

  /// New-user invite registration (deep link / validated token).
  static const inviteRegister = '/invite-register';
}
