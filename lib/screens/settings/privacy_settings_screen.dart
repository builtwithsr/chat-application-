import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance.collection(FirestoreCollections.users).doc(uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Settings')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: docRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final showReadReceipts = data['showReadReceipts'] ?? true;
          final showLastSeen = data['showLastSeen'] ?? true;
          final showOnlineStatus = data['showOnlineStatus'] ?? true;
          final blocked = List<String>.from(data['blockedUsers'] ?? []);

          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Read Receipts'),
                subtitle: const Text('Let others see when you\'ve read their messages'),
                value: showReadReceipts,
                onChanged: (v) => docRef.update({'showReadReceipts': v}),
              ),
              SwitchListTile(
                title: const Text('Last Seen'),
                subtitle: const Text('Show your last seen time to others'),
                value: showLastSeen,
                onChanged: (v) => docRef.update({'showLastSeen': v}),
              ),
              SwitchListTile(
                title: const Text('Online Status'),
                subtitle: const Text('Show when you\'re online'),
                value: showOnlineStatus,
                onChanged: (v) => docRef.update({'showOnlineStatus': v}),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Blocked Users (${blocked.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (blocked.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('No blocked users', style: TextStyle(color: Colors.grey)),
                ),
              ...blocked.map((blockedUid) => FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection(FirestoreCollections.users).doc(blockedUid).get(),
                    builder: (context, userSnap) {
                      final name = userSnap.hasData && userSnap.data!.exists
                          ? (userSnap.data!.data() as Map<String, dynamic>)['displayName'] ?? 'User'
                          : '...';
                      return ListTile(
                        leading: const Icon(Icons.block, color: Colors.red),
                        title: Text(name),
                        trailing: TextButton(
                          onPressed: () => docRef.update({
                            'blockedUsers': FieldValue.arrayRemove([blockedUid])
                          }),
                          child: const Text('Unblock'),
                        ),
                      );
                    },
                  )),
            ],
          );
        },
      ),
    );
  }
}
