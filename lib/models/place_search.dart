class PlaceSearch_ {
  final String? id;
  final String? formattedAddress;
  final Location location;
  final DisplayName? displayName;

  PlaceSearch_({
    this.id,
    this.formattedAddress,
    required this.location,
    this.displayName,
  });

  @override
  String toString()
  {
    return 'PlaceSearch_ { id: $id, formattedAddress: $formattedAddress, location: ${location.toString()}, displayName: $displayName }';
  }

  factory PlaceSearch_.fromJson(Map<String, dynamic> json) {
    return PlaceSearch_(
      id: json['id'] as String?,
      formattedAddress: json['formattedAddress'] as String?,
      location: Location.fromJson(json['location']),
      displayName: json['displayName'] != null
          ? DisplayName.fromJson(json['displayName'])
          : null,
    );
  }
}

class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
    );
  }

  @override
  String toString() {
    return 'Location { latitude: $latitude, longitude: $longitude }';
  }
}

class DisplayName {
  final String? text;
  final String? languageCode;

  DisplayName({this.text, this.languageCode});

  factory DisplayName.fromJson(Map<String, dynamic> json) {
    return DisplayName(
      text: json['text'] as String?,
      languageCode: json['languageCode'] as String?,
    );
  }

  @override
  String toString() {
    return 'DisplayName { text: $text, languageCode: $languageCode }';
  }
}