// import 'package:flutter/material.dart';
// import 'package:chatwoot_flutter_sdk/chatwoot_sdk.dart';

// class HalamanChat extends StatefulWidget {
//   @override
//   _HalamanChatState createState() => _HalamanChatState();
// }

// class _HalamanChatState extends State<HalamanChat> {
//   @override
//   void initState() {
//     super.initState();
    
//     // Inisialisasi Chatwoot saat halaman dimuat
//     // Ganti nilai-nilai di bawah ini dengan kredensial Anda
//     Chatwoot.initialize(
//       baseUrl: "https://app.chatwoot.com", // Ganti dengan Base URL Anda
//       inboxIdentifier: "YOUR_INBOX_IDENTIFIER", // Ganti dengan ID Inbox Anda
//       enablePersistence: true, // Opsional: untuk menyimpan riwayat chat di perangkat
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Data pelanggan (Sangat penting!)
//     // Ini mengidentifikasi pengguna di Chatwoot
//     final chatwootUser = ChatwootUser(
//       // ID unik untuk pelanggan di sistem Anda (misal, user ID dari database)
//       identifier: "pelanggan_12345", 
//       name: "Budi Setiawan", // Nama pelanggan
//       email: "budi.setiawan@email.com", // Email pelanggan
//       // Anda juga bisa menambahkan avatar_url, phone_number, dll.
//     );

//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Dukungan Pelanggan"),
//       ),
//       body: ChatwootWidget(
//         user: chatwootUser,
//         // Widget yang tampil selagi chat dimuat
//         placeholder: Center(
//           child: CircularProgressIndicator(
//             color: Colors.blue, // Sesuaikan warnanya
//           ),
//         ),
//         // Opsi untuk kustomisasi tampilan (opsional)
//         // baseUrl: "https..." (Anda bisa set di sini ATAU di initialize)
//         // inboxIdentifier: "..." (Anda bisa set di sini ATAU di initialize)
//       ),
//     );
//   }
// }