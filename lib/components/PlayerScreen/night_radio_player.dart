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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

/// Shared visual language for the technical, low-glare player surfaces.
class NightRadioPanel extends StatelessWidget {
  const NightRadioPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      clipBehavior: clipBehavior,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: colors.outline.withValues(alpha: 0.38)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(colors.primary.withValues(alpha: 0.075), const Color(0xF20D1014)),
            const Color(0xF2090B0E),
          ],
        ),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 8))],
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

/// A deliberately light-weight, decorative playback visualizer.
///
/// It paints directly from a single ticker and is isolated behind a repaint
/// boundary, so the surrounding player does not rebuild for every frame.
class NightRadioVisualizer extends StatefulWidget {
  const NightRadioVisualizer({super.key, required this.active, this.height = 44});

  final bool active;
  final double height;

  @override
  State<NightRadioVisualizer> createState() => _NightRadioVisualizerState();
}

class _NightRadioVisualizerState extends State<NightRadioVisualizer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700), value: 0.18);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant NightRadioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final shouldAnimate =
        widget.active && !MediaQuery.disableAnimationsOf(context) && TickerMode.valuesOf(context).enabled;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.18;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _NightRadioVisualizerPainter(animation: _controller, color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}

class _NightRadioVisualizerPainter extends CustomPainter {
  _NightRadioVisualizerPainter({required Animation<double> animation, required this.color})
    : _animation = animation,
      super(repaint: animation);

  final Animation<double> _animation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    const barCount = 34;
    const gap = 2.4;
    final barWidth = max(1.2, (size.width - gap * (barCount - 1)) / barCount);
    final baselinePaint = Paint()..color = color.withValues(alpha: 0.1);
    final barPaint = Paint()..color = color.withValues(alpha: 0.82);
    final phase = _animation.value * pi * 2;

    canvas.drawRect(Rect.fromLTWH(0, size.height - 1, size.width, 1), baselinePaint);
    for (var index = 0; index < barCount; index++) {
      final position = index / max(1, barCount - 1);
      final envelope = sin(position * pi).clamp(0.22, 1.0);
      final wave = (sin(phase * 1.3 + index * 0.72) + sin(phase * 0.73 - index * 0.31)) / 4 + 0.5;
      final barHeight = max(2.0, size.height * (0.13 + wave * 0.78 * envelope));
      final x = index * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NightRadioVisualizerPainter oldDelegate) => oldDelegate.color != color;
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
