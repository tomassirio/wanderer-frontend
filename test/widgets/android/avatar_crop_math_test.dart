import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_avatar_crop_screen.dart';

void main() {
  const landscape = Size(200, 100);

  test('zoom 1, no pan: square is the centred short side', () {
    expect(AvatarCropMath.sourceRect(landscape, 1, Offset.zero),
        const Rect.fromLTWH(50, 0, 100, 100));
  });

  test('pan is clamped so the square never leaves the image', () {
    // Short side spans the circle: no vertical slack, half a unit horizontal.
    expect(AvatarCropMath.clampPan(const Offset(5, 5), landscape, 1),
        const Offset(0.5, 0));
    final src = AvatarCropMath.sourceRect(landscape, 1,
        AvatarCropMath.clampPan(const Offset(-5, 0), landscape, 1));
    expect(src, const Rect.fromLTWH(100, 0, 100, 100));
    // Zoom 2: square is 50px, may move 75px either way horizontally.
    final z2 = AvatarCropMath.sourceRect(landscape, 2,
        AvatarCropMath.clampPan(const Offset(9, 9), landscape, 2));
    expect(z2, const Rect.fromLTWH(0, 0, 50, 50));
  });

  test('odd quarter turns swap the image size', () {
    expect(AvatarCropMath.rotated(landscape, 1), const Size(100, 200));
    expect(AvatarCropMath.rotated(landscape, 2), landscape);
  });
}
