import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod/src/framework.dart';
import 'package:rxdart/rxdart.dart';

class BehaviorProviderSubscription<T> implements ProviderSubscription<T> {
  final ProviderSubscription<AsyncValue<T>> _sub;
  final BehaviorSubject<T> _subject;

  BehaviorProviderSubscription(this._sub, this._subject);

  @override
  void close() => _sub.close();

  @override
  bool get closed => this._sub.closed;

  @override
  T read() => this._subject.value;

  @override
  Node get source => this._sub.source;
}

class BehaviorProvider<T> implements ProviderListenable<T> {
  late final StreamProvider<T> _streamProvider;
  final BehaviorSubject<T> _subject;

  BehaviorProvider(T value) : _subject = BehaviorSubject<T>.seeded(value) {
    this._streamProvider = StreamProvider<T>((_) => _subject);
  }

  @override
  ProviderSubscription<T> addListener(
      Node node, void Function(T? previous, T next) listener,
      {required void Function(Object error, StackTrace stackTrace)? onError,
      required void Function()? onDependencyMayHaveChanged,
      required bool fireImmediately}) {
    final sub = _streamProvider.addListener(
        node,
        (AsyncValue<T>? prev, AsyncValue<T> next) =>
            listener(prev?.valueOrNull, this._subject.value),
        onError: onError,
        onDependencyMayHaveChanged: onDependencyMayHaveChanged,
        fireImmediately: fireImmediately);
    return BehaviorProviderSubscription<T>(sub, _subject);
  }

  @override
  T read(Node node) {
    return this._streamProvider.read(node).valueOrNull ?? this._subject.value;
  }

  @override
  ProviderListenable<Selected> select<Selected>(
      Selected Function(T value) selector) {
    return _streamProvider.select((AsyncValue<T> value) {
      return selector(value.valueOrNull ?? this._subject.value);
    });
  }

  add(T value) {
    _subject.add(value);
  }

  T get value => _subject.value;

  ValueStream<T> get stream => _subject.stream;
}
