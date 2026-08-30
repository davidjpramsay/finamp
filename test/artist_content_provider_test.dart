import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/artist_content_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('trackContainsArtist', () {
    final requestedArtist = BaseItemId('requested-artist');

    test('matches the requested performing artist', () {
      final track = BaseItemDto(
        id: BaseItemId('track'),
        artistItems: [
          NameIdPair(id: BaseItemId('other-artist')),
          NameIdPair(id: requestedArtist),
        ],
      );

      expect(trackContainsArtist(track, requestedArtist), isTrue);
    });

    test('does not match a different or missing artist', () {
      final differentArtistTrack = BaseItemDto(
        id: BaseItemId('track'),
        artistItems: [NameIdPair(id: BaseItemId('other-artist'))],
      );
      final trackWithoutArtists = BaseItemDto(id: BaseItemId('track-without-artists'));

      expect(trackContainsArtist(differentArtistTrack, requestedArtist), isFalse);
      expect(trackContainsArtist(trackWithoutArtists, requestedArtist), isFalse);
    });
  });
}
