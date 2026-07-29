import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../../models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/chat_service.dart';
import '../../services/message_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_utils.dart';
import '../chat_detail/chat_detail_screen.dart';
import '../group/create_group_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/new_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser!.uid;
    final chatListProvider = context.watch<ChatListProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: Icon(context.watch<ThemeProvider>().isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.chat),
        onPressed: () => _showNewChatOptions(context),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          chatListProvider.setSearchQuery('');
                        },
                      )
                    : null,
              ),
              onChanged: chatListProvider.setSearchQuery,
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: ChatFilter.values.map((f) {
                final selected = chatListProvider.filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_filterLabel(f)),
                    selected: selected,
                    onSelected: (_) => chatListProvider.setFilter(f),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection(FirestoreCollections.users).snapshots(),
              builder: (context, userSnap) {
                final names = <String, String>{};
                if (userSnap.hasData) {
                  for (var d in userSnap.data!.docs) {
                    names[d.id] = (d.data() as Map<String, dynamic>)['displayName'] ?? 'User';
                  }
                }

                return StreamBuilder<List<ChatModel>>(
                  stream: _chatService.chatListStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading chats: ${snapshot.error}'));
                    }
                    final chats = snapshot.data ?? [];
                    
                    // Mark messages as delivered for all visible chats
                    if (chats.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final messageService = MessageService();
                        for (var chat in chats) {
                          if (chat.lastMessageSenderId != null && 
                              chat.lastMessageSenderId != uid && 
                              chat.lastMessageId != null) {
                            messageService.markLastMessageAsDelivered(chat.id, chat.lastMessageId!);
                          }
                        }
                      });
                    }

                    final filteredChats = chatListProvider.apply(chats, uid, names: names);
                    if (filteredChats.isEmpty) {
                      return _EmptyState(filter: chatListProvider.filter);
                    }
                    return RefreshIndicator(
                      onRefresh: () async => setState(() {}),
                      child: ListView.builder(
                        itemCount: filteredChats.length,
                        itemBuilder: (context, i) => _ChatTile(chat: filteredChats[i], uid: uid, names: names),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(ChatFilter f) {
    switch (f) {
      case ChatFilter.all:
        return 'All';
      case ChatFilter.unread:
        return 'Unread';
      case ChatFilter.groups:
        return 'Groups';
      case ChatFilter.archived:
        return 'Archived';
      case ChatFilter.favorites:
        return 'Favorites';
    }
  }

  void _showNewChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt),
              title: const Text('New chat'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewChatScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('New group'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  final String uid;
  final Map<String, String> names;
  const _ChatTile({required this.chat, required this.uid, required this.names});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    final unread = chat.unreadCountFor(uid);
    final pinned = chat.pinnedBy.contains(uid);
    final favorite = chat.favoritedBy.contains(uid);
    final archived = chat.archivedBy.contains(uid);
    
    String title = 'Chat';
    if (chat.isGroup) {
      title = chat.groupName ?? 'Group';
    } else {
      final otherUid = chat.participants.firstWhere((p) => p != uid, orElse: () => '');
      title = names[otherUid] ?? 'Direct chat';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Slidable(
      key: ValueKey(chat.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => chatService.togglePinChat(chat.id, !pinned),
            backgroundColor: Colors.orange,
            icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
            label: pinned ? 'Unpin' : 'Pin',
          ),
          SlidableAction(
            onPressed: (_) => chatService.toggleFavoriteChat(chat.id, !favorite),
            backgroundColor: Colors.amber,
            icon: favorite ? Icons.star : Icons.star_border,
            label: favorite ? 'Unstar' : 'Star',
          ),
          SlidableAction(
            onPressed: (_) => chatService.markUnread(chat.id, unread == 0),
            backgroundColor: Colors.blue,
            icon: Icons.markunread,
            label: unread > 0 ? 'Read' : 'Unread',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => chatService.toggleArchiveChat(chat.id, !archived),
            backgroundColor: Colors.grey,
            icon: Icons.archive,
            label: archived ? 'Unarchive' : 'Archive',
          ),
          SlidableAction(
            onPressed: (_) async {
              await chatService.deleteConversation(chat.id, chat.isGroup);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conversation deleted')));
              }
            },
            backgroundColor: Colors.red,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDark ? Colors.teal.shade700 : Colors.teal.shade100,
          child: Icon(chat.isGroup ? Icons.group : Icons.person, color: isDark ? Colors.white : Colors.teal.shade900),
        ),
        title: Text(title, style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal, color: isDark ? Colors.white : Colors.black)),
        subtitle: Text(
          chat.lastMessage.isEmpty ? 'No messages yet' : chat.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal, color: isDark ? Colors.white70 : Colors.black54),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (favorite) const Icon(Icons.star, size: 14, color: Colors.amber),
                if (favorite && pinned) const SizedBox(width: 4),
                if (pinned) const Icon(Icons.push_pin, size: 14, color: Colors.grey),
              ],
            ),
            Text(
              chat.lastMessageAt != null ? ChatDateUtils.messageTime(chat.lastMessageAt) : '',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            if (unread > 0)
              CircleAvatar(
                radius: 10,
                backgroundColor: Colors.teal,
                child: Text('$unread', style: const TextStyle(fontSize: 11, color: Colors.white)),
              ),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ChatFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              filter == ChatFilter.all ? 'No chats yet. Tap + to start one.' : 'Nothing here yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
