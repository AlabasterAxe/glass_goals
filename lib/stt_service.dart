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

  _setState(state) {
    _state = state;
    stateSubject.add(_state);
  }

  get state => _state;
}
