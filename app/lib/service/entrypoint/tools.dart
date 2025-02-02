// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';

import '../services.dart';

/// Setup the tool's runtime environment, including Datastore access and logging.
Future<void> withToolRuntime(Future<void> Function() fn) async {
  final subs = Logger.root.onRecord.listen((r) {
    print([
      r.time.toIso8601String().replaceFirst('T', ' '),
      r.toString(),
      r.error,
      r.stackTrace?.toString(),
    ].where((e) => e != null).join(' '));
  });
  try {
    await withServices(fn);
  } finally {
    await subs.cancel();
  }
}

/// Waits for any of the listed signals and returns the first that occurs.
Future<ProcessSignal> waitForProcessSignalTermination() {
  // Track subscriptions to event streams, so we can cancel them all.
  // This is probably not critical, but it's nice to cleanup.
  final subscriptions = <StreamSubscription>[];
  final completer = Completer<ProcessSignal>();

  Future<void> process(ProcessSignal event) async {
    try {
      // This should never throw, but it's nice to be defensive.
      while (subscriptions.isNotEmpty) {
        await subscriptions.removeLast().cancel();
      }
    } finally {
      if (!completer.isCompleted) {
        completer.complete(event);
      }
    }
  }

  subscriptions.addAll([
    ProcessSignal.sighup,
    ProcessSignal.sigint,
    ProcessSignal.sigterm,
  ].map((s) => s.watch().listen(process)));
  return completer.future;
}
