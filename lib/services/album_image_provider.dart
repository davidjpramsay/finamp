import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:file/file.dart' as cache;
import 'package:finamp/services/theme_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import '../models/jellyfin_models.dart';
import 'downloads_service.dart';
import 'finamp_settings_helper.dart';
import 'jellyfin_api_helper.dart';

final albumImageProviderLogger = Logger("AlbumImageProvider");

class AlbumImageRequest {
  const AlbumImageRequest({required this.item, this.maxWidth, this.maxHeight});

  final BaseItemDto item;

  final int? maxWidth;

  final int? maxHeight;

  bool get fullQuality => maxWidth == null && maxHeight == null;

  @override
  bool operator ==(Object other) {
    return other is AlbumImageRequest &&
        other.maxHeight == maxHeight &&
        other.maxWidth == maxWidth &&
        other.item.id == item.id;
  }

  @override
  int get hashCode => Object.hash(item.id, maxHeight, maxWidth);
}

final Map<String?, AlbumImageRequest> albumRequestsCache = {};

// Keep only recently used player images in memory. Other files remain available
// through flutter_cache_manager and are loaded lazily instead of being scanned at startup.
final LinkedHashMap<String, FileInfo> _playerImageCache = LinkedHashMap();
const _playerImageCacheLimit = 32;

final _imageCache = DefaultCacheManager();

const _infiniteHeight = 999999;

FileInfo? _getMemoryCachedImage(String key) {
  final entry = _playerImageCache.remove(key);
  if (entry == null || !entry.validTill.isAfter(DateTime.now()) || !entry.file.existsSync()) {
    return null;
  }
  _playerImageCache[key] = entry;
  return entry;
}

void _rememberPlayerImage(String key, FileInfo file) {
  _playerImageCache.remove(key);
  _playerImageCache[key] = file;
  while (_playerImageCache.length > _playerImageCacheLimit) {
    _playerImageCache.remove(_playerImageCache.keys.first);
  }
}

final albumImageProvider = StateNotifierProvider.autoDispose
    .family<AlbumImageController, AlbumImageInfo, AlbumImageRequest>((ref, request) {
      String? requestCacheKey = request.item.blurHash ?? request.item.imageId;
      // We currently only support square image requests
      assert(request.maxWidth == request.maxHeight);
      if (albumRequestsCache.containsKey(requestCacheKey)) {
        final cacheRequestHeight = albumRequestsCache[requestCacheKey]!.maxHeight;
        if ((request.maxHeight ?? _infiniteHeight) > (cacheRequestHeight ?? _infiniteHeight)) {
          albumRequestsCache[requestCacheKey] = request;
        }
      } else {
        albumRequestsCache[requestCacheKey] = request;
      }
      ref.onDispose(() {
        if (albumRequestsCache.containsKey(requestCacheKey)) {
          if (albumRequestsCache[requestCacheKey] == request) {
            albumRequestsCache.remove(requestCacheKey);
          }
        }
      });

      final initial = _resolveAlbumImage(ref, request);
      return AlbumImageController(
        request: request,
        initial: initial.$1,
        imageUrl: initial.$2,
        key: initial.$3,
        blurhashKey: initial.$4,
      );
    });

(AlbumImageInfo, Uri?, String?, bool) _resolveAlbumImage(Ref ref, AlbumImageRequest request) {
  if (request.item.imageId == null) {
    return (AlbumImageInfo.empty(request), null, null, false);
  }

  final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();
  final isardownloader = GetIt.instance<DownloadsService>();

  File? downloadedImage = isardownloader.getImageDownload(item: request.item)?.file;

  String key;
  bool blurhashKey = false;
  if (request.item.blurHash != null) {
    key = request.item.blurHash! + request.maxWidth.toString() + request.maxHeight.toString();
    blurhashKey = true;
  } else {
    key = request.item.imageId! + request.maxWidth.toString() + request.maxHeight.toString();
  }

  if (downloadedImage == null) {
    final cacheEntry = _getMemoryCachedImage(key);
    if (cacheEntry != null) {
      downloadedImage = cacheEntry.file;
    }
  }

  if (downloadedImage == null) {
    if (ref.watch(finampSettingsProvider.isOffline)) {
      return (AlbumImageInfo.empty(request), null, key, blurhashKey);
    }

    // TODO maybe we can reuse cached player images or existing sufficiently larger image requests instead of fetching from server

    Uri? imageUrl;

    if (request.fullQuality) {
      imageUrl = jellyfinApiHelper.getImageUrl(item: request.item, quality: null, format: null);
    } else {
      imageUrl = jellyfinApiHelper.getImageUrl(
        item: request.item,
        maxWidth: request.maxWidth,
        maxHeight: request.maxHeight,
      );
    }

    if (imageUrl == null) {
      return (AlbumImageInfo.empty(request), null, key, blurhashKey);
    }

    if (request.fullQuality) {
      return (AlbumImageInfo(null, request, null, fullQuality: true), imageUrl, key, blurhashKey);
    } else {
      // Allow drawing albums up to 4X intrinsic size by setting scale
      return (
        AlbumImageInfo(
          CachedImage(NetworkImage(imageUrl.toString(), scale: 0.25), key),
          request,
          imageUrl,
          fullQuality: request.fullQuality,
        ),
        null,
        key,
        blurhashKey,
      );
    }
  }

  // downloads are already de-dupped by blurHash and do not need CachedImage
  // Allow drawing albums up to 4X intrinsic size by setting scale
  ImageProvider out = FileImage(downloadedImage, scale: 0.25);
  if (!request.fullQuality) {
    // Limit memory cached image size to twice displayed size
    // This helps keep cache usage by fileImages in check
    // Caching smaller at 2X size results in blurriness comparable to
    // NetworkImages fetched with display size
    out = ResizeImage(out, width: request.maxWidth! * 2, height: request.maxHeight! * 2, policy: ResizeImagePolicy.fit);
  }
  return (
    AlbumImageInfo(out, request, Uri.file(downloadedImage.path), fullQuality: request.fullQuality),
    null,
    key,
    blurhashKey,
  );
}

