import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class NightEqualizerState {
  const NightEqualizerState({
    required this.supported,
    required this.enabled,
    required this.minimumGain,
    required this.maximumGain,
    required this.frequencies,
    required this.gains,
  });

  const NightEqualizerState.unsupported()
    : supported = false,
      enabled = false,
      minimumGain = -12,
      maximumGain = 12,
      frequencies = const [60, 250, 1000, 4000, 12000],
      gains = const [0, 0, 0, 0, 0];

  final bool supported;
  final bool enabled;
  final double minimumGain;
  final double maximumGain;
  final List<double> frequencies;
  final List<double> gains;

  NightEqualizerState copyWith({bool? enabled, List<double>? gains}) => NightEqualizerState(
    supported: supported,
    enabled: enabled ?? this.enabled,
    minimumGain: minimumGain,
    maximumGain: maximumGain,
    frequencies: frequencies,
    gains: gains ?? this.gains,
  );
}

class NightAudioService {
  NightAudioService._();

  static final instance = NightAudioService._();

  static const _spectrumChannel = EventChannel('finamp/night_audio/spectrum');
  static const _controlChannel = MethodChannel('finamp/night_audio/control');
  static const _enabledPreference = 'night_equalizer_enabled';
  static String _gainPreference(int index) => 'night_equalizer_gain_$index';

  final equalizer = ValueNotifier<NightEqualizerState>(const NightEqualizerState.unsupported());
  Stream<List<double>>? _spectrum;
  Future<void>? _initialization;

  Stream<List<double>> get spectrum {
    if (!Platform.isIOS) return const Stream.empty();
    return _spectrum ??= _spectrumChannel
        .receiveBroadcastStream()
        .map((event) {
          final values = (event as List<Object?>)
              .whereType<num>()
              .map((value) => value.toDouble().clamp(0, 1))
              .toList();
          return List<double>.unmodifiable(values);
        })
        .handleError((Object _) {});
  }

  Future<void> ensureInitialized() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!Platform.isIOS) return;
    try {
      final raw = await _controlChannel.invokeMapMethod<String, Object?>('getEqualizer');
      if (raw == null || raw['supported'] != true) return;

      final frequencies = (raw['frequencies'] as List<Object?>)
          .whereType<num>()
          .map((value) => value.toDouble())
          .toList();
      final nativeGains = (raw['gains'] as List<Object?>).whereType<num>().map((value) => value.toDouble()).toList();
      final preferences = await SharedPreferences.getInstance();
      final gains = List<double>.generate(
        nativeGains.length,
        (index) => preferences.getDouble(_gainPreference(index)) ?? nativeGains[index],
      );
      final enabled = preferences.getBool(_enabledPreference) ?? (raw['enabled'] as bool? ?? false);

      equalizer.value = NightEqualizerState(
        supported: true,
        enabled: enabled,
        minimumGain: (raw['minimumGain'] as num).toDouble(),
        maximumGain: (raw['maximumGain'] as num).toDouble(),
        frequencies: List<double>.unmodifiable(frequencies),
        gains: List<double>.unmodifiable(gains),
      );

      await _controlChannel.invokeMethod<void>('setEqualizerEnabled', {'enabled': enabled});
      for (var index = 0; index < gains.length; index++) {
        await _controlChannel.invokeMethod<void>('setEqualizerBand', {'index': index, 'gain': gains[index]});
      }
    } on MissingPluginException {
      // Equalizer is intentionally hidden on unsupported platforms.
    } on PlatformException {
      // A failed native effect must never interrupt playback startup.
    }
  }

  Future<void> setEnabled(bool enabled) async {
    await ensureInitialized();
    final current = equalizer.value;
    if (!current.supported) return;
    equalizer.value = current.copyWith(enabled: enabled);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledPreference, enabled);
    await _controlChannel.invokeMethod<void>('setEqualizerEnabled', {'enabled': enabled});
  }

  Future<void> setBandGain(int index, double gain) async {
    await ensureInitialized();
    final current = equalizer.value;
    if (!current.supported || index < 0 || index >= current.gains.length) return;
    final clamped = gain.clamp(current.minimumGain, current.maximumGain);
    final gains = [...current.gains]..[index] = clamped;
    equalizer.value = current.copyWith(gains: List<double>.unmodifiable(gains));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_gainPreference(index), clamped);
    await _controlChannel.invokeMethod<void>('setEqualizerBand', {'index': index, 'gain': clamped});
  }

  Future<void> applyPreset(List<double> gains) async {
    await ensureInitialized();
    final count = gains.length.clamp(0, equalizer.value.gains.length);
    for (var index = 0; index < count; index++) {
      await setBandGain(index, gains[index]);
    }
  }

  Future<void> reset() async {
    await ensureInitialized();
    final current = equalizer.value;
    if (!current.supported) return;
    final gains = List<double>.filled(current.gains.length, 0);
    equalizer.value = current.copyWith(gains: List<double>.unmodifiable(gains));
    final preferences = await SharedPreferences.getInstance();
    for (var index = 0; index < gains.length; index++) {
      await preferences.setDouble(_gainPreference(index), 0);
    }
    await _controlChannel.invokeMethod<void>('resetEqualizer');
  }
}
