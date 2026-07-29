import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/chat_service.dart';
import '../../services/message_service.dart';
import '../../utils/constants.dart';
import '../../utils/date_utils.dart';
import '../group/group_info_screen.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input.dart';
import 'widgets/poll_widget.dart';

class ChatDetailScreen extends StatefulWidget {
  final ChatModel chat;
  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final MessageService _messageService = MessageService();
  final ChatService _chatService = ChatService();
  final _scrollController = ScrollController();

  MessageModel? _replyingTo;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  List<MessageModel> _searchResults = [];
  bool _loadingMore = false;
  List<MessageModel> _olderMessages = [];
  DocumentSnapshot? _lastLoadedDoc;

  late String _uid;
  late Map<String, String> _memberNames; // populated lazily

  @override
  void initState() {
    super.initState();
    _uid = context.read<app_auth.AuthProvider>().firebaseUser!.uid;
    _memberNames = {};
    _scrollController.addListener(_onScroll);
    _loadMemberNames();
  }

  Future<void> _loadMemberNames() async {
    final snap = await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .where(FieldPath.documentId, whereIn: widget.chat.participants.take(10).toList())
        .get();
    setState(() {
      _memberNames = {for (final d in snap.docs) d.id: (d.data()['displayName'] ?? 'User')};
    });
  }

