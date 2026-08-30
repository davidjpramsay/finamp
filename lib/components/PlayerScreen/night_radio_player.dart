import 'dart:async';
import 'dart:math';

import 'package:finamp/components/AddToPlaylistScreen/add_to_playlist_button.dart';
import 'package:finamp/components/PlayerScreen/player_buttons_more.dart';
import 'package:finamp/components/album_image.dart';
import 'package:finamp/components/print_duration.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/process_artist.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/night_audio_service.dart';
import 'package:finamp/theme/night_radio_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

/// Shared visual language for the technical, low-glare player surfaces.
class NightRadioPanel extends StatelessWidget {
  const NightRadioPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: clipBehavior,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: NightRadioColors.violet.withValues(alpha: 0.34), width: 0.8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(NightRadioColors.violet.withValues(alpha: 0.08), const Color(0xFA101219)),
            const Color(0xFA080A0E),
          ],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x77000000), blurRadius: 18, offset: Offset(0, 8)),
          BoxShadow(color: Color(0x1FA970FF), blurRadius: 14),
        ],
      ),
      child: child,
    );
  }
}

class NightRadioSectionLabel extends StatelessWidget {
  const NightRadioSectionLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color ?? Theme.of(context).colorScheme.primary,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w700,
        letterSpacing: 1.7,
        height: 1.1,
      ),
    );
  }
}

/// Compact metadata block used by both portrait and landscape player decks.
class NightRadioTrackDetails extends ConsumerWidget {
  const NightRadioTrackDetails({super.key, this.compact = false});

  final bool compact;

  MediaStream? _audioStream(BaseItemDto item) {
    for (final stream in item.mediaStreams ?? const <MediaStream>[]) {
      if (stream.type.toLowerCase() == 'audio') return stream;
    }
    return null;
  }

  String _sampleRateLabel(int sampleRate) {
    final value = sampleRate / 1000;
    return '${value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} kHz';
  }

  List<String> _formatDetails(BaseItemDto item) {
    final stream = _audioStream(item);
    return <String>[
      if (stream?.codec?.isNotEmpty ?? false) stream!.codec!.toUpperCase(),
      if (stream?.sampleRate != null) _sampleRateLabel(stream!.sampleRate!),
      if (stream?.bitDepth != null) '${stream!.bitDepth} bit',
      if (stream?.bitRate != null && stream!.bitRate! > 0) '${(stream.bitRate! / 1000).round()} kbps',
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(QueueService.queueProvider);
    final currentTrack = queue?.currentTrack;
    if (currentTrack == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    final baseItem = currentTrack.baseItem;
    final formatDetails = _formatDetails(baseItem);
    final colors = Theme.of(context).colorScheme;
    final titleStyle = (compact ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.titleLarge)
        ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.25, height: 1.08);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: NightRadioSectionLabel('Now Playing')),
            if (queue != null)
              Text(
                '${queue.currentTrackIndex} / ${queue.trackCount}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.58),
                  fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
        SizedBox(height: compact ? 6 : 9),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentTrack.item.title,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    processArtist(currentTrack.item.artist, context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!compact && (baseItem.album?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 2),
                    Text(
                      baseItem.album!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.52)),
                    ),
                  ],
                ],
              ),
            ),
            IconTheme(
              data: IconThemeData(color: colors.onSurface.withValues(alpha: 0.82), size: compact ? 20 : 22),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayerButtonsMore(item: baseItem, queueItem: currentTrack),
                  AddToPlaylistButton(item: baseItem, queueItem: currentTrack),
                ],
              ),
            ),
          ],
        ),
        if (!compact && formatDetails.isNotEmpty) ...[
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: formatDetails.take(4).map((detail) => _TechnicalBadge(detail)).toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _TechnicalBadge extends StatelessWidget {
  const _TechnicalBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSurface.withValues(alpha: 0.7),
          fontFamily: 'monospace',
          fontSize: 10,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

/// An audio-driven FFT display supplied by the native playback pipeline.
///
/// There is deliberately no animation ticker or synthetic fallback here: when
/// the audio is silent, paused, or unsupported, the display shows no signal.
class NightRadioVisualizer extends StatefulWidget {
  const NightRadioVisualizer({super.key, required this.active, this.height = 44});

  final bool active;
  final double height;

  @override
  State<NightRadioVisualizer> createState() => _NightRadioVisualizerState();
}

class _NightRadioVisualizerState extends State<NightRadioVisualizer> {
  static const _emptyLevels = <double>[
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ];

  StreamSubscription<List<double>>? _subscription;
  List<double> _levels = _emptyLevels;

  @override
  void initState() {
    super.initState();
    _subscription = NightAudioService.instance.spectrum.listen((levels) {
      if (!mounted || levels.isEmpty) return;
      setState(() => _levels = levels);
    });
  }

  @override
  void didUpdateWidget(covariant NightRadioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && oldWidget.active) setState(() => _levels = _emptyLevels);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _NightRadioVisualizerPainter(
            levels: widget.active ? _levels : _emptyLevels,
            primary: NightRadioColors.violet,
            secondary: NightRadioColors.cyan,
          ),
        ),
      ),
    );
  }
}

