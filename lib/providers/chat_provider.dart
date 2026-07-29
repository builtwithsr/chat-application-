import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';

enum ChatFilter { all, unread, groups, archived, favorites }

class ChatListProvider with ChangeNotifier {
  String _searchQuery = '';
  ChatFilter _filter = ChatFilter.all;

  String get searchQuery => _searchQuery;
  ChatFilter get filter => _filter;

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setFilter(ChatFilter f) {
    _filter = f;
    notifyListeners();
  }

  /// Applies the current filter/search to a raw chat list. [uid] is the
  /// current user, [names] maps chatId -> display name for search matching,
  /// [starredChatIds] holds chats containing starred/favorite messages.
  List<ChatModel> apply(
    List<ChatModel> chats,
    String uid, {
    Map<String, String> names = const {},
    Set<String> starredChatIds = const {},
  }) {
    var result = chats.where((c) => !c.archivedBy.contains(uid) || _filter == ChatFilter.archived);

    switch (_filter) {
      case ChatFilter.unread:
        result = result.where((c) => c.unreadCountFor(uid) > 0);
        break;
      case ChatFilter.groups:
        result = result.where((c) => c.isGroup);
        break;
      case ChatFilter.archived:
        result = result.where((c) => c.archivedBy.contains(uid));
        break;
      case ChatFilter.favorites:
        result = result.where((c) => c.favoritedBy.contains(uid));
        break;
      case ChatFilter.all:
        break;
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((c) {
        String displayName = '';
        if (c.isGroup) {
          displayName = c.groupName ?? 'Group';
        } else {
          // For direct chats, find the other participant's name in the map
          final otherUid = c.participants.firstWhere((p) => p != uid, orElse: () => '');
          displayName = names[otherUid] ?? '';
        }
        
        return displayName.toLowerCase().contains(q) || 
               c.lastMessage.toLowerCase().contains(q);
      });
    }

    final list = result.toList();
    list.sort((a, b) {
      final aPinned = a.pinnedBy.contains(uid);
      final bPinned = b.pinnedBy.contains(uid);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      final aTime = a.lastMessageAt?.toDate() ?? DateTime(1970);
      final bTime = b.lastMessageAt?.toDate() ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
    return list;
  }
}
