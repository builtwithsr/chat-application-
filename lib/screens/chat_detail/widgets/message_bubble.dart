import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/message_model.dart';
import '../../../utils/constants.dart';
import '../../../utils/date_utils.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final String Function(String uid) senderName;
  final VoidCallback onLongPress;
  final VoidCallback onSwipeReply;
  final void Function(int optionIndex) onVote;
  final String currentUid;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.senderName,
    required this.onLongPress,
    required this.onSwipeReply,
    required this.onVote,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    if (message.deletedForEveryone) {
      return _buildDeletedBubble(context, 'This message was deleted for everyone');
    }
    if (message.isDeletedFor(currentUid)) {
      return _buildDeletedBubble(context, 'This message was deleted');
    }

    return Dismissible(
      key: ValueKey(message.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onSwipeReply();
        return false;
      },
      background: const Padding(
        padding: EdgeInsets.only(left: 16),
        child: Align(alignment: Alignment.centerLeft, child: Icon(Icons.reply, color: Colors.grey)),
      ),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              gradient: isMe 
                  ? const LinearGradient(
                      colors: [Colors.purple, Colors.blueAccent],
                      begin: Alignment.bottomRight,
                      end: Alignment.topLeft,
                    )
                  : null,
              color: isMe 
                  ? null
                  : (Theme.of(context).brightness == Brightness.dark 
                      ? Colors.grey.shade800 
                      : Colors.grey.shade200),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.pinned)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.push_pin, size: 12, color: isMe ? Colors.white70 : Colors.grey),
                      const SizedBox(width: 4),
                      Text('Pinned', style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : Colors.grey)),
                    ]),
                  ),
                if (message.replyToId != null) _buildReplyPreview(context),
                _buildContent(context),
                const SizedBox(height: 2),
                _buildFooter(context),
                if (message.reactions.isNotEmpty) _buildReactions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeletedBubble(BuildContext context, String text) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: Colors.teal, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.replyToSender ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
          Text(message.replyToText ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (message.type) {
      case MessageType.poll:
        return _PollContent(message: message, currentUid: currentUid, onVote: onVote);
      case MessageType.location:
        return _LocationContent(message: message);
      default:
        return Text.rich(
          TextSpan(children: [
            TextSpan(text: message.text, style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black))),
            if (message.editedAt != null)
              TextSpan(text: '  (edited)', style: TextStyle(fontSize: 10, color: isMe ? Colors.white60 : (isDark ? Colors.white60 : Colors.grey), fontStyle: FontStyle.italic)),
          ]),
        );
    }
  }

  Widget _buildFooter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(ChatDateUtils.messageTime(message.createdAt), style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : (isDark ? Colors.white60 : Colors.grey))),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            message.status == MessageStatus.read
                ? Icons.done_all
                : message.status == MessageStatus.delivered
                    ? Icons.done_all
                    : Icons.done,
            size: 14,
            color: message.status == MessageStatus.read ? Colors.blue : Colors.white70,
          ),
        ],
        if (message.starredBy.isNotEmpty) ...[
          const SizedBox(width: 4),
          const Icon(Icons.star, size: 12, color: Colors.amber),
        ],
      ],
    );
  }

  Widget _buildReactions(BuildContext context) {
    final counts = <String, int>{};
    for (final emoji in message.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: counts.entries
            .map((e) => Chip(
                  label: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.1) : null,
                ))
            .toList(),
      ),
    );
  }
}

class _PollContent extends StatelessWidget {
  final MessageModel message;
  final String currentUid;
  final void Function(int) onVote;
  const _PollContent({required this.message, required this.currentUid, required this.onVote});

  @override
  Widget build(BuildContext context) {
    final totalVotes = message.pollOptions.fold<int>(0, (sum, o) => sum + o.votes.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          const Icon(Icons.poll, size: 16),
          const SizedBox(width: 6),
          Flexible(child: Text(message.pollQuestion ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 8),
        ...message.pollOptions.asMap().entries.map((entry) {
          final i = entry.key;
          final option = entry.value;
          final pct = totalVotes == 0 ? 0.0 : option.votes.length / totalVotes;
          final votedByMe = option.votes.contains(currentUid);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => onVote(i),
              child: Stack(
                children: [
                  Container(
                    height: 32,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: votedByMe ? Colors.teal : Colors.grey.shade300),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          if (votedByMe) const Icon(Icons.check_circle, size: 14, color: Colors.teal),
                          if (votedByMe) const SizedBox(width: 4),
                          Expanded(child: Text(option.text, style: const TextStyle(fontSize: 13))),
                          Text('${option.votes.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        Text('$totalVotes vote${totalVotes == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _LocationContent extends StatelessWidget {
  final MessageModel message;
  const _LocationContent({required this.message});

  @override
  Widget build(BuildContext context) {
    final lat = message.locationLat;
    final lng = message.locationLng;
    return InkWell(
      onTap: () async {
        final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 90,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(6)),
              child: const Center(child: Icon(Icons.location_on, size: 36, color: Colors.redAccent)),
            ),
            const SizedBox(height: 6),
            Text('${lat?.toStringAsFixed(5)}, ${lng?.toStringAsFixed(5)}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            const Text('Open in Google Maps', style: TextStyle(fontSize: 12, color: Colors.teal)),
          ],
        ),
      ),
    );
  }
}
