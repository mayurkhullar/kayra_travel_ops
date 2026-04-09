String sanitizeTravellerPhone(String phone) {
  return phone.replaceAll(RegExp(r'\D'), '');
}

String mapTravellerPhoneToAuthEmail(String phone) {
  final sanitizedPhone = sanitizeTravellerPhone(phone);
  if (sanitizedPhone.isEmpty) {
    throw const TravellerIdentityMapperException('Enter a valid mobile number.');
  }
  return '$sanitizedPhone@traveller.kayra.local';
}

class TravellerIdentityMapperException implements Exception {
  const TravellerIdentityMapperException(this.message);

  final String message;

  @override
  String toString() => message;
}
