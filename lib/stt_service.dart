import 'dart:async' show StreamController;

import 'package:rxdart/subjects.dart' show BehaviorSubject, Subject;
import 'package:speech_to_text/speech_to_text.dart' show SpeechToText;

enum SttState {
  uninitialized,
  initializing,
  ready,
  listening,
  stopping,
  unavailable,
}

class SttService {
  final _speechToText = SpeechToText();
  SttState _state = SttState.uninitialized;
  Subject<SttState> stateSubject =
      BehaviorSubject.seeded(SttState.uninitialized);

  Future<void> init() async {
    final available = await _speechToText.initialize();
    if (available) {
      _setState(SttState.ready);
    } else {
      _setState(SttState.unavailable);
    }
  }

  Stream<String> detectSpeech() {
    switch (_state) {
      case SttState.ready:
        break;
      case SttState.uninitialized:
        throw Exception('stt not initialized');
      case SttState.unavailable:
        throw Exception('stt not available');
      case SttState.listening:
        throw Exception('stt already listening');
      case SttState.initializing:
        throw Exception('stt initializing');
      case SttState.stopping:
        throw Exception('stt stopping');
      default: // null
        throw Exception("invalid state $_state");
    }

    final controller = StreamController<String>();
    _setState(SttState.listening);
    controller.onListen = () {
      _speechToText.listen(
          onResult: (result) => controller.add(result.recognizedWords));
    };
    return controller.stream;
  }

  Future<void> stop() async {
    if (_state != SttState.listening) {
      return;
    }
    _setState(SttState.stopping);
    await _speechToText.stop();
    _setState(SttState.ready);
  }

  _setState(state) {
    _state = state;
    stateSubject.add(_state);
  }

  get state => _state;
}
