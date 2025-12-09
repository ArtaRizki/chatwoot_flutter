import 'dart:convert';
import 'dart:developer';
import 'dart:async';
import 'package:chatwoot_flutter/chat_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Halaman 1: Daftar Conversations
class ConversationsListPage extends StatefulWidget {
  const ConversationsListPage({super.key});

  @override
  State<ConversationsListPage> createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  // Konfigurasi Chatwoot
  final String baseUrl = "https://exm.connectowl.io";
  final String apiKey = "wek6kMCqN1C2ab13AbwwQ5At";
  final String accountId = "14";
  final String inboxId = "80";

  List<Map<String, dynamic>> conversations = [];
  bool isLoadingConversations = false;
  Timer? _autoRefreshTimer;
  String filter = 'all'; // all, open, resolved

  @override
  void initState() {
    super.initState();
    loadConversations();
    // Auto refresh setiap 10 detik
    _autoRefreshTimer = Timer.periodic(Duration(seconds: 10), (_) {
      if (mounted) {
        loadConversations();
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // Load semua conversations dari inbox
  Future<void> loadConversations() async {
    setState(() {
      isLoadingConversations = true;
    });

    try {
      final url = Uri.parse(
        '$baseUrl/api/v1/accounts/$accountId/conversations?inbox_id=$inboxId&status=$filter',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'api_access_token': apiKey,
        },
      );

      log("Load conversations response: ${response.statusCode}");
      log("Load conversations response body : ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          conversations = List<Map<String, dynamic>>.from(
            data['data']['payload'] ?? [],
          );
          isLoadingConversations = false;
        });

        log("Loaded ${conversations.length} conversations");
      } else {
        log("Error loading conversations: ${response.body}");
        setState(() {
          isLoadingConversations = false;
        });
      }
    } catch (e) {
      log("Error loading conversations: $e");
      setState(() {
        isLoadingConversations = false;
      });
    }
  }

  String formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Text('Briton CS Dashboard'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: loadConversations),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                filter = value;
              });
              loadConversations();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'all', child: Text('All')),
              PopupMenuItem(value: 'open', child: Text('Open')),
              PopupMenuItem(value: 'resolved', child: Text('Resolved')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Conversations',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Chip(
                    label: Text(
                      '${conversations.length}',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.blue,
                  ),
                ],
              ),
            ),

            // Conversations List
            Expanded(
              child:
                  // isLoadingConversations ? Center(child: CircularProgressIndicator()) :
                  conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No conversations',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: loadConversations,
                      child: ListView.builder(
                        itemCount: conversations.length,
                        itemBuilder: (context, index) {
                          final conv = conversations[index];
                          final contact = conv['meta']?['sender'];
                          final unreadCount = conv['unread_count'] ?? 0;

                          return InkWell(
                            onTap: () {
                              // Navigate ke halaman detail chat
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatDetailPage(
                                    conversation: conv,
                                    baseUrl: baseUrl,
                                    apiKey: apiKey,
                                    accountId: accountId,
                                  ),
                                ),
                              ).then((result) {
                                // <--- ADDED .then() block to handle result
                                // Refresh conversations saat kembali, especially if status was changed
                                if (result == true) {
                                  loadConversations();
                                } else {
                                  // This path runs on regular back press (like Mark as Read)
                                  loadConversations();
                                }
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Avatar
                                  CircleAvatar(
                                    backgroundColor: Colors.blue,
                                    radius: 22,
                                    child: Text(
                                      (contact?['name'] ?? 'U')[0]
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),

                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                contact?['name'] ?? 'Unknown',
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              formatTimestamp(
                                                conv['timestamp'] ?? 0,
                                              ),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                conv['last_non_activity_message']?['content'] ??
                                                    'No messages',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade700,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (unreadCount > 0)
                                              Container(
                                                margin: EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '$unreadCount',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Arrow icon
                                  SizedBox(width: 8),
                                  Icon(Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
