class Message {
  final String id;
  final String role; // 'user' or 'advisor'
  final String text;
  final MessageData? data;

  Message({
    required this.id,
    required this.role,
    required this.text,
    this.data,
  });
}

class MessageData {
  final String type; // 'stock', etc
  final Map<String, dynamic> content;

  MessageData({
    required this.type,
    required this.content,
  });
}
