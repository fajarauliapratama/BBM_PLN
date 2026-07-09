import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/transaksi_model.dart';
import '../services/firebase_service.dart';

class BbmProvider with ChangeNotifier {
  File? imageFile;
  bool isLoading = false;
  final FirebaseService _firebaseService = FirebaseService();

  // 1. Fungsi untuk membuka kamera HP
  Future<void> pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera, 
      imageQuality: 70, // Kompres ukuran foto agar kuota/storage hemat
    );
    
    if (pickedFile != null) {
      imageFile = File(pickedFile.path);
      notifyListeners(); // Memperbarui tampilan layar (munculkan foto)
    }
  }

  // 2. Fungsi utama untuk menyimpan semua data ke Firebase
  Future<bool> simpanData({
    required String platNomor,
    required int kilometer,
    required double liter,
    required double biaya,
  }) async {
    if (imageFile == null) return false; // Tolak jika tidak ada foto struk

    try {
      isLoading = true;
      notifyListeners(); // Ubah tombol simpan menjadi animasi loading

      // A. Upload Foto ke Firebase Storage terlebih dahulu
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance.ref().child('struk_bbm/$fileName.jpg');
      await ref.putFile(imageFile!);
      String imageUrl = await ref.getDownloadURL(); // Dapatkan link foto

      // B. Bungkus data ke dalam Objek Model
      TransaksiModel transaksi = TransaksiModel(
        id: '', // Firebase akan membuatkan ID acak secara otomatis
        platNomor: platNomor,
        petugas: 'Supir Default', // Sementara kita hardcode sebelum ada fitur Login
        kilometer: kilometer,
        jumlahLiter: liter,
        totalBiaya: biaya,
        imageUrl: imageUrl,
        tanggal: DateTime.now(),
      );

      // C. Simpan teks dan link foto ke Firestore
      await _firebaseService.simpanDataBBM(transaksi);

      // D. Bersihkan form setelah berhasil
      imageFile = null;
      isLoading = false;
      notifyListeners();
      
      return true; // Berhasil
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return false; // Gagal
    }
  }
}