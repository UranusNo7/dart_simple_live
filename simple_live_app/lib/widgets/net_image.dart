import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

class NetImage extends StatelessWidget {
  final String picUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final double borderRadius;
  final int? cacheWidth;
  const NetImage(this.picUrl,
      {this.width,
      this.height,
      this.fit = BoxFit.cover,
      this.borderRadius = 0,
      this.cacheWidth,
      Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (picUrl.isEmpty) {
      return Image.asset(
        'assets/images/logo.png',
        width: width,
        height: height,
      );
    }
    var pic = picUrl;
    if (pic.startsWith("//")) {
      pic = 'https:$pic';
    }
    final resolvedCacheWidth = cacheWidth ?? _resolveCacheWidth(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ExtendedImage.network(
        pic,
        cache: true,
        fit: fit,
        height: height,
        width: width,
        cacheWidth: resolvedCacheWidth,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(borderRadius),
        loadStateChanged: (e) {
          if (e.extendedImageLoadState == LoadState.loading) {
            return _stateIcon(
              width: width,
              height: height,
              icon: Icons.image,
            );
          }
          if (e.extendedImageLoadState == LoadState.failed) {
            return _stateIcon(
              width: width,
              height: height,
              icon: Icons.broken_image,
            );
          }
          return null;
        },
      ),
    );
  }

  int? _resolveCacheWidth(BuildContext context) {
    if (width == null || !width!.isFinite || width! <= 0) {
      return null;
    }
    return (width! * MediaQuery.of(context).devicePixelRatio).round();
  }

  Widget _stateIcon({
    required double? width,
    required double? height,
    required IconData icon,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Icon(
          icon,
          color: Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}
