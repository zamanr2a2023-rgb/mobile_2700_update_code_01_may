import '../models/fleet_job_summary.dart';
import '../models/job_offer.dart';
import '../models/mechanic_quote.dart';
import '../models/forgot_password_result.dart';
import '../models/session.dart';
import '../models/team_member.dart';
import '../models/vehicle.dart';
import '../../core/constants/app_assets.dart';
import '../../features/categories/job_categories.dart';

abstract class AuthRepository {
  Future<Session?> getSession();
  Future<void> saveSession(Session session);
  Future<void> clearSession();

  /// Real backend login. Implementations may ignore [roleHint] if backend returns role.
  Future<Session> login({
    required String email,
    required String password,
    required UserRole roleHint,
  });

  /// Optional backend logout (best-effort). Send [accessToken] as `Authorization: Bearer` when present.
  Future<void> logout({String? accessToken, String? refreshToken});

  /// Permanently delete the signed-in account (`DELETE /api/v1/users/me` + password).
  Future<void> deleteAccount({
    required String accessToken,
    required String password,
  });

  /// Merge user/role fields from an auth-like API body into the current session
  /// (e.g. after accepting a company invite). Preserves tokens when the body omits them.
  Future<Session> mergeSessionFromAuthBody(
    Map<String, dynamic> body, {
    required UserRole roleHint,
  });

  /// `POST /api/v1/auth/forgot-password` — sends reset instructions to [email].
  Future<ForgotPasswordResult> forgotPassword({required String email});

  /// Fleet operator registration — returns session when API issues tokens.
  Future<Session> registerFleetOperator({
    required String companyName,
    required String contactPerson,
    required String email,
    required String password,
    required String confirmPassword,
  });

  /// Service Provider (mechanic) registration.
  Future<void> registerServiceProvider({
    required String email,
    required String password,
    required String confirmPassword,
    required String fullName,
    required String phone,
    required String businessType, // e.g. SOLE_TRADER | COMPANY
    String? displayName,
    String? businessName,
    String? companyName,
    String? baseLocationText,
    String? basePostcode,
    num? hourlyRate,
    num? emergencyRate,
    num? emergencySurcharge,
    num? callOutFee,
    String? rateCurrency,
    num? coverageRadius,
    String? profilePhotoUrl,
    String? profilePhotoPath,
    List<String>? skills,
  });

  /// Company mechanic employee (invite) — `POST /api/v1/auth/register` with `role: MECHANIC_EMPLOYEE`.
  /// Returns a session when the API issues tokens.
  Future<Session> registerMechanicEmployee({
    required String email,
    required String password,
    required String confirmPassword,
    required String inviteToken,
    required String fullName,
    required String phone,
    required String displayName,
    required String baseLocationText,
    required List<String> skills,
  });
}

class MemoryAuthRepository implements AuthRepository {
  Session? _session;

  @override
  Future<void> clearSession() async {
    _session = null;
  }

  @override
  Future<Session?> getSession() async => _session;

  @override
  Future<void> saveSession(Session session) async {
    _session = session;
  }

  @override
  Future<Session> login({
    required String email,
    required String password,
    required UserRole roleHint,
  }) async {
    final s = Session(
        email: email, role: roleHint, displayName: email.split('@').first);
    await saveSession(s);
    return s;
  }

  @override
  Future<void> logout({String? accessToken, String? refreshToken}) async {
    await clearSession();
  }

  @override
  Future<void> deleteAccount({
    required String accessToken,
    required String password,
  }) async {
    await clearSession();
  }

  @override
  Future<Session> mergeSessionFromAuthBody(
    Map<String, dynamic> body, {
    required UserRole roleHint,
  }) async {
    final current = _session;
    final email = current?.email ?? 'merged@truckfix.app';
    final s = Session(
      email: email,
      role: roleHint,
      displayName: current?.displayName,
      accessToken: current?.accessToken,
      refreshToken: current?.refreshToken,
    );
    await saveSession(s);
    return s;
  }

  @override
  Future<ForgotPasswordResult> forgotPassword({required String email}) async {
    return ForgotPasswordResult(
      message: 'If an account exists for this email, password reset instructions have been sent.',
    );
  }

