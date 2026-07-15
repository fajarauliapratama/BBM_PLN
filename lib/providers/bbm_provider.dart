import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class BbmProvider with ChangeNotifier {
  XFile? _imageFile;
  bool _isLoading = false;

  XFile? get imageFile => _imageFile;
  bool get isLoading => _isLoading;

  final ImagePicker _picker = ImagePicker();

  Future<void> pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70, 
    );
    if (pickedFile != null) {
      _imageFile = pickedFile;
      notifyListeners();
    }
  }

  Future<bool> simpanData({
    required String platNomor,
    required String jenisBbm, // Dulu kilometer
    required double liter,
    required double biaya,
  }) async {
    if (_imageFile == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email ?? 'supir_anonim';

      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance.ref().child('struk_bbm/$fileName.jpg');
      await ref.putFile(File(_imageFile!.path));
      String imageUrl = await ref.getDownloadURL();

      DocumentReference docBbm = FirebaseFirestore.instance.collection('riwayat_bbm').doc();
      
      await docBbm.set({
        'plat_nomor': platNomor,
        'jenis_bbm': jenisBbm, 
        'jumlah_liter': liter,
        'total_biaya': biaya,
        'image_url': imageUrl,
        'tanggal': FieldValue.serverTimestamp(),
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