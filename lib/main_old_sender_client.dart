// import 'dart:convert';
// import 'dart:developer';
// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Briton WhatsApp Manager',
//       theme: ThemeData(
//         primarySwatch: Colors.green,
//         brightness: Brightness.dark,
//       ),
//       home: MyHomePage(),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key});

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage>
//     with SingleTickerProviderStateMixin {
//   // Konfigurasi dari Chatwoot Anda
//   final String baseUrl = "https://exm.connectowl.io";
//   final String apiKey = "wek6kMCqN1C2ab13AbwwQ5At";
//   final String accountId = "14";
//   final String inboxId = "80";

//   late TabController _tabController;

//   // Controllers untuk Single Message
//   final TextEditingController _phoneController = TextEditingController();
//   final TextEditingController _messageController = TextEditingController();

//   // Controllers untuk Broadcast
//   final TextEditingController _broadcastMessageController =
//       TextEditingController();
//   final TextEditingController _phoneNumberController = TextEditingController();

//   // State
//   bool _isLoading = false;
//   String _statusMessage = "";
//   File? _selectedImage;
//   List<String> _phoneNumbers = [];
//   List<Map<String, dynamic>> _messageHistory = [];
//   List<Map<String, dynamic>> _templates = [];
//   String? _selectedTemplate;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 4, vsync: this);
//     _loadMessageHistory();
//     _loadTemplates();
//   }

//   // Load message history dari SharedPreferences
//   Future<void> _loadMessageHistory() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final historyJson = prefs.getString('message_history');
//       if (historyJson != null) {
//         final List<dynamic> decoded = jsonDecode(historyJson);
//         setState(() {
//           _messageHistory = decoded.cast<Map<String, dynamic>>();
//         });
//       }
//     } catch (e) {
//       log("Error loading history: $e");
//     }
//   }

//   // Save message history
//   Future<void> _saveMessageHistory(Map<String, dynamic> message) async {
//     try {
//       _messageHistory.insert(0, message);
//       if (_messageHistory.length > 50) {
//         _messageHistory = _messageHistory.sublist(0, 50);
//       }

//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('message_history', jsonEncode(_messageHistory));
//       setState(() {});
//     } catch (e) {
//       log("Error saving history: $e");
//     }
//   }

