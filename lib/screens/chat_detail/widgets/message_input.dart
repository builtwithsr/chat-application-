import 'package:flutter/material.dart';
import '../../../models/message_model.dart';

class MessageInputBar extends StatefulWidget {
  final MessageModel? replyingTo;
  final String? replyingToSenderName;
  final VoidCallback onCancelReply;
  final void Function(String text) onSend;
  final void Function(bool typing) onTypingChanged;
  final VoidCallback onAttachPoll;
  final VoidCallback onAttachLocation;

  const MessageInputBar({
    super.key,
    required this.replyingTo,
    required this.replyingToSenderName,
    required this.onCancelReply,
    required this.onSend,
    required this.onTypingChanged,
    required this.onAttachPoll,
    required this.onAttachLocation,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final _controller = TextEditingController();
  bool _typing = false;

  void _handleChanged(String value) {
    final isTypingNow = value.trim().isNotEmpty;
    if (isTypingNow != _typing) {
      setState(() => _typing = isTypingNow);
      widget.onTypingChanged(_typing);
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    widget.onTypingChanged(false);
    setState(() => _typing = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Replying to ${widget.replyingToSenderName}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        Text(widget.replyingTo!.text, maxLines: 1, overflow: TextOverflow.ellipsis, 
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: widget.onCancelReply),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 28),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (_) => SafeArea(
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.poll_outlined),
                              title: const Text('Create Poll'),
                              onTap: () {
                                Navigator.pop(context);
                                widget.onAttachPoll();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.location_on_outlined),
                              title: const Text('Share Location'),
                              onTap: () {
                                Navigator.pop(context);
                                widget.onAttachLocation();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      onChanged: _handleChanged,
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_typing)
                  GestureDetector(
                    onTap: _send,
                    child: const Text(
                      'Send',
                      style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  )
                else
                   IconButton(
                    icon: const Icon(Icons.mic_none, size: 28),
                    onPressed: () {}, // Voice message placeholder
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
