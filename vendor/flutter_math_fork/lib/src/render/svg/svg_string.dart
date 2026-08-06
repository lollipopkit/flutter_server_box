import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

String svgStringFromPath(
  String path,
  Size viewPort,
  Rect viewBox,
  Color color, {
  String preserveAspectRatio = 'xMidYMid meet',
}) =>
    '<svg xmlns="http://www.w3.org/2000/svg" '
    'width="${viewPort.width}" height="${viewPort.height}" '
    'preserveAspectRatio="$preserveAspectRatio" '
    'viewBox='
    '"${viewBox.left} ${viewBox.top} ${viewBox.width} ${viewBox.height}" '
    '>'
    '<path fill="rgb(${color.red},${color.green},${color.blue})" d="$path"></path>'
    '</svg>';

final _alignmentToString = {
  Alignment.topLeft: 'xMinYMin',
  Alignment.topCenter: 'xMidYMin',
  Alignment.topRight: 'xMaxYMin',
  Alignment.centerLeft: 'xMinYMid',
  Alignment.center: 'xMidYMid',
  Alignment.centerRight: 'xMaxYMid',
  Alignment.bottomLeft: 'xMinYMax',
  Alignment.bottomCenter: 'xMidYMax',
  Alignment.bottomRight: 'xMaxYMax',
};

Widget svgWidgetFromPath(
  String path,
  Size viewPort,
  Rect viewBox,
  Color color, {
  Alignment align = Alignment.topLeft,
  BoxFit fit = BoxFit.fill,
}) {
  final alignment = _alignmentToString[align];

  assert(fit != BoxFit.none &&
      fit != BoxFit.fitHeight &&
      fit != BoxFit.fitWidth &&
      fit != BoxFit.scaleDown);
  final meetOrSlice = fit == BoxFit.contain ? 'meet' : 'slice';

  final preserveAspectRatio =
      fit == BoxFit.fill ? 'none' : '$alignment $meetOrSlice';

  final svgString = svgStringFromPath(path, viewPort, viewBox, color,
      preserveAspectRatio: preserveAspectRatio);
  return Container(
    height: viewPort.height,
    width: viewPort.width,
    child: SvgPicture.string(
      svgString,
      width: viewPort.width,
      height: viewPort.height,
      fit: fit,
      alignment: align,
    ),
  );
}
