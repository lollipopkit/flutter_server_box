import 'package:flutter/services.dart';

import '../model/app/github_id.dart';

/// RegExp for number
final numReg = RegExp(r'\s{1,}');

/// Private Key max allowed size is 20kb
const privateKeyMaxSize = 20 * 1024;

// Editor max allowed size is 1mb
const editorMaxSize = 1024 * 1024;

/// Max debug log lines
const maxDebugLogLines = 100;

/// Method Channels
const pkgName = 'tech.lolli.toolbox';
const bgRunChannel = MethodChannel('$pkgName/app_retain');
const homeWidgetChannel = MethodChannel('$pkgName/home_widget');

// Thanks
// If you want to change the url, please open an issue.
const contributors = <GhId>{
  'its-tom',
  'RainSunMe',
  'kalashnikov',
  'azkadev',
  'calvinweb',
  'Liloupar'
};
const participants = <GhId>{
  'jaychoubaby',
  'fecture',
  'Tao173',
  'QingAnLe',
  'wxdjs',
  'Aeorq',
  'allonmymind',
  'Yuuki-Rin',
  'LittleState',
  'karuboniru',
  'whosphp',
  'Climit',
  'dianso',
  'Jasondeepny',
  'kaliwell',
  'ymxkiss',
  'Ealrang',
  'hange33',
  'yuchen1204',
};