  String _nameFor(String uid) => uid == _uid ? 'You' : (_memberNames[uid] ?? 'User');

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _lastLoadedDoc == null) return;
    setState(() => _loadingMore = true);
    final older = await _messageService.fetchOlderMessages(widget.chat.id, _lastLoadedDoc!);
    setState(() {
      _olderMessages.addAll(older);
      _loadingMore = false;
    });
  }

  Future<void> _sendText(String text) async {
    await _messageService.sendTextMessage(
      chatId: widget.chat.id,
      text: text,
      replyToId: _replyingTo?.id,
      replyToText: _replyingTo?.text,
      replyToSender: _replyingTo == null ? null : _nameFor(_replyingTo!.senderId),
      participants: widget.chat.participants,
    );
    setState(() => _replyingTo = null);
  }

  Future<void> _attachPoll() async {
    final result = await showCreatePollDialog(context);
    if (result == null) return;
    await _messageService.sendPollMessage(
      chatId: widget.chat.id,
      question: result.question,
      options: result.options,
      allowMultiple: result.allowMultiple,
      participants: widget.chat.participants,
    );
  }

  Future<void> _attachLocation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Share Location?'),
        content: const Text('Your current coordinates will be sent to this chat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Share')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final permission = await Geolocator.checkPermission();
      var granted = permission;
      if (permission == LocationPermission.denied) {
        granted = await Geolocator.requestPermission();
      }
      if (granted == LocationPermission.denied || granted == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied')));
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      await _messageService.sendLocationMessage(
        chatId: widget.chat.id,
        lat: position.latitude,
        lng: position.longitude,
        participants: widget.chat.participants,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
      }
    }
  }

  void _showMessageActions(MessageModel message) {
    final isMe = message.senderId == _uid;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            _quickReactionsRow(message),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyingTo = message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(context);
                _forwardMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                String copyText = message.text;
                if (message.type == MessageType.location) {
                  copyText = 'Location: https://www.google.com/maps/search/?api=1&query=${message.locationLat},${message.locationLng}';
                } else if (message.type == MessageType.poll) {
                  copyText = 'Poll: ${message.pollQuestion}';
                }
                Clipboard.setData(ClipboardData(text: copyText)).then((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copied to clipboard')));
                  }
                });
              },
            ),
            ListTile(
              leading: Icon(message.pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(message.pinned ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(context);
                _messageService.togglePinMessage(widget.chat.id, message.id, !message.pinned);
              },
            ),
            ListTile(
              leading: Icon(message.starredBy.contains(_uid) ? Icons.star : Icons.star_border),
              title: Text(message.starredBy.contains(_uid) ? 'Remove star' : 'Star'),
              onTap: () {
                Navigator.pop(context);
                _messageService.toggleStarMessage(widget.chat.id, message.id, !message.starredBy.contains(_uid));
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete for me'),
              onTap: () {
                Navigator.pop(context);
                _messageService.deleteForMe(widget.chat.id, message.id);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete for everyone'),
                onTap: () {
                  Navigator.pop(context);
                  _messageService.deleteForEveryone(widget.chat.id, message.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _quickReactionsRow(MessageModel message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: quickReactionEmojis.map((emoji) {
          final mine = message.reactions[_uid] == emoji;
          return InkWell(
            onTap: () {
              Navigator.pop(context);
              _messageService.setReaction(widget.chat.id, message.id, mine ? null : emoji);
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(emoji, style: TextStyle(fontSize: mine ? 28 : 22)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _editMessage(MessageModel message) async {
    final controller = TextEditingController(text: message.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: controller, autofocus: true, maxLines: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newText != null && newText.isNotEmpty && newText != message.text) {
      await _messageService.editMessage(widget.chat.id, message.id, newText);
    }
  }

  Future<void> _forwardMessage(MessageModel message) async {
    final selectedChat = await showDialog<ChatModel>(
      context: context,
      builder: (context) => _ForwardPicker(currentUid: _uid, names: _memberNames),
    );

    if (selectedChat != null) {
      final chatName = selectedChat.isGroup 
          ? (selectedChat.groupName ?? 'Group') 
          : (_memberNames[selectedChat.participants.firstWhere((p) => p != _uid)] ?? 'Chat');

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Forward message?'),
          content: Text('Forward this message to $chatName?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Forward')),
          ],
        ),
      );

      if (confirm == true) {
        await _messageService.forwardMessage(
          targetChatId: selectedChat.id,
          message: message,
          participants: selectedChat.participants,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Forwarded to $chatName')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.chat.isGroup ? (widget.chat.groupName ?? 'Group') : _nameFor(
        widget.chat.participants.firstWhere((p) => p != _uid, orElse: () => ''));

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search messages', border: InputBorder.none),
                onChanged: (q) async {
                  final results = await _messageService.searchInChat(widget.chat.id, q);
                  setState(() => _searchResults = results);
                },
              )
            : Text(title),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() => _isSearching = !_isSearching),
          ),
          if (widget.chat.isGroup)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => GroupInfoScreen(chat: widget.chat))),
            )
          else
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'block') {
                  final otherUid = widget.chat.participants.firstWhere((p) => p != _uid);
                  await context.read<app_auth.AuthProvider>().toggleBlock(otherUid, true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked')));
                  }
                } else if (v == 'unblock') {
                  final otherUid = widget.chat.participants.firstWhere((p) => p != _uid);
                  await context.read<app_auth.AuthProvider>().toggleBlock(otherUid, false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unblocked')));
                  }
                }
              },
              itemBuilder: (_) {
                final otherUid = widget.chat.participants.firstWhere((p) => p != _uid, orElse: () => '');
                final amIBlocking = context.watch<app_auth.AuthProvider>().profile?.blockedUsers.contains(otherUid) ?? false;
                return [
                  PopupMenuItem(
                    value: amIBlocking ? 'unblock' : 'block',
                    child: Text(amIBlocking ? 'Unblock User' : 'Block User', 
                    style: TextStyle(color: amIBlocking ? Colors.teal : Colors.red)),
                  ),
                ];
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildPinnedHeader(),
          if (!widget.chat.isGroup) _buildPresenceBar(),
          if (_isSearching)
            Expanded(child: _buildSearchResults())
          else
            Expanded(child: _buildMessageList()),
          _buildInputOrBlockedBar(),
        ],
      ),
    );
  }

  Widget _buildInputOrBlockedBar() {
    if (widget.chat.isGroup) {
      return _inputBar();
    }

    final otherUid = widget.chat.participants.firstWhere((p) => p != _uid, orElse: () => '');
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection(FirestoreCollections.users).doc(otherUid).snapshots(),
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final myProfile = context.watch<app_auth.AuthProvider>().profile;
        final iBlockedThem = myProfile?.blockedUsers.contains(otherUid) ?? false;
        
        bool theyBlockedMe = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final blockedByThem = List<String>.from(data['blockedUsers'] ?? []);
          theyBlockedMe = blockedByThem.contains(_uid);
        }

        if (iBlockedThem || theyBlockedMe) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  iBlockedThem 
                    ? "You blocked this user. Unblock them to send a message."
                    : "You can't reply to this conversation.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.grey, fontSize: 13),
                ),
                if (iBlockedThem)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () => context.read<app_auth.AuthProvider>().toggleBlock(otherUid, false),
                      child: const Text(
                        "Unblock",
                        style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return _inputBar();
      },
    );
  }

  Widget _inputBar() {
    return MessageInputBar(
      replyingTo: _replyingTo,
      replyingToSenderName: _replyingTo == null ? null : _nameFor(_replyingTo!.senderId),
      onCancelReply: () => setState(() => _replyingTo = null),
      onSend: _sendText,
      onTypingChanged: (t) => _chatService.setTyping(widget.chat.id, t),
      onAttachPoll: _attachPoll,
      onAttachLocation: _attachLocation,
    );
  }

  Widget _buildPresenceBar() {
    final otherUid = widget.chat.participants.firstWhere((p) => p != _uid, orElse: () => '');
    if (otherUid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection(FirestoreCollections.users).doc(otherUid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final typing = (widget.chat.typing[otherUid] ?? false) == true;
        final showOnline = data['showOnlineStatus'] ?? true;
        final showLastSeen = data['showLastSeen'] ?? true;
        final status = data['status'] ?? 'offline';

        String label = '';
        if (typing) {
          label = 'typing...';
        } else if (showOnline && status == 'online') {
          label = 'online';
        } else if (showLastSeen) {
          label = ChatDateUtils.lastSeenLabel(data['lastSeen']);
        }
        if (label.isEmpty) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          color: Colors.teal.shade50,
          child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.teal)),
        );
      },
    );
  }

  Widget _buildPinnedHeader() {
    return StreamBuilder<List<MessageModel>>(
      stream: _messageService.pinnedMessagesStream(widget.chat.id),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
        final pinned = snap.data!.first;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.teal.shade50,
          child: Row(
            children: [
              const Icon(Icons.push_pin, size: 16, color: Colors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pinned Message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                    Text(pinned.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => _messageService.togglePinMessage(widget.chat.id, pinned.id, false),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(child: Text('No matching messages'));
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, i) {
        final m = _searchResults[i];
        return ListTile(
          title: Text(m.text, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('${_nameFor(m.senderId)} · ${ChatDateUtils.messageTime(m.createdAt)}'),
        );
      },
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<MessageModel>>(
      stream: _messageService.messagesStream(widget.chat.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final liveMessages = snapshot.data ?? [];
        final allMessages = [...liveMessages, ..._olderMessages];

        if (allMessages.isEmpty) {
          return const Center(child: Text('No messages yet. Say hi!'));
        }

        // Mark visible messages as read.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _messageService.markAllVisibleAsRead(widget.chat.id, liveMessages);
        });

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          itemCount: allMessages.length + (_loadingMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == allMessages.length) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final message = allMessages[i];
            // Use local time if server timestamp hasn't synced yet to prevent flickering
            final Timestamp currentMsgDate = message.createdAt ?? Timestamp.now();
            final Timestamp? nextMsgDate = (i + 1 < allMessages.length) 
                ? (allMessages[i + 1].createdAt ?? Timestamp.now()) 
                : null;

            final showDateSeparator = i == allMessages.length - 1 ||
                (nextMsgDate != null && !ChatDateUtils.isSameDay(currentMsgDate, nextMsgDate));

            return Column(
              children: [
                if (showDateSeparator)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Chip(
                      label: Text(
                        ChatDateUtils.dateSeparatorLabel(currentMsgDate),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      backgroundColor: Colors.grey.shade200,
                      side: BorderSide.none,
                    ),
                  ),
                MessageBubble(
                  message: message,
                  isMe: message.senderId == _uid,
                  senderName: _nameFor,
                  currentUid: _uid,
                  onLongPress: () => _showMessageActions(message),
                  onSwipeReply: () => setState(() => _replyingTo = message),
                  onVote: (optionIndex) => _messageService.voteOnPoll(
                    chatId: widget.chat.id,
                    messageId: message.id,
                    optionIndex: optionIndex,
                    allowMultiple: message.pollAllowMultiple,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ForwardPicker extends StatelessWidget {
  final String currentUid;
  final Map<String, String> names;
  const _ForwardPicker({required this.currentUid, required this.names});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Forward to...'),
      content: SizedBox(
        width: double.maxFinite,
        child: StreamBuilder<List<ChatModel>>(
          stream: ChatService().chatListStream(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final chats = snap.data!;
            if (chats.isEmpty) return const Text('No chats available');
            return ListView.builder(
              shrinkWrap: true,
              itemCount: chats.length,
              itemBuilder: (context, i) {
                final chat = chats[i];
                String title = 'Chat';
                if (chat.isGroup) {
                  title = chat.groupName ?? 'Group';
                } else {
                  final otherUid = chat.participants.firstWhere((p) => p != currentUid, orElse: () => '');
                  title = names[otherUid] ?? 'Direct chat';
                }
                return ListTile(
                  leading: CircleAvatar(child: Icon(chat.isGroup ? Icons.group : Icons.person)),
                  title: Text(title),
                  onTap: () => Navigator.pop(context, chat),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}
