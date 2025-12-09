// =========================================================================
// WIDGET BANTUAN (Letakkan di luar fungsi build/ListView.builder Anda)
// =========================================================================

import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart'; // UNCOMMENT IN REAL PROJECT

/// Widget sederhana untuk menampilkan gambar pratinjau layar penuh.
class ImagePreviewPage extends StatelessWidget {
  final String imageUrl;

  // const ImagePreviewPage({Key? key, required this.imageUrl})
  //     : super(key: key);
  const ImagePreviewPage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Image Preview'),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: Center(
        child: InteractiveViewer(
          // Memungkinkan zoom dan pan pada gambar
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.error, color: Colors.red, size: 50),
            ),
          ),
        ),
      ),
    );
  }
}
