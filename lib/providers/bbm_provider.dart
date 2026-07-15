import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:convert'; // Tambahan wajib untuk Base64 Encoding

class BbmProvider with ChangeNotifier {
  XFile? _imageFile;
  bool _isLoading = false;

  XFile? get imageFile => _imageFile;
  bool get isLoading => _isLoading;

  final ImagePicker _picker = ImagePicker();

  Future<void> pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      // KUALITAS DITURUNKAN: Agar teks Base64 tidak terlalu raksasa ukurannya
      imageQuality: 30, 
    );
    if (pickedFile != null) {
      _imageFile = pickedFile;
      notifyListeners();
    }
  }

  Future<bool> simpanData({
    required String platNomor,
    required String jenisBbm,
    required double liter,
    required double biaya,
    required DateTime tanggal,
  }) async {
    if (_imageFile == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email ?? 'supir_anonim';

      // --- PROSES BASE64 ENCODING (MENGGANTIKAN FIREBASE STORAGE) ---
      final bytes = await File(_imageFile!.path).readAsBytes();
      final String base64Image = base64Encode(bytes);
      // -------------------------------------------------------------

      DocumentReference docBbm = FirebaseFirestore.instance.collection('riwayat_bbm').doc();
      
      await docBbm.set({
        'plat_nomor': platNomor.toUpperCase(),
        'jenis_bbm': jenisBbm,
        'jumlah_liter': liter,
        'total_biaya': biaya,
        // Menyimpan String Base64 langsung ke Firestore, bukan URL
        'image_url': base64Image, 
        'tanggal': Timestamp.fromDate(tanggal),
        'petugas': userEmail, 
      });

      _imageFile = null;
      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}