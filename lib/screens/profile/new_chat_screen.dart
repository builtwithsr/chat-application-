import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/chat_service.dart';
import '../../utils/constants.dart';
import '../chat_detail/chat_detail_screen.dart';
import '../../models/chat_model.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final uid = context.read<app_auth.AuthProvider>().firebaseUser!.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(FirestoreCollections.users).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final myProfile = context.read<app_auth.AuthProvider>().profile;
          final myBlockedList = myProfile?.blockedUsers ?? [];

          final users = snapshot.data!.docs.where((d) {
            final uid = d.id;
            if (uid == context.read<app_auth.AuthProvider>().firebaseUser!.uid) return false;
            
            // Filter out users I have blocked
            if (myBlockedList.contains(uid)) return false;

            final data = d.data() as Map<String, dynamic>;
            
            // Filter out users who have blocked ME
            final theirBlockedList = List<String>.from(data['blockedUsers'] ?? []);
            if (theirBlockedList.contains(myProfile?.uid)) return false;

            final name = (data['displayName'] ?? '').toString().toLowerCase();
            return _query.isEmpty || name.contains(_query);
          }).toList();

          if (users.isEmpty) {
            return const Center(child: Text('No users found'));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final data = users[i].data() as Map<String, dynamic>;
              final name = data['displayName'] ?? 'User';
              return ListTile(
                leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
                title: Text(name),
                subtitle: Text(data['email'] ?? ''),
                onTap: () async {
                  final chatId = await ChatService().getOrCreateDirectChat(users[i].id);
                  if (!context.mounted) return;
                  final chatDoc = await FirebaseFirestore.instance
                      .collection(FirestoreCollections.chats)
                      .doc(chatId)
                      .get();
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: ChatModel.fromDoc(chatDoc))),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
