import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/group_service.dart';
import '../../utils/constants.dart';
import '../chat_list/chat_list_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final ChatModel chat;
  const GroupInfoScreen({super.key, required this.chat});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final GroupService _groupService = GroupService();

  Future<void> _renameGroup(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await _groupService.renameGroup(widget.chat.id, newName);
    }
  }

  void _showAddMemberDialog(BuildContext context, ChatModel chat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection(FirestoreCollections.users).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final availableUsers = snapshot.data!.docs.where((d) => !chat.participants.contains(d.id)).toList();
                  if (availableUsers.isEmpty) return const Center(child: Text('All users are already in the group'));
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: availableUsers.length,
                    itemBuilder: (context, i) {
                      final data = availableUsers[i].data() as Map<String, dynamic>;
                      final name = data['displayName'] ?? 'User';
                      return ListTile(
                        leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
                        title: Text(name),
                        trailing: const Icon(Icons.add_circle_outline, color: Colors.teal),
                        onTap: () {
                          _groupService.addMembers(chat.id, [availableUsers[i].id]);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Group Info')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection(FirestoreCollections.chats).doc(widget.chat.id).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Group not found'));
          }
          final chat = ChatModel.fromDoc(snapshot.data!);
          final isAdmin = chat.admins.contains(uid);

          return ListView(
            children: [
              const SizedBox(height: 16),
              Center(
                child: CircleAvatar(radius: 44, backgroundColor: Colors.teal, child: const Icon(Icons.group, color: Colors.white, size: 40)),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(chat.groupName ?? 'Group', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text('${chat.participants.length} members'),
                trailing: isAdmin
                    ? IconButton(icon: const Icon(Icons.edit), onPressed: () => _renameGroup(context, chat.groupName ?? ''))
                    : null,
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Participants', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    if (isAdmin)
                      TextButton.icon(
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Add Member'),
                        onPressed: () => _showAddMemberDialog(context, chat),
                      ),
                  ],
                ),
              ),
              ...chat.participants.map((memberUid) => FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection(FirestoreCollections.users).doc(memberUid).get(),
                    builder: (context, userSnap) {
                      final name = userSnap.hasData && userSnap.data!.exists
                          ? (userSnap.data!.data() as Map<String, dynamic>)['displayName'] ?? 'User'
                          : '...';
                      final memberIsAdmin = chat.admins.contains(memberUid);
                      return ListTile(
                        leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
                        title: Text(memberUid == uid ? '$name (You)' : name),
                        subtitle: memberIsAdmin ? const Text('Admin', style: TextStyle(color: Colors.teal)) : null,
                        trailing: (isAdmin && memberUid != uid)
                            ? PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'remove') _groupService.removeMember(chat.id, memberUid);
                                  if (v == 'make_admin') _groupService.makeAdmin(chat.id, memberUid);
                                  if (v == 'remove_admin') _groupService.removeAdmin(chat.id, memberUid);
                                },
                                itemBuilder: (_) => [
                                  if (!memberIsAdmin) const PopupMenuItem(value: 'make_admin', child: Text('Make admin')),
                                  if (memberIsAdmin) const PopupMenuItem(value: 'remove_admin', child: Text('Remove admin')),
                                  const PopupMenuItem(value: 'remove', child: Text('Remove from group')),
                                ],
                              )
                            : null,
                      );
                    },
                  )),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: const Text('Leave group', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await _groupService.leaveGroup(chat.id);
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const ChatListScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
