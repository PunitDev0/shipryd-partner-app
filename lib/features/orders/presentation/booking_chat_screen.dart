import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:partner/core/socket_client.dart';
import 'package:partner/shared/theme/app_colors.dart';

class ChatMessage {
  final String text;
  final String sender; // 'customer' or 'partner'
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.sender,
    required this.timestamp,
  });
}

class BookingChatScreen extends StatefulWidget {
  final String bookingId;
  final String peerName;

  const BookingChatScreen({
    super.key,
    required this.bookingId,
    required this.peerName,
  });

  @override
  State<BookingChatScreen> createState() => _BookingChatScreenState();
}

class _BookingChatScreenState extends State<BookingChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  void _connectSocket() {
    final socket = SocketClient.instance.socket;
    if (socket != null) {
      socket.emit('booking:join', widget.bookingId);
      socket.on('chat:message', _onChatMessage);
    }
  }

  void _onChatMessage(dynamic data) {
    if (!mounted) return;
    final map = Map<String, dynamic>.from(data as Map);
    if (map['bookingId'] != widget.bookingId) return;

    setState(() {
      _messages.add(ChatMessage(
        text: map['text'] as String,
        sender: map['from'] as String,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final socket = SocketClient.instance.socket;
    if (socket != null) {
      final payload = {
        'bookingId': widget.bookingId,
        'text': text,
      };
      socket.emit('chat:message', payload);
      setState(() {
        _messages.add(ChatMessage(
          text: text,
          sender: 'partner',
          timestamp: DateTime.now(),
        ));
      });
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    final socket = SocketClient.instance.socket;
    if (socket != null) {
      socket.off('chat:message', _onChatMessage);
      socket.emit('booking:leave', widget.bookingId);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kBg = AppColors.background;
    final kCardBg = AppColors.cardBg;
    final kYellow = AppColors.primary;
    final kText = AppColors.textPrimary;
    final kMuted = AppColors.textSecondary;
    final kBorder = AppColors.border;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: kText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.peerName,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kText,
              ),
            ),
            Text(
              'Customer Chat',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: kYellow,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(height: 1, color: kBorder),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: kBorder),
                          const SizedBox(height: 12),
                          Text(
                            'Start conversation with client',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: kMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg.sender == 'partner';
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isMe ? kYellow : kCardBg,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                              ),
                              border: isMe ? null : Border.all(color: kBorder),
                            ),
                            child: Text(
                              msg.text,
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                color: isMe ? Colors.black : kText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: kCardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: kBorder),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: GoogleFonts.outfit(fontSize: 13.5, color: kText),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: GoogleFonts.outfit(fontSize: 13.5, color: kMuted),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: kYellow,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
