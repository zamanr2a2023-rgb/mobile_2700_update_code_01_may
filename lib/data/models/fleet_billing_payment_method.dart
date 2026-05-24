/// One saved payment method from `GET /api/v1/billing/payment-methods`.
class FleetBillingPaymentMethod {
  const FleetBillingPaymentMethod({
    required this.id,
    required this.methodType,
    required this.displayBrand,
    required this.last4,
    required this.expiryLabel,
    required this.isDefault,
    required this.isActive,
    this.displayLabel,
  });

  final String id;
  final String methodType; // CARD | BANK | …
  /// Card brand for display, e.g. "Visa".
  final String displayBrand;
  /// Last four digits (cards) or short tail for other types.
  final String last4;
  /// e.g. `12/30` for Dec 2030.
  final String expiryLabel;
  final bool isDefault;
  final bool isActive;
  final String? displayLabel;

  static FleetBillingPaymentMethod? maybeFromJson(Map<String, dynamic> json) {
    final id = ((json['_id'] as String?) ?? '').trim();
    if (id.isEmpty) return null;

    final methodType = ((json['methodType'] as String?) ?? 'CARD').trim();
    final isDefault = json['isDefault'] == true;
    final isActive = json['isActive'] != false;
    final label = (json['displayLabel'] as String?)?.trim();

    final card = json['card'];
    if (card is Map<String, dynamic>) {
      final brandRaw = ((card['brand'] as String?) ?? 'Card').trim();
      final displayBrand = _titleCaseBrand(brandRaw);
      final last4Raw = ((card['last4'] as String?) ?? '').trim();
      final last4 = last4Raw.isEmpty
          ? '••••'
          : (last4Raw.length > 4 ? last4Raw.substring(last4Raw.length - 4) : last4Raw);
      final expM = card['expMonth'];
      final expY = card['expYear'];
      final month = expM is num ? expM.toInt() : int.tryParse(expM?.toString() ?? '') ?? 0;
      var year = expY is num ? expY.toInt() : int.tryParse(expY?.toString() ?? '') ?? 0;
      if (year > 99) year %= 100;
      final expiryLabel = (month >= 1 && month <= 12 && year > 0)
          ? '${month.toString().padLeft(2, '0')}/${year.toString().padLeft(2, '0')}'
          : '—';

      return FleetBillingPaymentMethod(
        id: id,
        methodType: methodType,
        displayBrand: displayBrand,
        last4: last4,
        expiryLabel: expiryLabel,
        isDefault: isDefault,
        isActive: isActive,
        displayLabel: label,
      );
    }

    final bank = json['bank'];
    if (bank is Map<String, dynamic>) {
      final masked = ((bank['accountMasked'] as String?) ?? label ?? 'Account').trim();
      final last4 = masked.length >= 4 ? masked.substring(masked.length - 4) : masked;
      final bankName = ((bank['bankName'] as String?) ?? 'Bank').trim();
      return FleetBillingPaymentMethod(
        id: id,
        methodType: methodType,
        displayBrand: _titleCaseBrand(bankName),
        last4: last4,
        expiryLabel: '—',
        isDefault: isDefault,
        isActive: isActive,
        displayLabel: label,
      );
    }

    final fallback = label ?? methodType;
    return FleetBillingPaymentMethod(
      id: id,
      methodType: methodType,
      displayBrand: _titleCaseBrand(fallback.split(' ').first),
      last4: '----',
      expiryLabel: '—',
      isDefault: isDefault,
      isActive: isActive,
      displayLabel: label,
    );
  }

  static String _titleCaseBrand(String raw) {
    if (raw.isEmpty) return 'Card';
    return raw
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
