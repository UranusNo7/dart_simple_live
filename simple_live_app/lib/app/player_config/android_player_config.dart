import 'package:media_kit_video/media_kit_video.dart';

const androidPlayerConfiguration = VideoControllerConfiguration(
  vo: 'gpu',
  hwdec: 'auto-safe',
  enableHardwareAcceleration: true,
  androidAttachSurfaceAfterVideoParameters: false,
);
