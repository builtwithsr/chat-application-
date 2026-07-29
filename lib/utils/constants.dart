class FirestoreCollections {
  static const users = 'users';
  static const chats = 'chats';
  static const messages = 'messages';
}

class MessageType {
  static const text = 'text';
  static const poll = 'poll';
  static const location = 'location';
}

class MessageStatus {
  static const sent = 'sent';
  static const delivered = 'delivered';
  static const read = 'read';
}

class ChatType {
  static const direct = 'direct';
  static const group = 'group';
}

const List<String> quickReactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

const int messagePageSize = 30;
