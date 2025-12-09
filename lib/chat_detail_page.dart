// chat_detail_page.dart

import 'dart:convert';
import 'dart:developer';
import 'dart:async';
import 'dart:io';

import 'package:chatwoot_flutter/image_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

// Halaman 2: Detail Chat
class ChatDetailPage extends StatefulWidget {
  final Map<String, dynamic> conversation;
  final String baseUrl;
  final String apiKey;
  final String accountId;

  const ChatDetailPage({
    super.key,
    required this.conversation,
    required this.baseUrl,
    required this.apiKey,
    required this.accountId,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  List<Map<String, dynamic>> messages = [];
  bool isLoadingMessages = false;
  bool isSending = false;
  // Menjaga status percakapan lokal agar UI AppBar tetap responsif
  String currentStatus = 'open';

  final TextEditingController _replyController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  Timer? _autoRefreshTimer;
  File? _selectedAttachment;

  @override
  void initState() {
    super.initState();
    // Inisialisasi status awal dari widget.conversation
    currentStatus = widget.conversation['status'] ?? 'open';
    loadMessages();
    markAsRead(); // Mark as read immediately on open

    // Auto refresh setiap 5 detik
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        loadMessages();
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _replyController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  // MARK AS READ FEATURE
  Future<void> markAsRead() async {
    try {
      final conversationId = widget.conversation['id'];
      final url = Uri.parse(
        '${widget.baseUrl}/api/v1/accounts/${widget.accountId}/conversations/$conversationId/update_last_seen',
      );

      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'api_access_token': widget.apiKey,
        },
      );
    } catch (e) {
      log("Error marking conversation as read: $e");
    }
  }

  // Load messages dari conversation
  Future<void> loadMessages() async {
    if (isLoadingMessages) return;

    setState(() {
      isLoadingMessages = true;
    });

    try {
      final conversationId = widget.conversation['id'];
      final url = Uri.parse(
        '${widget.baseUrl}/api/v1/accounts/${widget.accountId}/conversations/$conversationId/messages',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'api_access_token': widget.apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Asumsi struktur response: {'data': {'payload': [pesan1, pesan2, ...]}}
        final rawMessages = data['payload'] as List<dynamic>? ?? [];

        // Chatwoot mengembalikan pesan dengan yang terbaru di bawah, jadi kita perlu
        // membalikkan urutan untuk ListView.builder (index 0 = pesan pertama)
        final newMessages = List<Map<String, dynamic>>.from(
          rawMessages,
        ).toList();

        // Periksa apakah ada pesan baru atau perubahan status
        final isNewMessages = newMessages.length != messages.length;

        // Cek status terbaru dari conversation, jika API mengembalikan detail conversation
        final updatedStatus = data['status'] ?? currentStatus;

        if (isNewMessages || updatedStatus != currentStatus) {
          setState(() {
            messages = newMessages;
            currentStatus = updatedStatus; // Update status lokal
          });

          // Scroll to bottom only if new messages
          if (isNewMessages) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_messageScrollController.hasClients) {
                _messageScrollController.animateTo(
                  _messageScrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        }
      } else {
        log("Failed to load messages: ${response.statusCode}");
      }
    } catch (e) {
      log("Error loading messages: $e");
    } finally {
      setState(() {
        isLoadingMessages = false;
      });
    }
  }

  // ATTACHMENT HANDLING - File Picker
  Future<void> pickAttachment() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        _selectedAttachment = File(result.files.single.path!);
      });
    } else {
      // User canceled the picker
      setState(() {
        _selectedAttachment = null;
      });
    }
  }

  // Kirim balasan ke customer (supports text and attachment)
  Future<void> sendReply() async {
    if (_replyController.text.isEmpty && _selectedAttachment == null) {
      return;
    }

    setState(() {
      isSending = true;
    });

    String successMessage = 'Pesan terkirim!';
    bool hasAttachment = _selectedAttachment != null;

    try {
      final conversationId = widget.conversation['id'];
      final url = Uri.parse(
        '${widget.baseUrl}/api/v1/accounts/${widget.accountId}/conversations/$conversationId/messages',
      );

      var request = http.MultipartRequest('POST', url)
        ..headers.addAll({'api_access_token': widget.apiKey})
        ..fields['content'] = _replyController.text
        ..fields['message_type'] = 'outgoing'
        ..fields['private'] = 'false';

      if (hasAttachment) {
        successMessage = 'File terkirim!';
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachments[]', // The correct field name for Chatwoot attachments
            _selectedAttachment!.path,
            filename: _selectedAttachment!.path.split('/').last,
          ),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        _replyController.clear();
        setState(() {
          _selectedAttachment = null;
        });
        await loadMessages();

        // Gunakan pesan sukses yang sudah diperbarui
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        log("Send reply failed: ${response.statusCode} - $responseBody");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mengirim pesan: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      log("Error sending reply: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        isSending = false;
      });
    }
  }

  // Resolve conversation
  Future<void> resolveConversation() async {
    await toggleStatus('resolved', 'Conversation resolved!');
  }

  // UNRESOLVE CONVERSATION FEATURE
  Future<void> unresolveConversation() async {
    await toggleStatus('open', 'Conversation reopened!');
  }

  // Fungsi utilitas untuk mengubah status
  Future<void> toggleStatus(String status, String message) async {
    try {
      final conversationId = widget.conversation['id'];
      final url = Uri.parse(
        '${widget.baseUrl}/api/v1/accounts/${widget.accountId}/conversations/$conversationId/toggle_status',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'api_access_token': widget.apiKey,
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          // Update status lokal
          setState(() {
            currentStatus = status;
          });

          // Berikan indikasi untuk halaman sebelumnya agar merefresh list
          Navigator.pop(context, true);

          // Tampilkan pesan sukses
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.green),
          );
        }
      } else {
        log("Toggle status failed: ${response.statusCode}");
      }
    } catch (e) {
      log("Error toggling status to $status: $e");
    }
  }

  /// Fungsi untuk membuka URL file (memerlukan package url_launcher)
  void _launchURL(String url) async {
    // Ganti dengan implementasi url_launcher yang sebenarnya
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Handle error, misalnya dengan menampilkan SnackBar
      log('Could not launch $url');
    }
    debugPrint('Launching URL for download/open: $url');
  }

  // Fungsi utilitas untuk format waktu
  String formatMessageTime(int timestamp) {
    // timestamp di Chatwoot adalah detik, harus dikalikan 1000 untuk milidetik
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('HH:mm').format(date);
  }

  // Fungsi utilitas untuk format tanggal
  String formatMessageDate(int timestamp) {
    // timestamp di Chatwoot adalah detik, harus dikalikan 1000 untuk milidetik
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ambil data contact dari conversation awal
    final contact = widget.conversation['meta']?['sender'];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 18,
              child: Text(
                (contact?['name'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact?['name'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    contact?['phone_number'] ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadMessages,
            tooltip: 'Refresh Messages',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'resolve') {
                resolveConversation();
              } else if (value == 'unresolve') {
                unresolveConversation();
              }
            },
            itemBuilder: (context) => [
              // Show Resolve if current status is 'open'
              if (currentStatus == 'open')
                PopupMenuItem(
                  value: 'resolve',
                  child: ListTile(
                    leading: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    title: const Text('Resolve'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              // Show Reopen if current status is 'resolved'
              if (currentStatus == 'resolved')
                PopupMenuItem(
                  value: 'unresolve',
                  child: ListTile(
                    leading: const Icon(Icons.undo, color: Colors.orange),
                    title: const Text('Reopen'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // List Pesan
            Expanded(
              child: isLoadingMessages && messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No messages yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _messageScrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        // message_type: 0-incoming, 1-outgoing, 2-activity
                        final isOutgoing = msg['message_type'] == 1;

                        // --- Logika untuk Attachment ---
                        final attachments =
                            msg['attachments'] as List<dynamic>?;
                        final attachment =
                            (attachments != null && attachments.isNotEmpty)
                            ? attachments[0]
                            : null;

                        // File type 'file' di Chatwoot mencakup gambar
                        final isImage =
                            attachment != null &&
                            attachment['file_type'].toString() == 'file' &&
                            (attachment['data_url'].toString().contains(
                                  '.jpg',
                                ) ||
                                attachment['data_url'].toString().contains(
                                  '.jpeg',
                                ) ||
                                attachment['data_url'].toString().contains(
                                  '.png',
                                ) ||
                                attachment['data_url'].toString().contains(
                                  '.webp',
                                ));

                        // Menggunakan thumb_url untuk preview kecil di bubble
                        final imageUrl = isImage
                            ? attachment['thumb_url'] ?? attachment['data_url']
                            : null;

                        // Mengambil URL asli untuk pratinjau full-screen atau download
                        final fileUrl = attachment != null
                            ? attachment['data_url'] as String?
                            : null;

                        // --- Logika untuk Pembagi Tanggal ---
                        bool showDateDivider = false;
                        if (index == 0) {
                          showDateDivider = true;
                        } else {
                          final prevMsg = messages[index - 1];
                          final prevDate = DateTime.fromMillisecondsSinceEpoch(
                            (prevMsg['created_at'] ?? 0) * 1000,
                          );
                          final currentDate =
                              DateTime.fromMillisecondsSinceEpoch(
                                (msg['created_at'] ?? 0) * 1000,
                              );
                          // Tampilkan divider jika tanggal berbeda
                          if (prevDate.day != currentDate.day ||
                              prevDate.month != currentDate.month ||
                              prevDate.year != currentDate.year) {
                            showDateDivider = true;
                          }
                        }
                        // --- End Logika Pembagi Tanggal ---

                        // --- Tampilan Pesan ---
                        return Column(
                          children: [
                            // Date Divider
                            if (showDateDivider)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    formatMessageDate(msg['created_at'] ?? 0),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),

                            // Message Bubble
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: isOutgoing
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Avatar untuk Incoming Message
                                  if (!isOutgoing)
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.grey.shade400,
                                      child: const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  if (!isOutgoing) const SizedBox(width: 8),

                                  // Bubble Container
                                  Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                          0.75,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isOutgoing
                                          ? Colors.blue.shade500
                                          : Colors.white,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(
                                          isOutgoing ? 16 : 4,
                                        ),
                                        bottomRight: Radius.circular(
                                          isOutgoing ? 4 : 16,
                                        ),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // --- Image Rendering with Preview Logic ---
                                        if (isImage && imageUrl != null)
                                          GestureDetector(
                                            onTap: () {
                                              // Gunakan fileUrl (URL asli) untuk pratinjau layar penuh
                                              if (fileUrl != null) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        ImagePreviewPage(
                                                          imageUrl: fileUrl,
                                                        ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.network(
                                                imageUrl, // Gunakan imageUrl (thumbnail) untuk di dalam bubble
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Container(
                                                      width: 150,
                                                      height: 100,
                                                      color:
                                                          Colors.grey.shade200,
                                                      child: Center(
                                                        child: Icon(
                                                          Icons.broken_image,
                                                          color: Colors
                                                              .red
                                                              .shade400,
                                                        ),
                                                      ),
                                                    ),
                                                loadingBuilder:
                                                    (
                                                      context,
                                                      child,
                                                      loadingProgress,
                                                    ) {
                                                      if (loadingProgress ==
                                                          null) {
                                                        return child;
                                                      }
                                                      return Container(
                                                        width: 200,
                                                        height: 150,
                                                        decoration: BoxDecoration(
                                                          color: isOutgoing
                                                              ? Colors
                                                                    .blue
                                                                    .shade400
                                                              : Colors
                                                                    .grey
                                                                    .shade200,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        child: Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                                color:
                                                                    isOutgoing
                                                                    ? Colors
                                                                          .white
                                                                    : Colors
                                                                          .blue,
                                                                strokeWidth: 2,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                              ),
                                            ),
                                          ),

                                        // Tambahkan padding vertikal jika ada gambar DAN ada teks
                                        if (isImage &&
                                            imageUrl != null &&
                                            (msg['content'] ?? '').isNotEmpty)
                                          const SizedBox(height: 8),

                                        // Message Content
                                        if ((msg['content'] ?? '').isNotEmpty)
                                          Text(
                                            msg['content'] ?? '',
                                            style: TextStyle(
                                              color: isOutgoing
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontSize: 15,
                                            ),
                                          ),

                                        // Attachment Indicator (Non-image/Non-text attachment)
                                        if (attachment != null &&
                                            !isImage &&
                                            (msg['content'] ?? '').isEmpty)
                                          GestureDetector(
                                            onTap: () {
                                              // Panggil fungsi untuk membuka atau mengunduh file
                                              if (fileUrl != null) {
                                                _launchURL(fileUrl);
                                              }
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.insert_drive_file,
                                                  size: 16,
                                                  color: isOutgoing
                                                      ? Colors.white70
                                                      : Colors.blue.shade700,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    // Ganti teks untuk menunjukkan tindakan
                                                    'Tap to Open: ${attachment['file_type'] ?? 'Attachment'}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: isOutgoing
                                                          ? Colors.white70
                                                          : Colors
                                                                .grey
                                                                .shade700,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      decoration: TextDecoration
                                                          .underline, // Tambah underline
                                                      decorationColor:
                                                          isOutgoing
                                                          ? Colors.white70
                                                          : Colors
                                                                .blue
                                                                .shade700,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        const SizedBox(height: 4),

                                        // Waktu dan Status
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              formatMessageTime(
                                                msg['created_at'] ?? 0,
                                              ),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isOutgoing
                                                    ? Colors.white70
                                                    : Colors.grey.shade600,
                                              ),
                                            ),
                                            if (isOutgoing) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                msg['status'] == 'sent'
                                                    ? Icons.done
                                                    : Icons
                                                          .done_all, // done = sent, done_all = delivered/read
                                                size: 14,
                                                color: Colors.white70,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Avatar untuk Outgoing Message
                                  if (isOutgoing) const SizedBox(width: 8),
                                  if (isOutgoing)
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.blue.shade200,
                                      child: const Icon(
                                        Icons.support_agent,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            // Attachment Preview Box
            if (_selectedAttachment != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.blue.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedAttachment!.path.split('/').last,
                        style: TextStyle(color: Colors.blue.shade800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _selectedAttachment = null;
                        });
                      },
                    ),
                  ],
                ),
              ),

            // Reply Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top:
                    false, // Penting untuk menghindari padding di bagian atas notch
                child: Row(
                  children: [
                    // Attachment Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        onPressed: isSending ? null : pickAttachment,
                        icon: const Icon(Icons.attach_file, color: Colors.grey),
                        tooltip: 'Attach File',
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _replyController,
                          enabled: !isSending,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          onSubmitted: (_) => sendReply(),
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send Button
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: isSending ? null : sendReply,
                        icon: isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                        tooltip: 'Send Message',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
