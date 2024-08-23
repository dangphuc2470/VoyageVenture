import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:voyageventure/models/fetch_photo_url.dart';

@GenerateMocks([http.Client])
import 'fetch_photo_url_test.mocks.dart';
import 'test_photo_url.mocks.dart';

Future<void> main() async {
  String fetchPhotoResponse = '''
        
{
  "photos": [
    {
      "name": "places/ChIJN1t_tDeuEmsRUsoyG83frY4/photos/AelY_Cu8zls_7xXHnIfDzV7zK54MskJoB0j4HX_XNZ392Qch2S0264Pqpikp1Y5JYwRYV-Z-POSZ7GgU7DMBLyGL81lsPlLLbuwyaNk-HRVr16_MsZviU1F8Ax2xEqLnUXu0mfgtFtiRJom3SToHzdbLHa1VQpS--VUI7z5O",
      "widthPx": 4032,
      "heightPx": 3024,
      "authorAttributions": [
        {
          "displayName": "Matty B",
          "uri": "//maps.google.com/maps/contrib/104641095422852249098",
          "photoUri": "//lh3.googleusercontent.com/a-/ALV-UjWk8qO_qslrJAsU8AckTpNvL7ovyWJ4Xz7cMzI6Oabnbet38tAQSw=s100-p-k-no-mo"
        }
      ]
    },
    {
      "name": "places/ChIJN1t_tDeuEmsRUsoyG83frY4/photos/AelY_CukClWccyWMeWoNb4PsUUs9ozbWE2wuWcwWXoP1YwZ9h5DZ3T9diRrNlVkl_yi87QuMn0Lcw5ar-YatAh9K74Fgs322cEtsruB78TqXe00KDzWa21Zj0JTcRGC4ZyKbnZWeLbjtsOhmC4P8FGJJtWr0UaIfTRZ8RXlk",
      "widthPx": 4032,
      "heightPx": 3024,
      "authorAttributions": [
        {
          "displayName": "Matty B",
          "uri": "//maps.google.com/maps/contrib/104641095422852249098",
          "photoUri": "//lh3.googleusercontent.com/a-/ALV-UjWk8qO_qslrJAsU8AckTpNvL7ovyWJ4Xz7cMzI6Oabnbet38tAQSw=s100-p-k-no-mo"
        }
      ]
    }
  ]
}
    
  
  ''';
  // Read string response from lib/API_response_template/OldPlaceAutocomplete.json
  String placeAutocompleteResponse = await rootBundle.loadString('lib/API_response_template/PlaceAutocomplete.json');
  String placeSearchResponse = await rootBundle.loadString('lib/API_response_template/PlaceSearch.json');
  String placeRouteResponse = await rootBundle.loadString('lib/API_response_template/RouteNew.json');


  group('fetchPhotoUrls', () {
    test('returns an image url if the http call completes successfully', () async {
      final client = MockClient();

      dotenv.testLoad(fileInput: '''
          MAPS_API_KEY1=test_api_key
      '''
      );

      when(client.get(Uri.parse('https://places.googleapis.com/v1/places/ChIJN1t_tDeuEmsRUsoyG83frY4?fields=photos&key=${dotenv.env['MAPS_API_KEY1']}')))
          .thenAnswer((_) async => http.Response(fetchPhotoResponse, 200));
      //
      // Map<String, dynamic> jsonMap = jsonDecode(jsonResponse);
      // List<dynamic> photos = jsonMap['photos'];
      // List<String> photoUrls = photos.map((photo) => photo['name'] as String).toList();
      //

      expect(await fetchPhotoUrls("ChIJN1t_tDeuEmsRUsoyG83frY4", client), isA<List<String>>());
    });

    test('throw an exception if the http call fails', () async
    {
      final client = MockClient();

      dotenv.testLoad(fileInput: '''
          MAPS_API_KEY1=test_api_key
      '''
      );

      when(client.get(Uri.parse('https://places.googleapis.com/v1/places/ChIJN1t_tDeuEmsRUsoyG83frY4?fields=photos&key=${dotenv.env['MAPS_API_KEY1']}')))
          .thenAnswer((_) async => http.Response('Not Found', 404));

      expect(fetchPhotoUrls("ChIJN1t_tDeuEmsRUsoyG83frY4", client), throwsException);
    });

  });

}