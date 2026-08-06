import 'dart:developer';

void warn(String msg) => log(
      msg,
      name: 'Flutter Math',
      level: 900, // Level.WARNING
    );

void error(String msg) => log(
      msg,
      name: 'Flutter Math',
      level: 1000, // Level.SEVERE
    );

void info(String msg) => log(
      msg,
      name: 'Flutter Math',
      level: 800, // Level.INFO
    );
