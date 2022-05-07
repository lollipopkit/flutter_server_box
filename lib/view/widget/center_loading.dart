import 'package:flutter/material.dart';

const centerLoading = Center(child: CircularProgressIndicator());

const centerSizedLoading = SizedBox(
  width: 77,
  height: 77,
  child: Center(
    child: CircularProgressIndicator(),
  ),
);

final loadingIcon = IconButton(onPressed: () {}, icon: centerLoading);