class _NightRadioVisualizerPainter extends CustomPainter {
  const _NightRadioVisualizerPainter({required this.levels, required this.primary, required this.secondary});

  final List<double> levels;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final barCount = levels.length;
    if (barCount == 0) return;
    const gap = 2.0;
    final barWidth = max(1.2, (size.width - gap * (barCount - 1)) / barCount);
    final baselinePaint = Paint()..color = primary.withValues(alpha: 0.16);
    final gridPaint = Paint()
      ..color = NightRadioColors.outline.withValues(alpha: 0.38)
      ..strokeWidth = 0.5;
    final barPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [primary.withValues(alpha: 0.82), secondary, NightRadioColors.amber],
        stops: const [0, 0.76, 1],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Rect.fromLTWH(0, size.height - 1, size.width, 1), baselinePaint);
    for (var division = 1; division < 4; division++) {
      final y = size.height * division / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var index = 0; index < barCount; index++) {
      final level = levels[index].clamp(0.0, 1.0);
      final barHeight = max(1.0, size.height * level);
      final x = index * (barWidth + gap);
      canvas.drawRect(Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight), barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NightRadioVisualizerPainter oldDelegate) =>
      oldDelegate.levels != levels || oldDelegate.primary != primary || oldDelegate.secondary != secondary;
}

class NightRadioSpectrumPanel extends StatelessWidget {
  const NightRadioSpectrumPanel({super.key, required this.active, this.height = 44});

  final bool active;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            NightRadioSectionLabel(active ? 'Live FFT // 38 Hz–18 kHz' : 'Signal Paused', color: NightRadioColors.cyan),
            const Spacer(),
            TextButton.icon(
              onPressed: () => showNightRadioEqualizer(context),
              icon: const Icon(Icons.tune_rounded, size: 15),
              label: const Text('EQ'),
              style: TextButton.styleFrom(
                foregroundColor: NightRadioColors.amber,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                minimumSize: const Size(48, 30),
                textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        NightRadioVisualizer(active: active, height: height),
      ],
    );
  }
}

Future<void> showNightRadioEqualizer(BuildContext context) async {
  await NightAudioService.instance.ensureInitialized();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _NightRadioEqualizerSheet(),
  );
}

class _NightRadioEqualizerSheet extends StatefulWidget {
  const _NightRadioEqualizerSheet();

  @override
  State<_NightRadioEqualizerSheet> createState() => _NightRadioEqualizerSheetState();
}

class _NightRadioEqualizerSheetState extends State<_NightRadioEqualizerSheet> {
  List<double>? _draftGains;

