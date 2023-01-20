import 'dart:async' show Completer;

import 'package:rxdart/subjects.dart' show BehaviorSubject, Subject;
import 'package:speech_to_text/speech_to_text.dart' show SpeechToText;

enum SttState {
  uninitialized,
  initializing,
  ready,
  listening,
  unavailable,
  error,
}

class SttService {
  final _speechToText = SpeechToText();
  SttState _state = SttState.uninitialized;
  Subject<SttState> stateSubject =
      BehaviorSubject.seeded(SttState.uninitialized);

  Future<void> _init() async {
    _setState(SttState.initializing);
    if (await _speechToText.initialize()) {
      _setState(SttState.ready);
    } else {
      _setState(SttState.unavailable);
    }
  }

  Future<String> detectSpeech() async {
    switch (_state) {
      case SttState.ready:
        break;
      case SttState.uninitialized:
        await _init();
        break;
      case SttState.unavailable:
        throw Exception('stt not available');
      case SttState.listening:
        throw Exception('stt already listening');
      case SttState.initializing:
        throw Exception('stt initializing');
      default: // null
        throw Exception("invalid state $_state");
    }

    final result = Completer<String>();
    _setState(SttState.listening);
    _speechToText.listen(onResult: (r) => result.complete(r.recognizedWords));
    final resultText = await result.future;
    _setState(SttState.ready);
    return resultText;
  }

  _setState(state) {
    _state = state;
    stateSubject.add(_state);
  }

  get state => _state;
}
