import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

void drawSvgRoot(PictureInfo svgRoot, PaintingContext context, Offset offset) {
  final canvas = context.canvas;
  canvas.save();
  canvas.translate(offset.dx, offset.dy);
  canvas.scale(
    svgRoot.size.width,
    svgRoot.size.height,
  );
  canvas.clipRect(Rect.fromLTWH(
    0.0,
    0.0,
    svgRoot.size.width,
    svgRoot.size.height,
  ));
  canvas.drawPicture(svgRoot.picture);
  canvas.restore();
}
