import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/forgot_screen.dart';
import '../features/auth/screens/fleet_register_screen.dart';
import '../features/auth/screens/intro_loader_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/mechanic_register_screen.dart';
import '../features/auth/screens/pending_screen.dart';
import '../features/auth/screens/role_select_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/terms_screen.dart';
import '../features/auth/viewmodel/auth_viewmodel.dart';
import '../features/auth/logic/splash_login_check.dart';
import '../data/models/session.dart';
import '../features/company/screens/company_app_shell.dart';
import '../features/employee/screens/employee_app_shell.dart';
import '../features/fleet/screens/fleet_app_shell.dart';
import '../features/mechanic/screens/mechanic_app_shell.dart';
import 'app_routes.dart';

/// Application router with auth redirect guards.
abstract final class AppRouter {
  /// Maps prototype navigation ids and absolute paths used by onboarding screens.
  static void navigateAuth(BuildContext context, String target) {
    final router = GoRouter.of(context);
    if (target.startsWith('/')) {
      router.go(target);
      return;
    }
    switch (target) {
      case 'login':
        router.go(AppRoutes.login);
        return;
      case 'splash':
        router.go(AppRoutes.splash);
        return;
      case 'fleet-dashboard':
        router.go(AppRoutes.fleetHome);
        return;
      case 'mechanic-dashboard':
        router.go(AppRoutes.mechanicHome);
        return;
      case 'employee-dashboard':
        router.go(AppRoutes.employeeHome);
        return;
      case 'company-dashboard':
        router.go(AppRoutes.companyHome);
        return;
      case 'role-select':
        router.go(AppRoutes.roleSelect);
        return;
      case 'role-select-signup':
        router.go('${AppRoutes.roleSelect}?signup=1');
        return;
      case 'fleet-register':
        router.go(AppRoutes.fleetRegister);
        return;
      case 'mechanic-register':
        router.go(AppRoutes.mechanicRegister);
        return;
      case 'terms':
        router.go(AppRoutes.termsFleet);
        return;
      case 'mechanic-terms':
        router.go(AppRoutes.termsMechanic);
        return;
      case 'forgot':
        router.push(AppRoutes.forgot);
        return;
      default:
        router.go(AppRoutes.splash);
        return;
    }
  }

  static GoRouter create(AuthViewModel auth) {
    return GoRouter(
      initialLocation: AppRoutes.introLoader,
      refreshListenable: auth,
      redirect: (context, state) {
        final path = state.matchedLocation;
        final open = _isAuthArea(path);
        if (!auth.isAuthenticated && !open && path != AppRoutes.introLoader) {
          return AppRoutes.splash;
        }
        if (auth.isAuthenticated &&
            (path == AppRoutes.login ||
                path == AppRoutes.splash ||
                path == AppRoutes.register ||
                path == AppRoutes.roleSelect ||
                path == AppRoutes.fleetRegister ||
                path == AppRoutes.mechanicRegister ||
                path == AppRoutes.forgot ||
                path == AppRoutes.pending ||
                path.startsWith('/terms/'))) {
          return homeRouteForSession(auth.session!);
        }
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.introLoader,
          builder: (context, state) => const IntroLoaderScreen(),
        ),
        GoRoute(
          path: AppRoutes.splash,
          builder: (context, state) => SplashScreen(
            onNavigate: (id) => navigateAuth(context, id),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) {
            final roleParam = state.uri.queryParameters['role'];
            final role = switch (roleParam) {
              'mechanic' => UserRole.mechanic,
              'fleet' => UserRole.fleet,
              _ => UserRole.fleet,
            };
            return LoginScreen(
              role: role,
              onNavigate: (id) => navigateAuth(context, id),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.forgot,
          builder: (context, state) => const ForgetScreen(),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) => RoleSelectScreen(
            onNavigate: (id) => navigateAuth(context, id),
            signupFlow: true,
          ),
        ),
        GoRoute(
          path: AppRoutes.roleSelect,
          builder: (context, state) {
            final signup = state.uri.queryParameters['signup'] == '1';
            return RoleSelectScreen(
              onNavigate: (id) => navigateAuth(context, id),
              signupFlow: signup,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.fleetRegister,
          builder: (context, state) => FleetRegisterScreen(
            onNavigate: (id) => navigateAuth(context, id),
          ),
        ),
        GoRoute(
          path: AppRoutes.mechanicRegister,
          builder: (context, state) => MechanicRegisterScreen(
            onNavigate: (id) => navigateAuth(context, id),
          ),
        ),
        GoRoute(
          path: AppRoutes.termsFleet,
          builder: (context, state) => TermsScreen(
            onNavigate: (id) => navigateAuth(context, id),
            nextRoute: AppRoutes.pending,
            buttonLabel: 'Accept & Continue →',
          ),
        ),
        GoRoute(
          path: AppRoutes.termsMechanic,
          builder: (context, state) => TermsScreen(
            onNavigate: (id) => navigateAuth(context, id),
            nextRoute: AppRoutes.pending,
            buttonLabel: 'Accept & Continue →',
          ),
        ),
        GoRoute(
          path: AppRoutes.pending,
          builder: (context, state) => PendingApprovalScreen(
            onNavigate: (id) => navigateAuth(context, id),
          ),
        ),
        GoRoute(
          path: AppRoutes.fleetHome,
          builder: (context, state) => const FleetAppShell(),
        ),
        GoRoute(
          path: AppRoutes.mechanicHome,
          builder: (context, state) => const MechanicAppShell(),
        ),
        GoRoute(
          path: AppRoutes.companyHome,
          builder: (context, state) => const CompanyAppShell(),
        ),
        GoRoute(
          path: AppRoutes.employeeHome,
          builder: (context, state) => const EmployeeAppShell(),
        ),
      ],
    );
  }

  static bool _isAuthArea(String path) =>
      path == AppRoutes.introLoader ||
      path == AppRoutes.splash ||
      path == AppRoutes.login ||
      path == AppRoutes.forgot ||
      path == AppRoutes.register ||
      path == AppRoutes.roleSelect ||
      path == AppRoutes.fleetRegister ||
      path == AppRoutes.mechanicRegister ||
      path.startsWith('/terms/') ||
      path == AppRoutes.pending;
}
