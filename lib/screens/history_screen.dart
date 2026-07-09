import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import '../models/transaksi_model.dart';
import '../services/firebase_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseService firebaseService = FirebaseService();
  
  // Controller untuk menangkap teks yang diketik di kolom pencarian
  final TextEditingController _searchController = TextEditingController();
  
  // Variabel untuk menyimpan kata kunci pencarian saat ini
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap Riwayat BBM'),
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // KOTAK PENCARIAN (SEARCH BAR)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cari Plat Nomor',
                hintText: 'Misal: B 1234 PLN',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          // Tombol "X" untuk menghapus pencarian
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                // Memperbarui tampilan setiap kali admin mengetik
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // LIST DATA RIWAYAT
          Expanded(
            child: StreamBuilder<List<TransaksiModel>>(
              stream: firebaseService.getRiwayatBBM(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Belum ada riwayat pengisian BBM.'),
                  );
                }

                // Mengambil semua data dari Firebase
                final semuaData = snapshot.data!;

                // PROSES FILTERING (PENYARINGAN DATA)
                // Hanya mengambil data yang plat nomornya mengandung teks pencarian
                final dataTersaring = semuaData.where((transaksi) {
                  return transaksi.platNomor
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                }).toList();

                // Tampilan jika data yang dicari tidak ditemukan
                if (dataTersaring.isEmpty) {
                  return const Center(
                    child: Text('Plat nomor tidak ditemukan.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: dataTersaring.length,
                  itemBuilder: (context, index) {
                    final transaksi = dataTersaring[index];

                    final formatRupiah = NumberFormat.currency(
                      locale: 'id',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    );

                    final formatTanggal = DateFormat('dd MMM yyyy, HH:mm').format(transaksi.tanggal);

                    return Card(
                      elevation: 3,
                      // Jarak bawah sudah menggunakan EdgeInsets.only(bottom: 12)
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: transaksi.imageUrl.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      child: Image.network(transaksi.imageUrl),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    transaksi.imageUrl,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            : const Icon(Icons.image_not_supported, size: 50),
                        title: Text(
                          transaksi.platNomor.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pengisi: ${transaksi.petugas}'),
                              Text('Odometer: ${transaksi.kilometer} KM'),
                              Text('Volume: ${transaksi.jumlahLiter} Liter'),
                              const SizedBox(height: 4),
                              Text(
                                formatTanggal,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        trailing: Text(
                          formatRupiah.format(transaksi.totalBiaya),
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}