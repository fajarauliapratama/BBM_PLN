import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaksi_model.dart';

class FirebaseService {
  // Merujuk ke tabel/koleksi 'riwayat_bbm' di Firestore
  final CollectionReference _transaksiCollection =
      FirebaseFirestore.instance.collection('riwayat_bbm');

  // Fungsi untuk menyimpan data transaksi baru
  Future<void> simpanDataBBM(TransaksiModel transaksi) async {
    try {
      // Mengubah objek Dart menjadi Map lalu mengirimnya ke Firebase
      await _transaksiCollection.add(transaksi.toMap());
    } catch (e) {
      // Menangkap error jika gagal (misal: koneksi terputus)
      throw Exception('Gagal menyimpan data ke database: $e');
    }
  }

  // Fungsi untuk mengambil seluruh data (Untuk Halaman History Admin)
  Stream<List<TransaksiModel>> getRiwayatBBM() {
    return _transaksiCollection
        .orderBy('tanggal', descending: true) // Urutkan dari yang terbaru
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TransaksiModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }
}