//   // Load templates dari API
//   Future<void> _loadTemplates() async {
//     try {
//       final url = Uri.parse(
//         '$baseUrl/api/v1/accounts/$accountId/inboxes/$inboxId',
//       );
//       final response = await http.get(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'api_access_token': apiKey,
//         },
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         if (data['message_templates'] != null) {
//           setState(() {
//             _templates = List<Map<String, dynamic>>.from(
//               data['message_templates'],
//             );
//           });
//         }
//       }
//     } catch (e) {
//       log("Error loading templates: $e");
//     }
//   }

//   // Pick image
//   Future<void> _pickImage() async {
//     try {
//       final picker = ImagePicker();
//       final image = await picker.pickImage(source: ImageSource.gallery);

//       if (image != null) {
//         setState(() {
//           _selectedImage = File(image.path);
//         });
//       }
//     } catch (e) {
//       log("Error picking image: $e");
//       _showSnackBar("Error memilih gambar: $e", Colors.red);
//     }
//   }

//   // Upload image ke Chatwoot
//   Future<String?> _uploadImage(File image, int conversationId) async {
//     try {
//       final url = Uri.parse(
//         '$baseUrl/api/v1/accounts/$accountId/conversations/$conversationId/messages',
//       );

//       var request = http.MultipartRequest('POST', url);
//       request.headers['api_access_token'] = apiKey;
//       request.fields['message_type'] = 'outgoing';
//       request.fields['private'] = 'false';

//       request.files.add(
//         await http.MultipartFile.fromPath('attachments[]', image.path),
//       );

//       final response = await request.send();
//       final responseData = await response.stream.bytesToString();

//       log("Upload image response: ${response.statusCode}");
//       log("Upload image body: $responseData");

//       return response.statusCode == 200 ? responseData : null;
//     } catch (e) {
//       log("Error uploading image: $e");
//       return null;
//     }
//   }

//   // Find or create contact
//   Future<Map<String, dynamic>?> findOrCreateContact(String phoneNumber) async {
//     try {
//       String formattedPhone = phoneNumber;
//       if (!phoneNumber.startsWith('+')) {
//         formattedPhone = '+62${phoneNumber.replaceFirst(RegExp(r'^0+'), '')}';
//       }

//       log("Mencari contact dengan nomor: $formattedPhone");

//       final searchUrl = Uri.parse(
//         '$baseUrl/api/v1/accounts/$accountId/contacts/search?q=$formattedPhone',
//       );
//       final searchResponse = await http.get(
//         searchUrl,
//         headers: {
//           'Content-Type': 'application/json',
//           'api_access_token': apiKey,
//         },
//       );

//       if (searchResponse.statusCode == 200) {
//         final searchData = jsonDecode(searchResponse.body);
//         if (searchData['payload'] != null && searchData['payload'].isNotEmpty) {
//           log("Contact ditemukan: ${searchData['payload'][0]['id']}");
//           return searchData['payload'][0];
//         }
//       }

//       log("Contact tidak ditemukan, membuat baru...");
//       final createUrl = Uri.parse(
//         '$baseUrl/api/v1/accounts/$accountId/contacts',
//       );
//       final createResponse = await http.post(
//         createUrl,
//         headers: {
//           'Content-Type': 'application/json',
//           'api_access_token': apiKey,
//         },
//         body: jsonEncode({
//           'inbox_id': inboxId,
//           'name': formattedPhone,
//           'phone_number': formattedPhone,
//           'identifier': formattedPhone,
//         }),
//       );

//       if (createResponse.statusCode == 200 ||
//           createResponse.statusCode == 201) {
//         final contactData = jsonDecode(createResponse.body);
//         log("Contact baru dibuat: ${contactData['payload']['contact']['id']}");
//         return contactData['payload']['contact'];
//       }

//       return null;
//     } catch (e) {
//       log("Error find/create contact: $e");
//       return null;
//     }
//   }

//   // Create conversation
//   Future<Map<String, dynamic>?> createConversation(int contactId) async {
//     try {
//       log("Membuat conversation untuk contact ID: $contactId");

//       final url = Uri.parse(
//         '$baseUrl/api/v1/accounts/$accountId/conversations',
//       );
//       final response = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'api_access_token': apiKey,
//         },
//         body: jsonEncode({
//           'source_id': contactId.toString(),
//           'inbox_id': inboxId,
//           'contact_id': contactId,
//           'status': 'open',
//         }),
//       );

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         return jsonDecode(response.body);
//       }

//       return null;
//     } catch (e) {
//       log("Error create conversation: $e");
//       return null;
//     }
//   }

//   // Send message
//   Future<bool> sendMessage(int conversationId, String message) async {
//     try {
//       log("Mengirim pesan ke conversation ID: $conversationId");

//       final url = Uri.parse(
//         '$baseUrl/api/v1/accounts/$accountId/conversations/$conversationId/messages',
//       );
//       final response = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'api_access_token': apiKey,
//         },
//         body: jsonEncode({
//           'content': message,
//           'message_type': 'outgoing',
//           'private': false,
//         }),
//       );

//       log("Send message response: ${response.statusCode}");
//       return response.statusCode == 200 || response.statusCode == 201;
//     } catch (e) {
//       log("Error send message: $e");
//       return false;
//     }
//   }

//   // Send single message with image
//   Future<void> sendWhatsAppMessage() async {
//     if (_phoneController.text.isEmpty || _messageController.text.isEmpty) {
//       _showSnackBar("Nomor dan pesan harus diisi!", Colors.red);
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _statusMessage = "⏳ Memproses...";
//     });

//     try {
//       final contact = await findOrCreateContact(_phoneController.text);
//       if (contact == null) {
//         setState(() {
//           _statusMessage = "❌ Gagal membuat contact";
//           _isLoading = false;
//         });
//         return;
//       }

//       final contactId = contact['id'];
//       final conversation = await createConversation(contactId);
//       if (conversation == null) {
//         setState(() {
//           _statusMessage = "❌ Gagal membuat conversation";
//           _isLoading = false;
//         });
//         return;
//       }

//       final conversationId = conversation['id'];

//       // Send text message
//       final success = await sendMessage(
//         conversationId,
//         _messageController.text,
//       );

//       // Upload image if selected
//       if (_selectedImage != null && success) {
//         await _uploadImage(_selectedImage!, conversationId);
//       }

//       if (success) {
//         // Save to history
//         await _saveMessageHistory({
//           'phone': _phoneController.text,
//           'message': _messageController.text,
//           'timestamp': DateTime.now().toIso8601String(),
//           'hasImage': _selectedImage != null,
//           'status': 'sent',
//         });

//         setState(() {
//           _statusMessage = "✅ Pesan berhasil dikirim!";
//           _isLoading = false;
//         });

//         _phoneController.clear();
//         _messageController.clear();
//         _selectedImage = null;

//         _showSnackBar("Pesan berhasil dikirim!", Colors.green);
//       } else {
//         setState(() {
//           _statusMessage = "❌ Gagal mengirim pesan";
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _statusMessage = "❌ Error: $e";
//         _isLoading = false;
//       });
//     }
//   }

//   // Send broadcast messages
//   Future<void> sendBroadcastMessages() async {
//     if (_phoneNumbers.isEmpty || _broadcastMessageController.text.isEmpty) {
//       _showSnackBar("Tambahkan nomor dan tulis pesan!", Colors.red);
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _statusMessage = "⏳ Mengirim broadcast...";
//     });

//     int success = 0;
//     int failed = 0;

//     for (String phone in _phoneNumbers) {
//       try {
//         final contact = await findOrCreateContact(phone);
//         if (contact != null) {
//           final conversation = await createConversation(contact['id']);
//           if (conversation != null) {
//             final sent = await sendMessage(
//               conversation['id'],
//               _broadcastMessageController.text,
//             );

//             if (sent) {
//               success++;
//               await _saveMessageHistory({
//                 'phone': phone,
//                 'message': _broadcastMessageController.text,
//                 'timestamp': DateTime.now().toIso8601String(),
//                 'type': 'broadcast',
//                 'status': 'sent',
//               });
//             } else {
//               failed++;
//             }
//           }
//         }

//         // Delay to avoid rate limiting
//         await Future.delayed(Duration(seconds: 2));
//       } catch (e) {
//         log("Error sending to $phone: $e");
//         failed++;
//       }
//     }

//     setState(() {
//       _statusMessage =
//           "✅ Broadcast selesai! Berhasil: $success, Gagal: $failed";
//       _isLoading = false;
//     });

//     _showSnackBar(
//       "Broadcast selesai! Berhasil: $success, Gagal: $failed",
//       success > 0 ? Colors.green : Colors.red,
//     );
//   }

//   void _showSnackBar(String message, Color color) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: color,
//         duration: Duration(seconds: 3),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: Text('Briton WhatsApp Manager'),
//         backgroundColor: Colors.green.shade700,
//         bottom: TabBar(
//           labelColor: Colors.white,
//           controller: _tabController,
//           tabs: [
//             Tab(icon: Icon(Icons.send), text: "Kirim"),
//             Tab(icon: Icon(Icons.broadcast_on_home), text: "Broadcast"),
//             Tab(icon: Icon(Icons.history), text: "History"),
//             Tab(icon: Icon(Icons.description), text: "Templates"),
//           ],
//         ),
//       ),
//       body: SafeArea(
//         child: TabBarView(
//           controller: _tabController,
//           children: [
//             _buildSingleMessageTab(),
//             _buildBroadcastTab(),
//             _buildHistoryTab(),
//             _buildTemplatesTab(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSingleMessageTab() {
//     return SingleChildScrollView(
//       padding: EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           Card(
//             color: Colors.green.shade50,
//             child: Padding(
//               padding: EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   Icon(
//                     Icons.phone_android,
//                     size: 48,
//                     color: Colors.green.shade700,
//                   ),
//                   SizedBox(height: 8),
//                   Text(
//                     'Kirim Pesan WhatsApp',
//                     style: TextStyle(
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.green.shade700,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           SizedBox(height: 20),

//           TextField(
//             controller: _phoneController,
//             style: TextStyle(color: Colors.black),
//             decoration: InputDecoration(
//               labelText: 'Nomor WhatsApp',
//               hintText: '08123456789',
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               prefixIcon: Icon(Icons.phone),
//             ),
//             keyboardType: TextInputType.phone,
//           ),

//           SizedBox(height: 16),

//           TextField(
//             controller: _messageController,
//             style: TextStyle(color: Colors.black),
//             decoration: InputDecoration(
//               labelText: 'Pesan',
//               hintText: 'Tulis pesan...',
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               prefixIcon: Icon(Icons.message),
//             ),
//             maxLines: 4,
//           ),

//           SizedBox(height: 16),

//           if (_selectedImage != null)
//             Stack(
//               children: [
//                 Container(
//                   height: 200,
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(12),
//                     image: DecorationImage(
//                       image: FileImage(_selectedImage!),
//                       fit: BoxFit.cover,
//                     ),
//                   ),
//                 ),
//                 Positioned(
//                   top: 8,
//                   right: 8,
//                   child: IconButton(
//                     icon: Icon(Icons.close, color: Colors.white),
//                     onPressed: () {
//                       setState(() {
//                         _selectedImage = null;
//                       });
//                     },
//                     style: IconButton.styleFrom(backgroundColor: Colors.red),
//                   ),
//                 ),
//               ],
//             ),

//           SizedBox(height: 16),

//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton.icon(
//                   onPressed: _pickImage,
//                   icon: Icon(Icons.image),
//                   label: Text('Pilih Gambar'),
//                 ),
//               ),
//             ],
//           ),

//           SizedBox(height: 16),

//           ElevatedButton.icon(
//             onPressed: _isLoading ? null : sendWhatsAppMessage,
//             icon: _isLoading
//                 ? SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       color: Colors.white,
//                     ),
//                   )
//                 : Icon(Icons.send),
//             label: Text(_isLoading ? 'Mengirim...' : 'Kirim WhatsApp'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.green.shade700,
//               foregroundColor: Colors.white,
//               padding: EdgeInsets.all(16),
//             ),
//           ),

//           if (_statusMessage.isNotEmpty)
//             Padding(
//               padding: EdgeInsets.only(top: 16),
//               child: Card(
//                 color: _statusMessage.contains('✅')
//                     ? Colors.green.shade50
//                     : Colors.red.shade50,
//                 child: Padding(
//                   padding: EdgeInsets.all(12),
//                   child: Text(
//                     _statusMessage,
//                     textAlign: TextAlign.center,
//                     style: TextStyle(color: Colors.white),
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildBroadcastTab() {
//     return SingleChildScrollView(
//       padding: EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           Card(
//             color: Colors.blue.shade50,
//             child: Padding(
//               padding: EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   Icon(
//                     Icons.broadcast_on_home,
//                     size: 48,
//                     color: Colors.blue.shade700,
//                   ),
//                   SizedBox(height: 8),
//                   Text(
//                     'Broadcast Pesan',
//                     style: TextStyle(
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.blue.shade700,
//                     ),
//                   ),
//                   Text('Kirim pesan ke banyak nomor sekaligus'),
//                 ],
//               ),
//             ),
//           ),

//           SizedBox(height: 20),

//           Row(
//             children: [
//               Expanded(
//                 child: TextField(
//                   controller: _phoneNumberController,
//                   decoration: InputDecoration(
//                     labelText: 'Nomor WhatsApp',
//                     hintText: '08123456789',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   keyboardType: TextInputType.phone,
//                 ),
//               ),
//               SizedBox(width: 8),
//               IconButton(
//                 icon: Icon(Icons.add_circle, color: Colors.green, size: 32),
//                 onPressed: () {
//                   if (_phoneNumberController.text.isNotEmpty) {
//                     setState(() {
//                       _phoneNumbers.add(_phoneNumberController.text);
//                       _phoneNumberController.clear();
//                     });
//                   }
//                 },
//               ),
//             ],
//           ),

//           SizedBox(height: 16),

//           if (_phoneNumbers.isNotEmpty)
//             Card(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Padding(
//                     padding: EdgeInsets.all(12),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Daftar Nomor (${_phoneNumbers.length})',
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         TextButton.icon(
//                           icon: Icon(Icons.delete, size: 16),
//                           label: Text('Hapus Semua'),
//                           onPressed: () {
//                             setState(() {
//                               _phoneNumbers.clear();
//                             });
//                           },
//                         ),
//                       ],
//                     ),
//                   ),
//                   Divider(height: 1),
//                   ListView.builder(
//                     shrinkWrap: true,
//                     physics: NeverScrollableScrollPhysics(),
//                     itemCount: _phoneNumbers.length,
//                     itemBuilder: (context, index) {
//                       return ListTile(
//                         leading: CircleAvatar(
//                           child: Text('${index + 1}'),
//                           backgroundColor: Colors.green.shade100,
//                         ),
//                         title: Text(_phoneNumbers[index]),
//                         trailing: IconButton(
//                           icon: Icon(Icons.delete, color: Colors.red),
//                           onPressed: () {
//                             setState(() {
//                               _phoneNumbers.removeAt(index);
//                             });
//                           },
//                         ),
//                       );
//                     },
//                   ),
//                 ],
//               ),
//             ),

//           SizedBox(height: 16),

//           TextField(
//             controller: _broadcastMessageController,
//             decoration: InputDecoration(
//               labelText: 'Pesan Broadcast',
//               hintText: 'Tulis pesan yang akan dikirim ke semua nomor...',
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//             maxLines: 5,
//           ),

//           SizedBox(height: 16),

//           ElevatedButton.icon(
//             onPressed: _isLoading || _phoneNumbers.isEmpty
//                 ? null
//                 : sendBroadcastMessages,
//             icon: _isLoading
//                 ? SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       color: Colors.white,
//                     ),
//                   )
//                 : Icon(Icons.send_to_mobile),
//             label: Text(
//               _isLoading
//                   ? 'Mengirim...'
//                   : 'Kirim Broadcast (${_phoneNumbers.length} nomor)',
//             ),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.blue.shade700,
//               foregroundColor: Colors.white,
//               padding: EdgeInsets.all(16),
//             ),
//           ),

//           if (_statusMessage.isNotEmpty)
//             Padding(
//               padding: EdgeInsets.only(top: 16),
//               child: Card(
//                 color: _statusMessage.contains('✅')
//                     ? Colors.green.shade50
//                     : Colors.red.shade50,
//                 child: Padding(
//                   padding: EdgeInsets.all(12),
//                   child: Text(_statusMessage, textAlign: TextAlign.center),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildHistoryTab() {
//     return _messageHistory.isEmpty
//         ? Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.history, size: 64, color: Colors.grey),
//                 SizedBox(height: 16),
//                 Text(
//                   'Belum ada history pesan',
//                   style: TextStyle(color: Colors.grey),
//                 ),
//               ],
//             ),
//           )
//         : ListView.builder(
//             padding: EdgeInsets.all(16),
//             itemCount: _messageHistory.length,
//             itemBuilder: (context, index) {
//               final msg = _messageHistory[index];
//               final date = DateTime.parse(msg['timestamp']);

//               return Card(
//                 margin: EdgeInsets.only(bottom: 12),
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     backgroundColor: msg['status'] == 'sent'
//                         ? Colors.green.shade100
//                         : Colors.red.shade100,
//                     child: Icon(
//                       msg['hasImage'] == true ? Icons.image : Icons.message,
//                       color: msg['status'] == 'sent'
//                           ? Colors.green.shade700
//                           : Colors.red.shade700,
//                     ),
//                   ),
//                   title: Text(msg['phone']),
//                   subtitle: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         msg['message'],
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       SizedBox(height: 4),
//                       Text(
//                         '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}',
//                         style: TextStyle(fontSize: 12, color: Colors.grey),
//                       ),
//                     ],
//                   ),
//                   trailing: msg['type'] == 'broadcast'
//                       ? Chip(
//                           label: Text(
//                             'Broadcast',
//                             style: TextStyle(fontSize: 10),
//                           ),
//                           backgroundColor: Colors.blue.shade100,
//                         )
//                       : null,
//                 ),
//               );
//             },
//           );
//   }

//   Widget _buildTemplatesTab() {
//     if (_templates.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(),
//             SizedBox(height: 16),
//             Text('Memuat templates...'),
//             SizedBox(height: 16),
//             ElevatedButton(onPressed: _loadTemplates, child: Text('Refresh')),
//           ],
//         ),
//       );
//     }

//     return ListView.builder(
//       padding: EdgeInsets.all(16),
//       itemCount: _templates.length,
//       itemBuilder: (context, index) {
//         final template = _templates[index];
//         final status = template['status'] ?? 'UNKNOWN';

//         return Card(
//           margin: EdgeInsets.only(bottom: 12),
//           child: ExpansionTile(
//             leading: CircleAvatar(
//               backgroundColor: status == 'APPROVED'
//                   ? Colors.green.shade100
//                   : Colors.orange.shade100,
//               child: Icon(
//                 status == 'APPROVED' ? Icons.check_circle : Icons.pending,
//                 color: status == 'APPROVED'
//                     ? Colors.green.shade700
//                     : Colors.orange.shade700,
//               ),
//             ),
//             title: Text(template['name'] ?? 'Unnamed'),
//             subtitle: Text('Status: $status'),
//             children: [
//               Padding(
//                 padding: EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     if (template['components'] != null)
//                       ...List.generate(
//                         (template['components'] as List).length,
//                         (i) {
//                           final component = template['components'][i];
//                           if (component['type'] == 'BODY') {
//                             return Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   'Template Body:',
//                                   style: TextStyle(fontWeight: FontWeight.bold),
//                                 ),
//                                 SizedBox(height: 8),
//                                 Container(
//                                   padding: EdgeInsets.all(12),
//                                   decoration: BoxDecoration(
//                                     color: Colors.grey.shade200,
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                   child: Text(component['text'] ?? ''),
//                                 ),
//                               ],
//                             );
//                           }
//                           return SizedBox.shrink();
//                         },
//                       ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     _phoneController.dispose();
//     _messageController.dispose();
//     _broadcastMessageController.dispose();
//     _phoneNumberController.dispose();
//     super.dispose();
//   }
// }
