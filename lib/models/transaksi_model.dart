import 'package:cloud_firestore/cloud_firestore.dart';

class TransaksiModel {
  final String id;
  final String platNomor;
  final String petugas;
  final int kilometer;
  final double jumlahLiter;
  final double totalBiaya;
  final String imageUrl;
  final DateTime tanggal;

  // Constructor
  TransaksiModel({
    required this.id,
    required this.platNomor,
    required this.petugas,
    required this.kilometer,
    required this.jumlahLiter,
    required this.totalBiaya,
    required this.imageUrl,
    required this.tanggal,
  });

  // Fungsi untuk membaca data mentah dari Firebase menjadi Objek Dart
  factory TransaksiModel.fromMap(Map<String, dynamic> data, String documentId) {
    return TransaksiModel(
      id: documentId,
      platNomor: data['platNomor'] ?? '',
      petugas: data['petugas'] ?? '',
      kilometer: data['kilometer']?.toInt() ?? 0,
      jumlahLiter: data['jumlahLiter']?.toDouble() ?? 0.0,
      totalBiaya: data['totalBiaya']?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'] ?? '',
      // Firebase menyimpan waktu dalam bentuk Timestamp, harus diubah ke DateTime Dart
      tanggal: (data['tanggal'] as Timestamp).toDate(), 
    );
  }

  // Fungsi untuk membungkus Objek Dart menjadi data mentah sebelum dikirim ke Firebase
  Map<String, dynamic> toMap() {
    return {
      'platNomor': platNomor,
      'petugas': petugas,
      'kilometer': kilometer,
      'jumlahLiter': jumlahLiter,
      'totalBiaya': totalBiaya,
      'imageUrl': imageUrl,
      'tanggal': Timestamp.fromDate(tanggal),
    };
  }
}