  String _frequency(double frequency) => frequency >= 1000
      ? '${(frequency / 1000).toStringAsFixed(frequency % 1000 == 0 ? 0 : 1)}K'
      : frequency.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ValueListenableBuilder<NightEqualizerState>(
        valueListenable: NightAudioService.instance.equalizer,
        builder: (context, state, _) {
          if (!state.supported) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(24, 6, 24, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NightRadioSectionLabel('Equalizer // unavailable'),
                  SizedBox(height: 12),
                  Text('The live equalizer is currently available in the Finamp Night iPhone audio engine.'),
                ],
              ),
            );
          }

          final gains = _draftGains ?? state.gains;
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const NightRadioSectionLabel('Five-band parametric EQ', color: NightRadioColors.amber),
                    const Spacer(),
                    Switch.adaptive(value: state.enabled, onChanged: NightAudioService.instance.setEnabled),
                  ],
                ),
                Text(
                  state.enabled ? 'DSP ONLINE // ±12 dB' : 'DSP BYPASSED // zero processing',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: state.enabled ? NightRadioColors.signal : NightRadioColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 224,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < gains.length; index++)
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '${gains[index] >= 0 ? '+' : ''}${gains[index].toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: NightRadioColors.cyan,
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              Expanded(
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: Slider(
                                    value: gains[index],
                                    min: state.minimumGain,
                                    max: state.maximumGain,
                                    divisions: 48,
                                    onChanged: state.enabled
                                        ? (value) => setState(() {
                                            _draftGains = [...gains]..[index] = value;
                                          })
                                        : null,
                                    onChangeEnd: (value) async {
                                      await NightAudioService.instance.setBandGain(index, value);
                                      if (mounted) setState(() => _draftGains = null);
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                _frequency(state.frequencies[index]),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: NightRadioColors.text),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _PresetButton(label: 'FLAT', gains: const [0, 0, 0, 0, 0]),
                    _PresetButton(label: 'WARM', gains: const [3, 2, 0, -1, -2]),
                    _PresetButton(label: 'PUNCH', gains: const [3, 1, -1, 2, 3]),
                    _PresetButton(label: 'AIR', gains: const [-1, 0, 1, 2, 3]),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({required this.label, required this.gains});

  final String label;
  final List<double> gains;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: () => NightAudioService.instance.applyPreset(gains), child: Text(label));
  }
}

/// Always-visible queue context for wide player layouts.
class NightRadioQueuePanel extends ConsumerWidget {
  const NightRadioQueuePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(QueueService.queueProvider);
    final queueService = GetIt.instance<QueueService>();
    final upcoming = queue == null ? const <FinampQueueItem>[] : <FinampQueueItem>[...queue.nextUp, ...queue.queue];
    final colors = Theme.of(context).colorScheme;

    return NightRadioPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
            child: Row(
              children: [
                Expanded(child: NightRadioSectionLabel(AppLocalizations.of(context)!.nextUp)),
                if (queue != null)
                  Text(
                    '${queue.upcomingTrackCount}  •  ${printDuration(queue.remainingDuration)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.55),
                      fontFamily: 'monospace',
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: colors.outline.withValues(alpha: 0.26)),
          Expanded(
            child: upcoming.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context)!.queue,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.45)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemExtent: 49,
                    itemCount: upcoming.length,
                    itemBuilder: (context, index) {
                      final item = upcoming[index];
                      return Semantics(
                        button: true,
                        label: '${index + 1}. ${item.item.title}, ${processArtist(item.item.artist, context)}',
                        child: InkWell(
                          onTap: () async => queueService.skipByOffset(index + 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  child: Text(
                                    '${index + 1}'.padLeft(2, '0'),
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: colors.primary.withValues(alpha: 0.8),
                                      fontFamily: 'monospace',
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: SizedBox.square(
                                    dimension: 36,
                                    child: AlbumImage(
                                      item: item.baseItem,
                                      sizePreset: 36,
                                      borderRadius: BorderRadius.zero,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        processArtist(item.item.artist, context),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: colors.onSurface.withValues(alpha: 0.48),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (item.item.duration != null)
                                  Text(
                                    printDuration(item.item.duration!),
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: colors.onSurface.withValues(alpha: 0.45),
                                      fontFamily: 'monospace',
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
