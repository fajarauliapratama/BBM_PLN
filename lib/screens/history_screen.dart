import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:share_plus/share_plus.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaksi_model.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';
import 'dart:convert';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseService firebaseService = FirebaseService();
  
  // Variabel untuk menyimpan Plat yang dipilih dari Dropdown (Default: Semua Data)
  String _selectedFilterPlat = 'Semua Kendaraan';
  
  bool _isExporting = false; 

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _exportToExcel(List<TransaksiModel> data) async {
    setState(() {
      _isExporting = true;
    });

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Rekap_BBM'];
      excel.setDefaultSheet('Rekap_BBM');

      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      List<String> headers = ['No', 'Tanggal', 'Plat Nomor', 'Jenis BBM', 'Volume (Liter)', 'Total Biaya (Rp)', 'Petugas'];
      for (int i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Center);
      }

      final DateFormat dateFormat = DateFormat('dd/MM/yyyy');
      for (int i = 0; i < data.length; i++) {
        var item = data[i];
        int rowIndex = i + 1; 

        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = IntCellValue(i + 1);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(dateFormat.format(item.tanggal));
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(item.platNomor);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(item.jenisBbm);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = DoubleCellValue(item.jumlahLiter);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = DoubleCellValue(item.totalBiaya);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = TextCellValue(item.petugas);
      }

      sheetObject.setColumnWidth(0, 5);  
      sheetObject.setColumnWidth(1, 15); 
      sheetObject.setColumnWidth(2, 15); 
      sheetObject.setColumnWidth(3, 15); 
      sheetObject.setColumnWidth(4, 15); 
      sheetObject.setColumnWidth(5, 20); 
      sheetObject.setColumnWidth(6, 25); 

      var fileBytes = excel.save();
      if (fileBytes == null) throw Exception("Gagal memproses file");

      final directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/Rekap_BBM_PLN.xlsx'; 
      
      File file = File(filePath);
      await file.writeAsBytes(fileBytes);

      if (!mounted) return;
      await Share.shareXFiles([XFile(filePath)], text: 'Lampiran Dokumen Laporan BBM PLN.');

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap Riwayat BBM'),
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _logout();
                      },
                      child: const Text('Keluar', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<TransaksiModel>>(
        stream: firebaseService.getRiwayatBBM(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Belum ada riwayat pengisian BBM.'));
          }

          final semuaData = snapshot.data!;
          
          // 1. MENGAMBIL DAFTAR PLAT UNIK DARI DATABASE UNTUK DROPDOWN
          List<String> daftarPlatUnik = ['Semua Kendaraan'];
          // Gunakan Set agar tidak ada plat yang duplikat
          Set<String> platDariDatabase = semuaData.map((e) => e.platNomor).toSet();
          daftarPlatUnik.addAll(platDariDatabase.toList()..sort()); // Diurutkan sesuai abjad

          // 2. MENYARING DATA BERDASARKAN DROPDOWN
          final dataTersaring = semuaData.where((transaksi) {
            if (_selectedFilterPlat == 'Semua Kendaraan') return true;
            return transaksi.platNomor == _selectedFilterPlat;
          }).toList();

          return Column(
            children: [
              // --- KOTAK DROPDOWN FILTER ADMIN ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedFilterPlat,
                  decoration: const InputDecoration(
                    labelText: 'Filter Berdasarkan Kendaraan',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.filter_alt),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  // Buat menu dropdown dinamis
                  items: daftarPlatUnik.map((String plat) {
                    return DropdownMenuItem<String>(
                      value: plat,
                      child: Text(plat, style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      // Cek validasi untuk mencegah error saat data dihapus
                      _selectedFilterPlat = newValue ?? 'Semua Kendaraan';
                    });
                  },
                ),
              ),

              // --- BARIS TOMBOL EXPORT ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Data: ${dataTersaring.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600], 
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isExporting ? null : () => _exportToExcel(dataTersaring),
                      icon: _isExporting 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.table_view),
                      label: const Text('Unduh Excel'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // --- TAMPILAN LIST DATA ---
              if (dataTersaring.isEmpty)
                const Expanded(child: Center(child: Text('Data tidak ditemukan.')))
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: dataTersaring.length,
                    itemBuilder: (context, index) {
                      final transaksi = dataTersaring[index];
                      final formatRupiah = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
                      final formatTanggal = DateFormat('dd MMM yyyy').format(transaksi.tanggal); // Hanya menampilkan tanggal

                      return Card(
                        elevation: 3,
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
                                        // Mengubah teks Base64 kembali menjadi gambar di Pop-up
                                        child: Image.memory(base64Decode(transaksi.imageUrl)),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    // Mengubah teks Base64 kembali menjadi gambar di daftar (List)
                                    child: Image.memory(
                                      base64Decode(transaksi.imageUrl),
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.image_not_supported, size: 50),
                          title: Text(
                            transaksi.platNomor,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pengisi: ${transaksi.petugas}'),
                                Text('BBM: ${transaksi.jenisBbm}'),
                                Text('Volume: ${transaksi.jumlahLiter} Liter'),
                                const SizedBox(height: 4),
                                Text(
                                  formatTanggal,
                                  style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold),
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
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}