part of flutter_data;

/// Hive implementation of [LocalAdapter].
// ignore: must_be_immutable
abstract class ObjectboxLocalAdapter<T extends DataModelMixin<T>>
    extends LocalAdapter<T> {
  ObjectboxLocalAdapter(Ref ref) : super(ref);

  @protected
  @visibleForTesting
  Store get store => graph._store;

  @override
  bool get isInitialized => true;

  @override
  void dispose() {}

  // protected API

  @override
  List<T> findAll() {
    return store
        .box<StoredModel>()
        .query(StoredModel_.typeId.startsWith(internalType) &
            StoredModel_.data.notNull())
        .build()
        .find()
        .map((e) => initModel(deserialize(e.toJson()!)))
        .toList();
  }

  @override
  T? findOne(String? key) {
    if (key == null) return null;
    final internalKey = key.detypify() as int;
    final json = store.box<StoredModel>().get(internalKey)?.toJson();
    return _deserializeWithKey(json, internalKey);
  }

  @override
  T? findOneById(Object? id) {
    if (id == null) return null;
    final model = store
        .box<StoredModel>()
        .query(StoredModel_.typeId.equals(id.typifyWith(internalType)))
        .build()
        .findFirst();
    return _deserializeWithKey(model?.toJson(), model?.key);
  }

  @override
  List<T> findMany(Iterable<String> keys) {
    final _keys = keys.map((key) => key.detypify() as int).toList();
    return graph._store
        .box<StoredModel>()
        .getMany(_keys)
        .filterNulls
        .mapIndexed((i, map) => _deserializeWithKey(map.toJson(), _keys[i]))
        .filterNulls
        .toList();
  }

  @override
  bool exists(String key) {
    return graph._store
            .box<StoredModel>()
            .query(StoredModel_.key.equals(key.detypify() as int) &
                StoredModel_.data.notNull())
            .build()
            .count() >
        0;
  }

  @override
  T save(String key, T model, {bool notify = true}) {
    final packer = Packer();
    // TODO could avoid saving ID?
    packer.packJson(serialize(model, withRelationships: false));

    final storedModel = StoredModel(
      typeId: model.id.typifyWith(internalType),
      key: key.detypify() as int,
      data: packer.takeBytes(),
    );

    bool keyExisted = exists(key);
    store.box<StoredModel>().put(storedModel);

    if (notify) {
      graph._notify(
        [key],
        type: keyExisted
            ? DataGraphEventType.updateNode
            : DataGraphEventType.addNode,
      );
    }
    return model;
  }

  @override
  Future<void> bulkSave(Iterable<DataModel> models,
      {bool notify = true}) async {
    final storedModels = models.map((m) {
      final key = DataModel.keyFor(m);
      final packer = Packer();
      final a = DataModel.adapterFor(m).localAdapter;
      packer.packJson(a.serialize(m, withRelationships: false));
      return StoredModel(
        typeId: m.id.typifyWith(internalType),
        key: key.detypify() as int,
        data: packer.takeBytes(),
      );
    }).toList();

    final existingKeys = store.runInTransaction(TxMode.read, () {
      final allKeys = storedModels.map((e) => e.key).toList();
      return store
          .box<StoredModel>()
          .query(StoredModel_.key.oneOf(allKeys) & StoredModel_.data.notNull())
          .build()
          .property(StoredModel_.key)
          .find()
          .map((k) {
        final m = storedModels.firstWhere((e) => e.key == k);
        return k.typifyWith(m.type);
      }).toList();
    });

    final savedKeys =
        await store.runInTransactionAsync(TxMode.write, (store, storedModels) {
      return store.box<StoredModel>().putMany(storedModels);
    }, storedModels);

    if (storedModels.length != savedKeys.length) {
      print('WARNING! Not all models stored!');
    }

    if (notify) {
      graph._notify(
        existingKeys,
        type: DataGraphEventType.updateNode,
      );
      graph._notify(
        existingKeys, // TODO fix: should be the non-existing keys
        type: DataGraphEventType.addNode,
      );
    }
  }

  @override
  Future<void> delete(String key, {bool notify = true}) async {
    store.box<StoredModel>().remove(key.detypify() as int);
    graph._notify([key], type: DataGraphEventType.removeNode);
  }

  @override
  void clear() {
    graph._store.box<Edge>().removeAll();
    graph._store.box<StoredModel>().removeAll();
    graph._notify([internalType], type: DataGraphEventType.clear);
  }

  @override
  int get count {
    return store
        .box<StoredModel>()
        .query(StoredModel_.typeId.startsWith(internalType))
        .build()
        .count();
  }

  @override
  List<String> get keys {
    return store
        .box<StoredModel>()
        .query(StoredModel_.typeId.startsWith(internalType))
        .build()
        .property(StoredModel_.key)
        .find()
        .map((k) => k.typifyWith(internalType))
        .toList();
  }

  ///

  T? _deserializeWithKey(Map<String, dynamic>? map, int? internalKey) {
    if (map != null) {
      var model = deserialize(map);
      if (model.id == null) {
        // if model has no ID, deserializing will assign a new key
        // but we want to keep the supplied one, so we use `withKey`
        model = DataModel.withKey(internalKey.typifyWith(internalType),
            applyTo: model);
      }
      return initModel(model);
    } else {
      return null;
    }
  }
}
