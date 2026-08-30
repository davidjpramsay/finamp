import 'package:finamp/components/finamp_icon.dart';
import 'package:finamp/theme/night_radio_theme.dart';
import 'package:flutter/material.dart';

class NightRadioBrand extends StatelessWidget {
  const NightRadioBrand({super.key, this.onTap, this.compact = false, this.offline = false, this.busy = false});

  final VoidCallback? onTap;
  final bool compact;
  final bool offline;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 5 : 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              FinampIcon(
                compact ? 25 : 32,
                compact ? 25 : 32,
                overrideColor: offline ? NightRadioColors.textMuted : NightRadioColors.violet,
              ),
              Positioned(
                right: -2,
                bottom: -1,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: busy
                        ? NightRadioColors.amber
                        : offline
                        ? NightRadioColors.textMuted
                        : NightRadioColors.signal,
                    shape: BoxShape.circle,
                    border: Border.all(color: NightRadioColors.background, width: 1.5),
                    boxShadow: const [BoxShadow(color: Color(0x669DFF6B), blurRadius: 5)],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: compact ? 7 : 9),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FINAMP',
                style: TextStyle(
                  color: NightRadioColors.text,
                  fontFamily: 'monospace',
                  fontSize: compact ? 11 : 13,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: compact ? 1.5 : 2.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                offline ? 'NIGHT // OFFLINE' : 'NIGHT // ONLINE',
                style: TextStyle(
                  color: offline ? NightRadioColors.textMuted : NightRadioColors.cyan,
                  fontFamily: 'monospace',
                  fontSize: compact ? 7.5 : 8.5,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Material(
      color: const Color(0xE60A0C11),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: const BorderSide(color: NightRadioColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
