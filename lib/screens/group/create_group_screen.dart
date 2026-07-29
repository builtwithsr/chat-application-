import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/group_service.dart';
import '../../utils/constants.dart';
import '../chat_detail/chat_detail_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final Set<String> _selected = {};
  bool _creating = false;

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selected.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a group name and pick at least 2 members')),
      );
      return;
    }
    setState(() => _creating = true);
    final chatId = await GroupService().createGroup(groupName: name, memberUids: _selected.toList());
    if (!mounted) return;
    final doc = await FirebaseFirestore.instance.collection(FirestoreCollections.chats).doc(chatId).get();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: ChatModel.fromDoc(doc))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().firebaseUser!.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Group'),
        actions: [
          TextButton(
            onPressed: _creating ? null : _create,
            child: const Text('Create'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Group name', prefixIcon: Icon(Icons.group)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Add members (${_selected.length} selected)', style: const TextStyle(color: Colors.grey)),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection(FirestoreCollections.users).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final users = snapshot.data!.docs.where((d) => d.id != uid).toList();
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final data = users[i].data() as Map<String, dynamic>;
                    final id = users[i].id;
                    final name = data['displayName'] ?? 'User';
                    return CheckboxListTile(
                      secondary: CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
                      title: Text(name),
                      value: _selected.contains(id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(id);
                        } else {
                          _selected.remove(id);
                        }
                      }),
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
}
