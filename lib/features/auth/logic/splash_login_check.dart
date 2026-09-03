import '../../../core/auth/session_validation.dart';
import '../../../data/models/session.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../routes/app_routes.dart';

/// Maps an authenticated session to the role home route.
String homeRouteForSession(Session session) => switch (session.role) {
      UserRole.fleet => AppRoutes.fleetHome,
      UserRole.mechanic => AppRoutes.mechanicHome,
      UserRole.company => AppRoutes.companyHome,
      UserRole.employee => AppRoutes.employeeHome,
    };

/// After intro/splash, returns login or role home based on a **validated** session.
/// Prefer [AuthViewModel.bootstrapSession] at app start.
Future<String> resolvePostSplashLocation(AuthRepository auth) async {
  final result = await auth.validateStoredSession();
  switch (result.status) {
    case SessionValidationStatus.none:
    case SessionValidationStatus.invalid:
      return AppRoutes.splash;
    case SessionValidationStatus.valid:
      return homeRouteForSession(result.session!);
    case SessionValidationStatus.unreachable:
      // Keep credentials; caller should Retry rather than enter home.
      throw const SessionUnreachableException();
  }
}
