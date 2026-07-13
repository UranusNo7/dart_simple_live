import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_core/simple_live_core.dart';

class SuperChatCard extends StatefulWidget {
  final LiveSuperChatMessage message;
  final Function()? onExpire;
  final int? customCountdown;
  const SuperChatCard(
    this.message, {
    required this.onExpire,
    this.customCountdown,
    Key? key,
  }) : super(key: key);

  @override
  State<SuperChatCard> createState() => _SuperChatCardState();
}

class _SuperChatCardState extends State<SuperChatCard> {
  StreamSubscription<int>? _countdownSub;
  late ValueNotifier<int> _countdownNotifier;
  int _countdown = 0;

  int _resolveCountdown() {
    if (widget.customCountdown != null) {
      return widget.customCountdown!.clamp(0, 1 << 30).toInt();
    }
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final endTime = widget.message.endTime.millisecondsSinceEpoch ~/ 1000;
    return (endTime - currentTime).clamp(0, 1 << 30).toInt();
  }

  @override
  void initState() {
    super.initState();
    _countdown = _resolveCountdown();
    _countdownNotifier = ValueNotifier(_countdown);
    if (_countdown <= 0 && widget.customCountdown == null) {
      return;
    }
    _startCountdown();
  }

  void _startCountdown() {
    _countdownSub = Stream<int>.periodic(
      const Duration(seconds: 1),
      (tick) => _countdown - tick - 1,
    ).takeWhile((v) => v >= 0).listen(
      (v) {
        if (mounted) _countdownNotifier.value = v;
      },
      onDone: () {
        if (mounted) widget.onExpire?.call();
      },
    );
  }

  @override
  void didUpdateWidget(covariant SuperChatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message ||
        oldWidget.customCountdown != widget.customCountdown) {
      _countdownSub?.cancel();
      _countdown = _resolveCountdown();
      _countdownNotifier.value = _countdown;
      if (_countdown <= 0 && widget.customCountdown == null) return;
      _startCountdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppStyle.radius8,
      child: Container(
        decoration: BoxDecoration(
          color: Utils.convertHexColor(widget.message.backgroundColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: AppStyle.edgeInsetsA8,
              child: Row(
                children: [
                  NetImage(
                    widget.message.face,
                    width: 48,
                    height: 48,
                    borderRadius: 36,
                  ),
                  AppStyle.hGap12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.message.userName,
                          style: const TextStyle(color: AppColors.black333),
                        ),
                        Text(
                          "￥${widget.message.price}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _countdownNotifier,
                    builder: (context, value, _) {
                      final displayCountdown =
                          (widget.customCountdown ?? value)
                              .clamp(0, 1 << 30)
                              .toInt();
                      return Text(
                        "$displayCountdown",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color:
                    Utils.convertHexColor(widget.message.backgroundBottomColor),
              ),
              padding: AppStyle.edgeInsetsA8,
              child: Text(
                widget.message.message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownSub?.cancel();
    _countdownNotifier.dispose();
    super.dispose();
  }
}
