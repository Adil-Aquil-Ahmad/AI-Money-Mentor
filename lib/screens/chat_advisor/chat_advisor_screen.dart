import 'package:flutter/material.dart';
import 'dart:ui';
import '../../theme/app_colors.dart';
import '../../components/common/glass_card.dart';
import '../../models/message.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';

class ChatAdvisorScreen extends StatefulWidget {
  const ChatAdvisorScreen({Key? key}) : super(key: key);

  @override
  State<ChatAdvisorScreen> createState() => _ChatAdvisorScreenState();
}

class _ChatAdvisorScreenState extends State<ChatAdvisorScreen> {
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  List<Message> messages = [];
  bool isTyping = false;
  String _inputMode = 'free'; // 'free' or 'dropdown'
  String? _selectedDropdownValue;
  String _errorMessage = '';
  bool _backendConnected = false;

  final List<String> _predefinedQuestions = [
    'What is my current financial health?',
    'When can I retire (FIRE)?',
    'How is my portfolio performing?',
    'What should I invest in?',
    'Simulate: Increase savings by 20%',
    'What are my investment goals?',
  ];

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _checkBackendConnection();
    messages = [
      Message(
        id: 'init',
        role: 'advisor',
        text:
            "Hello! I'm your AI Money Mentor. Based on your profile, you have a moderate risk tolerance and your primary goal is buying a house in 5 years. How can I help you today?",
      ),
    ];
  }

  Future<void> _checkBackendConnection() async {
    try {
      final isConnected = await apiService.checkConnection();
      setState(() {
        _backendConnected = isConnected;
        if (isConnected) {
          _errorMessage = '';
        } else {
          _errorMessage = 'Backend unreachable. Check if server is running.';
        }
      });
    } catch (e) {
      setState(() {
        _backendConnected = false;
        _errorMessage = 'Connection error: $e';
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    String messageText = '';
    
    if (_inputMode == 'dropdown') {
      if (_selectedDropdownValue == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a question')),
        );
        return;
      }
      messageText = _selectedDropdownValue!;
      _selectedDropdownValue = null;
    } else {
      if (_messageController.text.isEmpty) return;
      messageText = _messageController.text;
      _messageController.clear();
    }

    final userMessage = Message(
      id: DateTime.now().toString(),
      role: 'user',
      text: messageText,
    );

    setState(() {
      messages.add(userMessage);
      isTyping = true;
    });

    _scrollToBottom();

    try {
      // Call backend API
      final response = await apiService.post<ChatMessageResponse>(
        '/chat/message',
        body: ChatMessageRequest(
          userId: 'user_123', // TODO: Replace with actual user ID
          message: messageText,
        ).toJson(),
        fromJson: (json) => ChatMessageResponse.fromJson(json),
        requireAuth: false,
      );

      final advisorMessage = Message(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        role: 'advisor',
        text: response.message,
        data: response.data != null
            ? MessageData(type: 'data', content: response.data!)
            : null,
      );

      setState(() {
        messages.add(advisorMessage);
        isTyping = false;
      });
    } catch (e) {
      final errorMessage = Message(
        id: (DateTime.now().millisecondsSinceEpoch + 2).toString(),
        role: 'advisor',
        text: 'Sorry, I encountered an error: ${e.toString()}. Please try again.',
      );

      setState(() {
        messages.add(errorMessage);
        isTyping = false;
      });
    }

    _scrollToBottom();
  }


  void _clearChat() {
    setState(() {
      messages = [
        Message(
          id: 'init',
          role: 'advisor',
          text: 'Chat history cleared. How can I assist you now?',
        ),
      ];
    });
  }

  void _toggleInputMode() {
    setState(() {
      _inputMode = _inputMode == 'free' ? 'dropdown' : 'free';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      children: [
        // Connection Status Banner
        if (!_backendConnected)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.red.withOpacity(0.2),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
                GestureDetector(
                  onTap: _checkBackendConnection,
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Enhanced Header
        Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.whiteOpacity(0.2),
                    width: 1.5,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.whiteOpacity(0.1),
                      AppColors.whiteOpacity(0.05),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                padding: EdgeInsets.all(isMobile ? 12 : 20),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [Colors.white, AppColors.primary],
                                ).createShader(bounds),
                                child: const Text(
                                  'AI Chat Advisor',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _backendConnected
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Personalized financial advice',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _clearChat,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                      color: AppColors.primary.withOpacity(0.1),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.refresh,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Clear',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _toggleInputMode,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                      color: AppColors.primary.withOpacity(0.1),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _inputMode == 'dropdown'
                                              ? Icons.list
                                              : Icons.edit,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _inputMode == 'dropdown'
                                              ? 'Quick'
                                              : 'Type',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [Colors.white, AppColors.primary],
                                  ).createShader(bounds),
                                  child: const Text(
                                    'AI Chat Advisor',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Personalized, data-driven financial advice',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textTertiary,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _backendConnected
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _clearChat,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                color: AppColors.primary.withOpacity(0.1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.refresh,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Clear',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _toggleInputMode,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                color: AppColors.primary.withOpacity(0.1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _inputMode == 'dropdown'
                                        ? Icons.list
                                        : Icons.edit,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _inputMode == 'dropdown'
                                        ? 'Quick Ask'
                                        : 'Free Type',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        // Chat Area
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: 12,
            ),
            itemCount: messages.length + (isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == messages.length && isTyping) {
                return _buildTypingIndicator();
              }

              final message = messages[index];
              return _buildMessageBubble(message);
            },
          ),
        ),
        // Input Area
        Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          child: GlassCard(
            borderRadius: 24,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 8 : 12,
            ),
            backgroundColor: AppColors.background.withOpacity(0.6),
            blurAmount: 120,
            child: _inputMode == 'free'
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.w400,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                          enabled: _backendConnected,
                          decoration: InputDecoration(
                            hintText: _backendConnected
                                ? (isMobile
                                    ? 'Ask about portfolio...'
                                    : 'Ask about your portfolio, a specific stock...')
                                : 'Backend not connected...',
                            hintStyle: TextStyle(
                              color: AppColors.textTertiary.withOpacity(0.7),
                              fontSize: isMobile ? 12 : 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: isMobile ? 6 : 8,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _backendConnected ? _sendMessage : null,
                        child: Container(
                          width: isMobile ? 40 : 48,
                          height: isMobile ? 40 : 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: AppColors.primaryGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: isMobile ? 18 : 20,
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedDropdownValue,
                          items: _predefinedQuestions.map((question) {
                            return DropdownMenuItem(
                              value: question,
                              child: Text(
                                question,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: _backendConnected
                              ? (value) {
                                  setState(() {
                                    _selectedDropdownValue = value;
                                  });
                                }
                              : null,
                          decoration: InputDecoration(
                            hintText: 'Select a question',
                            hintStyle: TextStyle(
                              color: AppColors.textTertiary.withOpacity(0.7),
                              fontSize: isMobile ? 12 : 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: isMobile ? 6 : 8,
                            ),
                            filled: false,
                          ),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: isMobile ? 14 : 16,
                          ),
                          dropdownColor: Color(0xFF153C6A),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.primary,
                            size: isMobile ? 18 : 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _backendConnected ? _sendMessage : null,
                        child: Container(
                          width: isMobile ? 40 : 48,
                          height: isMobile ? 40 : 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: AppColors.primaryGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: isMobile ? 18 : 20,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isUser = message.role == 'user';
    final isMobile = MediaQuery.of(context).size.width < 768;
    final avatarSize = isMobile ? 32.0 : 40.0;
    final avatarIconSize = isMobile ? 16.0 : 20.0;
    final bubblePadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 18, vertical: 14);
    final bubbleRadius = isMobile ? 16.0 : 20.0;
    final textSize = isMobile ? 13.0 : 15.0;

    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: avatarSize,
              height: avatarSize,
              margin: EdgeInsets.only(right: isMobile ? 8 : 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: avatarIconSize,
              ),
            ),
          Flexible(
            child: GlassCard(
              borderRadius: bubbleRadius,
              padding: bubblePadding,
              backgroundColor: isUser
                  ? Color(0xFF733E85).withOpacity(0.15)
                  : Color(0xFF153C6A).withOpacity(0.2),
              blurAmount: 120,
              glowColor: isUser
                  ? const Color(0xFFE977F5)
                  : AppColors.primary,
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: textSize,
                  color: AppColors.textSecondary,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          if (isUser)
            Container(
              width: avatarSize,
              height: avatarSize,
              margin: EdgeInsets.only(left: isMobile ? 8 : 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFE977F5), Color(0xFF733E85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE977F5).withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: avatarIconSize,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final avatarSize = isMobile ? 32.0 : 40.0;
    final avatarIconSize = isMobile ? 16.0 : 20.0;

    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            margin: EdgeInsets.only(right: isMobile ? 8 : 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: AppColors.primaryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: avatarIconSize,
            ),
          ),
          GlassCard(
            borderRadius: isMobile ? 16 : 20,
            padding: isMobile
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                : const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            backgroundColor: Color(0xFF153C6A).withOpacity(0.2),
            blurAmount: 120,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                SizedBox(width: isMobile ? 4 : 6),
                _buildDot(150),
                SizedBox(width: isMobile ? 4 : 6),
                _buildDot(300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      onEnd: () {
        // Restart animation
      },
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                AppColors.primary.withOpacity((value * 0.8).toDouble()),
          ),
        );
      },
    );
  }
}