class AlbumImageController extends StateNotifier<AlbumImageInfo> {
  AlbumImageController({
    required this.request,
    required AlbumImageInfo initial,
    required Uri? imageUrl,
    required String? key,
    required bool blurhashKey,
  }) : super(initial) {
    if (imageUrl != null && key != null) {
      unawaited(_loadFullQualityImage(imageUrl, key, blurhashKey));
    }
  }

  final AlbumImageRequest request;

  Future<void> _loadFullQualityImage(Uri imageUrl, String key, bool blurhashKey) async {
    try {
      var imageFile = _getMemoryCachedImage(key) ?? await _imageCache.getFileFromCache(key);
      final cachedFileIsValid =
          imageFile != null && imageFile.validTill.isAfter(DateTime.now()) && imageFile.file.existsSync();
      if (!cachedFileIsValid) {
        imageFile = await _imageCache.downloadFile(imageUrl.toString(), key: key);
        if (blurhashKey) {
          // Images addressed by blurhash are immutable, so retain them longer.
          var cacheObject = await _imageCache.store.retrieveCacheData(key);
          if (cacheObject != null) {
            cacheObject = cacheObject.copyWith(validTill: DateTime.now().add(const Duration(days: 365)));
            await _imageCache.store.putFile(cacheObject);
          }
        }
      }
      _rememberPlayerImage(key, imageFile!);
      _publish(
        AlbumImageInfo(
          FileImage(imageFile.file, scale: 0.25),
          request,
          Uri.file(imageFile.file.path),
          fullQuality: true,
        ),
      );
    } catch (error, stackTrace) {
      albumImageProviderLogger.warning("Failed to load full-quality artwork for ${request.item.id}", error, stackTrace);
    }
  }

  void _publish(AlbumImageInfo image) {
    if (!mounted) return;
    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    if (schedulerPhase == SchedulerPhase.idle || schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      state = image;
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) state = image;
    });
  }
}

class CachedImage extends ImageProvider<CachedImage> {
  CachedImage(ImageProvider base, this.cacheKey) : _base = base;

  final ImageProvider _base;

  final String? cacheKey;

  double get scale => switch (_base) {
    NetworkImage() => _base.scale,
    FileImage() => _base.scale,
    _ => throw UnsupportedError("Unsupported base image provider $_base"),
  };

  String get location => switch (_base) {
    NetworkImage() => _base.url,
    FileImage() => _base.file.path,
    _ => throw UnsupportedError("Unsupported base image provider $_base"),
  };

  @override
  ImageStreamCompleter loadBuffer(CachedImage key, DecoderBufferCallback decode) => _base.loadBuffer(key._base, decode);

  @override
  ImageStreamCompleter loadImage(CachedImage key, ImageDecoderCallback decode) => _base.loadImage(key._base, decode);

  @override
  Future<CachedImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture<CachedImage>(this);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    if (cacheKey != null) {
      return other is CachedImage && other.cacheKey == cacheKey && other.scale == scale;
    }
    return other is CachedImage && other.location == location && other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(cacheKey ?? location, scale);

  @override
  String toString() => 'CachedImage("$location", scale: ${scale.toStringAsFixed(1)})';
}

@immutable
class AlbumImageInfo extends FinampImage {
  const AlbumImageInfo(super.image, this.albumRequest, this.uri, {required super.fullQuality});

  const AlbumImageInfo.empty(this.albumRequest) : uri = null, super(null, fullQuality: true);

  final AlbumImageRequest albumRequest;

  final Uri? uri;

  FinampThemeImage asTheme(ThemeInfo themeRequest) => FinampThemeImage(image, themeRequest, fullQuality: fullQuality);

  @override
  BaseItemDto get item => albumRequest.item;
}

/// This cache implementation does nothing but throw errors.  It is fed to audio service, which should not try to use
/// it due to our player image caching logic.  audio service cannot deduplicate images by blurhash, so we should
/// avoid feeding it network images directly.
class StubImageCache implements BaseCacheManager {
  @override
  Future<void> dispose() {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<FileInfo> downloadFile(String url, {String? key, Map<String, String>? authHeaders, bool force = false}) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<void> emptyCache() {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Stream<FileInfo> getFile(String url, {String? key, Map<String, String>? headers}) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<FileInfo?> getFileFromCache(String key, {bool ignoreMemCache = false}) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<FileInfo?> getFileFromMemory(String key) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Stream<FileResponse> getFileStream(String url, {String? key, Map<String, String>? headers, bool? withProgress}) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<cache.File> getSingleFile(String url, {String? key, Map<String, String>? headers}) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<cache.File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<cache.File> putFileStream(
    String url,
    Stream<List<int>> source, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) {
    throw UnsupportedError("This cache should not be used");
  }

  @override
  Future<void> removeFile(String key) {
    throw UnsupportedError("This cache should not be used");
  }
}
