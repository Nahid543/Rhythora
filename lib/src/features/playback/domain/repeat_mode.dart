import 'package:just_audio/just_audio.dart';

enum RepeatMode {
  off, // Play queue once, stop at end
  all, // Loop entire queue
  one, // Repeat current song
}

extension RepeatModeExtension on RepeatMode {
  LoopMode toLoopMode() {
    switch (this) {
      case RepeatMode.off:
        return LoopMode.off;
      case RepeatMode.all:
        return LoopMode.all;
      case RepeatMode.one:
        return LoopMode.one;
    }
  }

  RepeatMode get next {
    switch (this) {
      case RepeatMode.off:
        return RepeatMode.all;
      case RepeatMode.all:
        return RepeatMode.one;
      case RepeatMode.one:
        return RepeatMode.off;
    }
  }

  String get label {
    switch (this) {
      case RepeatMode.off:
        return 'Repeat Off';
      case RepeatMode.all:
        return 'Repeat All';
      case RepeatMode.one:
        return 'Repeat One';
    }
  }
}
