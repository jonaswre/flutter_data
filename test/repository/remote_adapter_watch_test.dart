import 'dart:math';

import 'package:flutter_data/flutter_data.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../_support/book.dart';
import '../_support/familia.dart';
import '../_support/house.dart';
import '../_support/person.dart';
import '../_support/setup.dart';
import '../mocks.dart';

void main() async {
  setUp(setUpFn);
  tearDown(tearDownFn);

  test('watchAllNotifier', () async {
    final listener = Listener<DataState<List<Familia>?>>();

    container.read(responseProvider.notifier).state = TestResponse.text('''
        [{ "id": "1", "surname": "Corleone" }, { "id": "2", "surname": "Soprano" }]
      ''');
    final notifier = familiaRepository.remoteAdapter.watchAllNotifier();

    dispose = notifier.addListener(listener);

    verify(listener(DataState(null, isLoading: true))).called(1);
    await oneMs();

    verify(listener(DataState([
      Familia(id: '1', surname: 'Corleone'),
      Familia(id: '2', surname: 'Soprano')
    ], isLoading: false)))
        .called(1);
    verifyNoMoreInteractions(listener);
  });

  test('watchAllNotifier with error', () async {
    final listener = Listener<DataState<List<Familia>?>?>();

    container.read(responseProvider.notifier).state =
        TestResponse(text: (_) => throw Exception('unreachable'));
    final notifier = familiaRepository.remoteAdapter.watchAllNotifier();

    dispose = notifier.addListener(listener);

    verify(listener(DataState(null, isLoading: true))).called(1);
    await oneMs();

    // finished loading but found the network unreachable
    verify(listener(argThat(isA<DataState>()
            .having((s) => s.isLoading, 'isLoading', isFalse)
            .having((s) => s.exception, 'exception', isA<Exception>()))))
        .called(1);
    verifyNoMoreInteractions(listener);

    // now server will successfully respond with two familia
    container.read(responseProvider.notifier).state = TestResponse.text('''
        [{ "id": "1", "surname": "Corleone" }, { "id": "2", "surname": "Soprano" }]
      ''');

    // reload
    await notifier.reload();

    final familia = Familia(id: '1', surname: 'Corleone');
    final familia2 = Familia(id: '2', surname: 'Soprano');

    // loads again, for now exception remains
    verify(listener(argThat(isA<DataState>()
            .having((s) => s.isLoading, 'isLoading', isTrue)
            .having((s) => s.exception, 'exception', isA<Exception>()))))
        .called(1);

    await oneMs();

    // now responds with models, loading done, and no exception
    verify(listener(DataState([familia, familia2], isLoading: false)))
        .called(1);
    verifyNoMoreInteractions(listener);
  });

  test('watchOneNotifier', () async {
    final listener = Listener<DataState<Person?>?>();

    container.read(responseProvider.notifier).state = TestResponse.text(
      '''{ "_id": "1", "name": "Charlie", "age": 23 }''',
    );
    final notifier =
        personRepository.remoteAdapter.watchOneNotifier('1', remote: true);

    dispose = notifier.addListener(listener);

    verify(listener(DataState(null, isLoading: true))).called(1);

    await oneMs();

    final charlie = isA<DataState>()
        .having((s) => s.isLoading, 'isLoading', isFalse)
        .having((s) => s.model.id, 'id', '1')
        .having((s) => s.model.age, 'age', 23)
        .having((s) => s.model.name, 'name', 'Charlie')
        // ensure the notifier has been attached
        .having((s) => s.model.notifier, 'notifier', isNotNull);

    verify(listener(argThat(charlie))).called(1);
    verifyNoMoreInteractions(listener);

    await personRepository.save(Person(id: '1', name: 'Charlie', age: 24));

    // unrelated request should not affect the current listener
    await familiaRepository.findOne('234324', remote: false);

    verify(listener(DataState(Person(id: '1', name: 'Charlie', age: 24),
            isLoading: false)))
        .called(1);
    verifyNoMoreInteractions(listener);
  });

  test('watchOneNotifier with error', () async {
    final listener = Listener<DataState<Familia?>?>();

    container.read(responseProvider.notifier).state = TestResponse(
      text: (_) => throw Exception('whatever'),
    );
    final notifier = familiaRepository.remoteAdapter.watchOneNotifier('1');

    dispose = notifier.addListener(listener);

    verify(listener(DataState<Familia?>(null, isLoading: true))).called(1);
    await oneMs();

    verify(listener(argThat(isA<DataState>().having(
            (s) => s.exception!.error.toString(),
            'exception',
            'Exception: whatever'))))
        .called(1);
    verifyNoMoreInteractions(listener);

    container.read(responseProvider.notifier).state =
        TestResponse(text: (_) => throw Exception('unreachable'));

    await notifier.reload();
    await oneMs();

    // loads again, for now original exception remains
    verify(listener(argThat(isA<DataState>()
            .having((s) => s.isLoading, 'isLoading', isTrue)
            .having((s) => s.exception!.error.toString(), 'exception',
                startsWith('Exception:')))))
        .called(1);

    await oneMs();
    // finished loading but found the network unreachable
    verify(listener(argThat(isA<DataState>()
            .having((s) => s.isLoading, 'isLoading', isFalse)
            .having((s) => s.exception, 'exception', isA<Exception>()))))
        .called(1);
    verifyNoMoreInteractions(listener);

    // now server will successfully respond with a familia
    final familia = Familia(id: '1', surname: 'Corleone');
    container.read(responseProvider.notifier).state = TestResponse.text('''
        { "id": "1", "surname": "Corleone" }
      ''');

    // reload
    await notifier.reload();
    await oneMs();

    // loads again, for now exception remains
    verify(listener(argThat(isA<DataState>()
            .having((s) => s.isLoading, 'isLoading', isTrue)
            .having((s) => s.exception, 'exception', isA<Exception>()))))
        .called(1);

    // now responds with model, loading done, and no exception
    verify(listener(DataState(familia, isLoading: false))).called(1);
    verifyNoMoreInteractions(listener);
  });

  test('watchOneNotifier with alsoWatch relationships', () async {
    // simulate Familia that exists in local storage
    // important to keep to test `alsoWatch` assignment order
    final familia = await Familia(id: '22', surname: 'Paez', persons: HasMany())
        .init(container.read)
        .save(remote: false);

    final listener = Listener<DataState<Familia?>?>();

    container.read(responseProvider.notifier).state =
        TestResponse.text('''{ "id": "22", "surname": "Paez" }''');
    final notifier = familiaRepository.remoteAdapter.watchOneNotifier(
      '22',
      alsoWatch: (f) => [f.persons],
    );

    dispose = notifier.addListener(listener);

    // verify loading
    verify(listener(DataState(familia, isLoading: true))).called(1);

    await oneMs();

    verify(listener(argThat(isA<DataState>()
            .having((s) => s.model.persons!, 'rel', isEmpty)
            .having((s) => s.isLoading, 'loading', false))))
        .called(1);
    verifyNoMoreInteractions(listener);

    // add a watched relationship
    var martin = Person(id: '1', name: 'Martin', age: 44);
    familia.persons.add(martin);

    verify(listener(argThat(isA<DataState>()
            .having((s) => s.model.persons!.toSet(), 'rel', {martin}).having(
                (s) => s.isLoading, 'loading', false))))
        .called(1);
    verifyNoMoreInteractions(listener);

    // update person
    martin = Person(id: '1', name: 'Martin', age: 45).init(container.read);

    verify(listener(argThat(isA<DataState>().having(
        (s) => s.model.persons!.toSet(),
        'rel',
        {Person(id: '1', name: 'Martin', age: 45)})))).called(1);
    verifyNoMoreInteractions(listener);

    // update another person through deserialization
    container.read(responseProvider.notifier).state = TestResponse.text(
        '''{ "_id": "2", "name": "Eve", "age": 20, "familia_id": "22" }''');
    final eve = await personRepository.findOne('2', remote: true);
    await oneMs();

    verify(listener(argThat(isA<DataState>().having((s) {
      return s.model.persons!.toSet();
    }, 'rel', unorderedEquals({martin, eve}))))).called(1);
    verifyNoMoreInteractions(listener);

    // remove person
    familia.persons.remove(martin);
    verify(listener(argThat(isA<DataState>()
        .having((s) => s.model.persons!.toSet(), 'rel', {eve})))).called(1);
    verifyNoMoreInteractions(listener);
  });

  test('watchOneNotifier with alsoWatch relationships (remote=false)',
      () async {
    // simulate Familia that exists in local storage
    // important to keep to test `alsoWatch` assignment order
    final familia = Familia(id: '1', surname: 'Paez', persons: HasMany())
        .init(container.read);

    final listener = Listener<DataState<Familia?>?>();

    final notifier = familiaRepository.remoteAdapter
        .watchOneNotifier('1', remote: false, alsoWatch: (f) => [f.persons]);

    // we don't want it to immediately notify the default local model
    dispose = notifier.addListener(listener, fireImmediately: false);

    familia.persons.add(Person(id: '1', name: 'Ricky'));
    await oneMs();

    verify(listener(DataState(familia))).called(1);

    Person(id: '1', name: 'Ricardo').init(container.read);
    await oneMs();

    verify(listener(DataState(familia))).called(1);
  });

  test('watchAllNotifier updates isLoading even in an empty response',
      () async {
    final listener = Listener<DataState<List<Familia>?>?>();

    container.read(responseProvider.notifier).state = TestResponse.text('[]');
    final notifier =
        familiaRepository.remoteAdapter.watchAllNotifier(remote: true);

    dispose = notifier.addListener(listener);

    verify(listener(argThat(
      isA<DataState>()
          .having((s) => s.isLoading, 'loading', true)
          // local storage should be null at this point
          .having((s) => s.model, 'model', null),
    ))).called(1);

    await oneMs();

    verify(listener(argThat(
      isA<DataState>()
          // empty because the server response was an empty list
          .having((s) => s.model, 'model', isEmpty)
          .having((s) => s.isLoading, 'loading', false),
    ))).called(1);

    // get a new notifier and try again

    final notifier2 = familiaRepository.remoteAdapter.watchAllNotifier();
    final listener2 = Listener<DataState<List<Familia>?>?>();

    dispose?.call();

    dispose = notifier2.addListener(listener2);

    verify(listener2(argThat(
      isA<DataState>().having((s) => s.isLoading, 'loading', true),
    ))).called(1);

    await oneMs();

    verify(listener2(argThat(
      isA<DataState>()
          .having((s) => s.model, 'empty', isEmpty)
          .having((s) => s.isLoading, 'loading', false),
    ))).called(1);
    verifyNoMoreInteractions(listener2);
  });

  test('watchAllNotifier syncLocal', () async {
    final listener = Listener<DataState<List<Familia>?>>();

    container.read(responseProvider.notifier).state = TestResponse.text(
        '''[{ "id": "22", "surname": "Paez" }, { "id": "12", "surname": "Brunez" }]''');
    final notifier =
        familiaRepository.remoteAdapter.watchAllNotifier(syncLocal: true);

    dispose = notifier.addListener(listener);
    await oneMs();

    verify(listener(DataState([
      Familia(id: '22', surname: 'Paez'),
      Familia(id: '12', surname: 'Brunez'),
    ], isLoading: false)))
        .called(1);

    container.read(responseProvider.notifier).state =
        TestResponse.text('''[{ "id": "22", "surname": "Paez" }]''');
    await notifier.reload();
    await oneMs();

    verify(listener(DataState([
      Familia(id: '22', surname: 'Paez'),
      Familia(id: '12', surname: 'Brunez'),
    ], isLoading: true)))
        .called(1);

    verify(listener(DataState([
      Familia(id: '22', surname: 'Paez'),
    ], isLoading: false)))
        .called(1);
  });

  //

  test('watchAllNotifier with multiple model updates', () async {
    final notifier = personRemoteAdapter.watchAllNotifier(remote: false);

    final matcher = predicate((p) {
      return p is Person && p.name.startsWith('Number') && p.age! < 19;
    });

    final count = 29;
    var i = 0;
    dispose = notifier.addListener(
      expectAsync1((state) {
        if (i == 0) {
          expect(state.model, isNull);
          expect(state.isLoading, isFalse);
        } else if (i <= count) {
          expect(state.model, List.generate(i, (_) => matcher));
          final box =
              (personRemoteAdapter.localAdapter as HiveLocalAdapter<Person>)
                  .box!;
          // check box has all the keys
          expect(box.keys.length, i);
        } else {
          // one less because of emitting the deletion,
          // and one less because of the now missing model
          expect(state.model, hasLength(i - 2));
        }
        i++;
        // an extra count because of the initial `null` state
        // and an extra count because of the deletion in the loop below
      }, count: count + 2),
    );

    // this emits `count` states
    Person person;
    for (var j = 0; j < count; j++) {
      await (() async {
        final id =
            Random().nextBool() ? Random().nextInt(999999999).toString() : null;
        person = Person.generate(container, withId: id);

        // in the last cycle, delete last Person too
        if (j == count - 1) {
          await oneMs();
          await person.delete();
        }
        await oneMs();
      })();
    }
  });

  test('watchAllNotifier updates', () async {
    final listener = Listener<DataState<List<Person>?>>();

    final p1 = Person(id: '1', name: 'Zof', age: 23).init(container.read);
    final notifier = personRemoteAdapter.watchAllNotifier(remote: true);

    dispose = notifier.addListener(listener);

    verify(listener(DataState([p1], isLoading: true))).called(1);
    verifyNoMoreInteractions(listener);

    final p2 = Person(id: '1', name: 'Zofie', age: 23).init(container.read);
    await oneMs();

    verify(listener(DataState([p2], isLoading: false))).called(1);
    verifyNoMoreInteractions(listener);

    // since p3 is not init() it won't show up thru watchAllNotifier
    final p3 = Person(id: '1', name: 'Zofien', age: 23);
    await oneMs();

    verifyNever(listener(DataState([p3], isLoading: false)));
    verifyNoMoreInteractions(listener);
  });

  test('watchAllNotifier with where/map', () async {
    final listener = Listener<DataState<List<Person>?>>();

    Person(id: '1', name: 'Zof', age: 23).init(container.read);
    Person(id: '2', name: 'Sarah', age: 50).init(container.read);
    Person(id: '3', name: 'Walter', age: 11).init(container.read);
    Person(id: '4', name: 'Koen', age: 92).init(container.read);

    final notifier = personRemoteAdapter
        .watchAllNotifier(remote: false)
        .where((p) => p.age! < 40)
        .map((p) => Person(name: p.name, age: p.age! + 10));

    dispose = notifier.addListener(listener);

    verify(listener(DataState(
      [Person(name: 'Zof', age: 33), Person(name: 'Walter', age: 21)],
    ))).called(1);
    verifyNoMoreInteractions(listener);
  });

  test('watchOneNotifier 2', () async {
    final listener = Listener<DataState<Person?>?>();

    final notifier = personRemoteAdapter.watchOneNotifier('1');

    final matcher = (name) => isA<DataState>()
        .having((s) => s.model.id, 'id', '1')
        .having((s) => s.model.name, 'name', name);

    dispose = notifier.addListener(listener, fireImmediately: false);

    Person(id: '1', name: 'Frank', age: 30).init(container.read);
    await oneMs();

    verify(listener(argThat(matcher('Frank')))).called(1);
    verifyNoMoreInteractions(listener);

    await personRemoteAdapter.save(Person(id: '1', name: 'Steve-O', age: 34));
    await oneMs();

    verify(listener(argThat(matcher('Steve-O')))).called(1);
    verifyNoMoreInteractions(listener);

    await personRemoteAdapter.save(Person(id: '1', name: 'Liam', age: 36));
    await oneMs();

    verify(listener(argThat(matcher('Liam')))).called(1);
    verifyNoMoreInteractions(listener);

    // a different ID doesn't trigger
    await personRemoteAdapter.save(Person(id: '2', name: 'Jupiter', age: 3));
    await oneMs();

    verifyNever(listener(argThat(matcher('Jupiter'))));
    verifyNoMoreInteractions(listener);
  });

  test('watchOneNotifier reads latest version', () async {
    Person(id: '345', name: 'Frank', age: 30).init(container.read);
    Person(id: '345', name: 'Steve-O', age: 34).init(container.read);

    final notifier = personRemoteAdapter.watchOneNotifier('345');

    dispose = notifier.addListener(expectAsync1((state) {
      expect(state.model!.name, 'Steve-O');
    }));
  });

  test('watchOneNotifier with custom finder', () async {
    // initialize a book in local storage, so we can later link it to the author
    final author = BookAuthor(id: 1, name: 'Robert').init(container.read);
    Book(id: 1, title: 'Choice', originalAuthor: author.asBelongsTo)
        .init(container.read);

    // update to the author
    container.read(responseProvider.notifier).state = TestResponse.text('''
        { "id": 1, "name": "Frank" }
      ''');

    final listener = Listener<DataState<BookAuthor?>?>();

    final notifier = bookAuthorRepository.remoteAdapter
        .watchOneNotifier(1, finder: 'caps', remote: true);

    dispose = notifier.addListener(listener);

    verify(listener(DataState(author, isLoading: true))).called(1);

    await oneMs();

    verify(listener(argThat(
      isA<DataState>().having((s) => s.model!.name, 'name', 'FRANK'),
    ))).called(1);
    verifyNoMoreInteractions(listener);
  });

  test('watchOneNotifier with alsoWatch relationships remote=false', () async {
    final f1 = Familia(
      id: '22',
      surname: 'Abagnale',
      persons: HasMany(),
      residence: BelongsTo(),
      cottage: BelongsTo(),
    ).init(container.read);

    final listener = Listener<DataState<Familia?>?>();

    final notifier = familiaRemoteAdapter.watchOneNotifier('22',
        alsoWatch: (familia) => [familia.persons, familia.residence],
        remote: false);

    dispose = notifier.addListener(listener);

    final p1 = Person(id: '1', name: 'Frank', age: 16).init(container.read);

    final matcher = isA<DataState>()
        .having((s) => s.model.persons!, 'persons', isEmpty)
        .having((s) => s.hasModel, 'hasModel', true)
        .having((s) => s.hasException, 'hasException', false)
        .having((s) => s.isLoading, 'isLoading', false);

    verify(listener(argThat(matcher))).called(1);

    p1.familia.value = f1;
    await oneMs();

    final matcher2 = isA<DataState>()
        .having((s) => s.model.persons!, 'persons', hasLength(1))
        .having((s) => s.hasModel, 'hasModel', true)
        .having((s) => s.hasException, 'hasException', false)
        .having((s) => s.isLoading, 'isLoading', false);

    verify(listener(argThat(matcher2))).called(1);

    f1.persons.add(Person(name: 'Martin', age: 44)); // this time without init
    await oneMs();

    verify(listener(argThat(
      isA<DataState>().having((s) => s.model.persons!, 'persons', hasLength(2)),
    ))).called(1);
    verifyNoMoreInteractions(listener);

    f1.residence!.value = House(address: '123 Main St'); // no init
    await oneMs();

    verify(listener(argThat(
      isA<DataState>().having(
          (s) => s.model.residence!.value!.address, 'address', '123 Main St'),
    ))).called(1);
    verifyNoMoreInteractions(listener);

    f1.persons.remove(p1);
    await oneMs();

    verify(listener(argThat(
      isA<DataState>().having((s) => s.model.persons!, 'persons', hasLength(1)),
    ))).called(1);
    verifyNoMoreInteractions(listener);

    // a non-watched relationship does not trigger
    f1.cottage!.value = House(address: '7342 Mountain Rd');
    await oneMs();

    verifyNever(listener(any));
    verifyNoMoreInteractions(listener);

    await f1.delete();
    await oneMs();

    // only the model removal triggers
    verify(listener(argThat(
      isA<DataState>().having((s) => s.model, 'model', isNull),
    ))).called(1);
    verifyNoMoreInteractions(listener);
  });

  test('watchOneNotifier without ID and alsoWatch', () async {
    final frank = Person(name: 'Frank', age: 30).init(container.read);

    final notifier = personRepository.remoteAdapter.watchOneNotifier(
      frank,
      alsoWatch: (p) => p.familia.andEach((f) => [f.cottage]),
    );

    final listener = Listener<DataState<Person?>?>();
    dispose = notifier.addListener(listener, fireImmediately: false);

    final matcher = isA<DataState>()
        .having((s) => s.model.name, 'name', 'Steve-O')
        .having((s) => s.hasException, 'exception', isFalse)
        .having((s) => s.isLoading, 'loading', isFalse);

    verifyNever(listener(argThat(matcher)));
    verifyNoMoreInteractions(listener);

    final steve = Person(name: 'Steve-O', age: 30).was(frank);
    await oneMs();

    verify(listener(argThat(matcher))).called(1);
    verifyNoMoreInteractions(listener);

    final cottage = House(id: '32769', address: '32769 Winding Road');

    final familia = Familia(
      surname: 'Marquez',
      cottage: cottage.asBelongsTo,
    );
    steve.familia.value = familia;
    await oneMs();

    verify(listener(argThat(matcher))).called(1);
    verifyNoMoreInteractions(listener);

    Familia(surname: 'Thomson', cottage: cottage.asBelongsTo).was(familia);
    await oneMs();

    verify(listener(argThat(matcher))).called(1);
    verifyNoMoreInteractions(listener);

    await House(id: '32769', address: '8 Hill St')
        .init(container.read)
        .save(remote: false);
    await oneMs();

    verify(listener(argThat(matcher))).called(1);
    verifyNoMoreInteractions(listener);

    Familia(surname: 'Thomson', cottage: BelongsTo.remove()).was(familia);
    await oneMs();

    verify(listener(argThat(matcher))).called(1);
    verifyNoMoreInteractions(listener);
  });

  test('watchOneNotifier with where/map', () async {
    final listener = Listener<DataState<Person?>>();

    Person(id: '1', name: 'Zof', age: 23).init(container.read);

    final notifier = personRemoteAdapter
        .watchOneNotifier('1', remote: false)
        .map((p) => Person(name: p!.name, age: p.age! + 10))
        .where((p) => p!.age! < 40);

    dispose = notifier.addListener(listener);

    verify(listener(DataState(
      Person(name: 'Zof', age: 33),
    ))).called(1);
    verifyNoMoreInteractions(listener);

    Person(id: '1', name: 'Zof', age: 71).init(container.read);
    await oneMs();

    // since 71 + 10 > 40, the listener will receive a null
    verify(listener(DataState(null))).called(1);
    verifyNoMoreInteractions(listener);
  });

  test('should be able to watch, dispose and watch again', () async {
    final notifier = personRemoteAdapter.watchAllNotifier();
    dispose = notifier.addListener((_) {});
    dispose!();
    final notifier2 = personRemoteAdapter.watchAllNotifier();
    dispose = notifier2.addListener((_) {});
  });

  test('notifier equality', () async {
    final bookAuthor = await BookAuthor(id: 1, name: 'Billy')
        .init(container.read)
        .save(remote: false);

    final defaultNotifier = container.read(bookAuthorProvider(1).notifier);
    final capsNotifier =
        container.read(bookAuthorProvider(1, finder: 'caps').notifier);
    final capsNotifier2 =
        container.read(bookAuthorProvider(1, finder: 'caps').notifier);

    expect(capsNotifier, capsNotifier2);
    expect(defaultNotifier, isNot(capsNotifier));

    final state = container.read(bookAuthorProvider(1));
    expect(state.model!, bookAuthor);
  });

  test('watchargs', () {
    final a1 = WatchArgs<Person>(id: 1, remote: false, finder: 'finder');
    final a2 = WatchArgs<Person>(id: 1, remote: false, finder: 'finder');
    expect(a1, a2);
  });
}
