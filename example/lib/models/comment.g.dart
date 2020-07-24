// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Comment _$CommentFromJson(Map<String, dynamic> json) {
  return Comment(
    id: json['id'] as int,
    body: json['body'] as String,
    approved: json['approved'] as bool,
    post: json['post'] == null
        ? null
        : BelongsTo.fromJson(json['post'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$CommentToJson(Comment instance) => <String, dynamic>{
      'id': instance.id,
      'body': instance.body,
      'approved': instance.approved,
      'post': instance.post,
    };

// **************************************************************************
// RepositoryGenerator
// **************************************************************************

// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

mixin $CommentLocalAdapter on LocalAdapter<Comment> {
  @override
  Map<String, Map<String, Object>> relationshipsFor([Comment model]) => {
        'post': {
          'inverse': 'comments',
          'type': 'posts',
          'kind': 'BelongsTo',
          'instance': model?.post
        }
      };

  @override
  Comment deserialize(map) {
    for (final key in relationshipsFor().keys) {
      map[key] = {
        '_': [map[key], !map.containsKey(key)],
      };
    }
    return _$CommentFromJson(map);
  }

  @override
  Map<String, dynamic> serialize(model) => _$CommentToJson(model);
}

// ignore: must_be_immutable
class $CommentHiveLocalAdapter = HiveLocalAdapter<Comment>
    with $CommentLocalAdapter;

class $CommentRemoteAdapter = RemoteAdapter<Comment>
    with JSONServerAdapter<Comment>;

//

final commentLocalAdapterProvider = Provider<LocalAdapter<Comment>>((ref) =>
    $CommentHiveLocalAdapter(
        ref.read(hiveLocalStorageProvider), ref.read(graphProvider)));

final commentRemoteAdapterProvider = Provider<RemoteAdapter<Comment>>(
    (ref) => $CommentRemoteAdapter(ref.read(commentLocalAdapterProvider)));

final commentRepositoryProvider =
    Provider<Repository<Comment>>((_) => Repository<Comment>());

extension CommentX on Comment {
  Comment init([owner]) {
    return internalLocatorFn(commentRepositoryProvider, owner)
        .internalAdapter
        .initializeModel(this, save: true) as Comment;
  }
}