  @override
  Future<Session> registerFleetOperator({
    required String companyName,
    required String contactPerson,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final s = Session(
      email: email,
      role: UserRole.fleet,
      displayName: contactPerson.trim(),
    );
    await saveSession(s);
    return s;
  }

  @override
  Future<void> registerServiceProvider({
    required String email,
    required String password,
    required String confirmPassword,
    required String fullName,
    required String phone,
    required String businessType,
    String? displayName,
    String? businessName,
    String? companyName,
    String? baseLocationText,
    String? basePostcode,
    num? hourlyRate,
    num? emergencyRate,
    num? emergencySurcharge,
    num? callOutFee,
    String? rateCurrency,
    num? coverageRadius,
    String? profilePhotoUrl,
    String? profilePhotoPath,
    List<String>? skills,
  }) async {
    // No-op for prototype mode.
  }

  @override
  Future<Session> registerMechanicEmployee({
    required String email,
    required String password,
    required String confirmPassword,
    required String inviteToken,
    required String fullName,
    required String phone,
    required String displayName,
    required String baseLocationText,
    required List<String> skills,
  }) async {
    final s = Session(
      email: email,
      role: UserRole.employee,
      displayName: displayName.trim().isNotEmpty ? displayName.trim() : fullName.trim(),
    );
    await saveSession(s);
    return s;
  }
}

abstract class JobRepository {
  List<JobOffer> mechanicJobsNearby();
  List<MechanicQuote> postedQuotes();
  List<FleetJobSummary> fleetActiveJobs();
  List<Vehicle> fleetVehicles();
  List<TeamMember> companyTeam();
}

class MemoryJobRepository implements JobRepository {
  @override
  List<TeamMember> companyTeam() => const [
        TeamMember(
          id: '1',
          name: 'James Cole',
          role: 'Lead Technician',
          email: 'james@swiftmechanics.co.uk',
          activeJobs: 2,
        ),
        TeamMember(
          id: '2',
          name: 'Alex Morgan',
          role: 'Roadside',
          email: 'alex@swiftmechanics.co.uk',
          activeJobs: 1,
        ),
      ];

  @override
  List<FleetJobSummary> fleetActiveJobs() => [
        FleetJobSummary(
          id: 'TF-8821',
          truck: 'Volvo FH · LD 882 TF',
          issue: 'Coolant leak · M6 northbound',
          status: 'EN ROUTE',
          urgency: 'HIGH',
          urgencyColorHex: 0xFFFB923C,
          urgencyBgHex: 0x33FB923C,
          statusColorHex: 0xFFFBBF24,
          statusBgHex: 0xFFFBBF24,
        ),
        FleetJobSummary(
          id: 'TF-8804',
          truck: 'Scania R450 · B12 XYZ',
          issue: 'Tyre replacement completed',
          status: 'ON SITE',
          urgency: 'MEDIUM',
          urgencyColorHex: 0xFFFBBF24,
          urgencyBgHex: 0x33FBBF24,
          statusColorHex: 0xFF4ADE80,
          statusBgHex: 0xFF4ADE80,
        ),
      ];

  @override
  List<Vehicle> fleetVehicles() => const [
        Vehicle(
          id: 'fv1',
          label: 'MAN TGX 18.640',
          plate: 'CA 456-789',
          type: 'Tautliner',
          categoryBadge: 'TAUTLINER',
          lastService: '15 Jan 2025',
          photoUrl: AppAssets.fleetVehicleThumb1,
          photoUrlSecondary: AppAssets.fleetVehicleSecondary1,
        ),
        Vehicle(
          id: 'fv2',
          label: 'Mercedes-Benz Actros 2545',
          plate: 'GP 331-876',
          type: 'Rigid',
          categoryBadge: 'RIGID 8T',
          lastService: '3 Feb 2025',
          photoUrl: AppAssets.fleetVehicleThumb2,
          photoUrlSecondary: AppAssets.fleetVehicleSecondary2,
        ),
        Vehicle(
          id: 'fv3',
          label: 'Volvo FH16 750',
          plate: 'KZN 44-221',
          type: 'Tanker',
          categoryBadge: 'TANKER',
          lastService: '28 Dec 2024',
          photoUrl: AppAssets.fleetVehicleThumb3,
          photoUrlSecondary: AppAssets.fleetVehicleSecondary3,
        ),
      ];

  @override
  List<JobOffer> mechanicJobsNearby() => JobFeedMock.mechanicNearby();

  @override
  List<MechanicQuote> postedQuotes() => [
        MechanicQuote(
          id: 'q1',
          name: 'James Mitchell',
          rating: 4.8,
          jobs: 211,
          verified: true,
          distance: '4.2 km',
          eta: '12 min',
          imageUrl: AppAssets.mechanicPortrait,
          labour: '£85',
          callout: '£35',
          parts: '£25',
          total: '£145',
          speciality: 'Tyres & Suspension',
          responded: '2 min ago',
        ),
        MechanicQuote(
          id: 'q2',
          name: 'Tom Stevens',
          rating: 4.7,
          jobs: 163,
          verified: true,
          distance: '7.8 km',
          eta: '22 min',
          imageUrl: AppAssets.mechanicPortrait,
          labour: '£80',
          callout: '£35',
          parts: '£20',
          total: '£135',
          speciality: 'Tyres & Axles',
          responded: '5 min ago',
        ),
        MechanicQuote(
          id: 'q3',
          name: 'Paul Davies',
          rating: 4.5,
          jobs: 98,
          verified: false,
          distance: '11 km',
          eta: '31 min',
          imageUrl: AppAssets.mechanicPortrait,
          labour: '£70',
          callout: '£30',
          parts: '£18',
          total: '£118',
          speciality: 'General HGV',
          responded: '9 min ago',
        ),
      ];
}
