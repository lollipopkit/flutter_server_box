import '../../../../../tex.dart';
import '../../../../ast/nodes/cursor_node.dart';
import '../../functions.dart';

const cursorEntries = {
  ['\\cursor']: FunctionSpec(numArgs: 1, handler: _cursorHandler)
};

GreenNode _cursorHandler(TexParser parser, FunctionContext context) =>
    CursorNode();
