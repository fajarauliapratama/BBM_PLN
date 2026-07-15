import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart'; // Package Excel
import 'package:path_provider/path_provider.dart'; // Package Path
import 'package:share_plus/share_plus.dart'; // Package Share
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaksi_model.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseService firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Variabel untuk menampilkan loading saat memproses Excel
  bool _isExporting = false; 

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  // --- FUNGSI EXPORT KE EXCEL ---
  Future<void> _exportToExcel(List<TransaksiModel> data) async {
    setState(() {
      _isExporting = true;
    });

    try {
      // 1. Membuat Dokumen Excel Baru
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Rekap_BBM'];
      excel.setDefaultSheet('Rekap_BBM');

      // Hapus sheet bawaan agar rapi
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // 2. Mendesain Baris Judul (Header)
      List<String> headers = ['No', 'Tanggal', 'Plat Nomor', 'Jenis BBM', 'Volume (Liter)', 'Total Biaya (Rp)', 'Petugas'];
      for (int i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        // Membuat teks judul menjadi tebal dan ke tengah
        cell.cellStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Center);
      }

      // 3. Mengisi Data dari Firebase ke dalam Tabel Excel
      final DateFormat dateFormat = DateFormat('dd/MM/yyyy HH:mm');
      for (int i = 0; i < data.length; i++) {
        var item = data[i];
        int rowIndex = i + 1; // Baris 0 dipakai header, data mulai di baris 1

        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = IntCellValue(i + 1);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(dateFormat.format(item.tanggal));
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(item.platNomor);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = TextCellValue(item.jenisBbm);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = DoubleCellValue(item.jumlahLiter);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = DoubleCellValue(item.totalBiaya);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = TextCellValue(item.petugas);
      }

      // 4. Merapikan Lebar Kolom Agar Tidak Berantakan / Terpotong
      sheetObject.setColumnWidth(0, 5);  // Kolom No
      sheetObject.setColumnWidth(1, 20); // Kolom Tanggal
      sheetObject.setColumnWidth(2, 15); // Kolom Plat Nomor
      sheetObject.setColumnWidth(3, 15); // Kolom Jenis BBM
      sheetObject.setColumnWidth(4, 15); // Kolom Liter
      sheetObject.setColumnWidth(5, 20); // Kolom Biaya
      sheetObject.setColumnWidth(6, 25); // Kolom Petugas

      // 5. Menyimpan File ke Memori Sementara HP
      var fileBytes = excel.save();
      if (fileBytes == null) throw Exception("Gagal memproses file Excel");

      final directory = await getTemporaryDirectory();
      // Nama file saat diunduh
      final String filePath = '${directory.path}/Rekap_BBM_PLN.xlsx'; 
      
      File file = File(filePath);
      await file.writeAsBytes(fileBytes);

      // 6. Memunculkan Pop-Up Share/Unduh
      if (!mounted) return;
      await Share.shareXFiles( 
        [XFile(filePath)], 
        text: 'Lampiran Dokumen Laporan Rekapitulasi BBM PLN.'
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan saat mengekspor: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
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
            tooltip: 'Keluar',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
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
      body: Column(
        children: [
          // KOTAK PENCARIAN
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
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

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

                final semuaData = snapshot.data!;
                final dataTersaring = semuaData.where((transaksi) {
                  return transaksi.platNomor
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                }).toList();

                return Column(
                  children: [
                    // --- BARIS TOMBOL EXPORT ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Data: ${dataTersaring.length}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600], // Hijau khas Excel
                              foregroundColor: Colors.white,
                            ),
                            // Jika tombol ditekan, jalankan fungsi pembuat Excel
                            onPressed: _isExporting ? null : () => _exportToExcel(dataTersaring),
                            icon: _isExporting 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.table_view),
                            label: const Text('Unduh Excel'),
                          ),
                        ],
                      ),
                    ),

                    // TAMPILAN LIST DATA
                    if (dataTersaring.isEmpty)
                      const Expanded(child: Center(child: Text('Plat nomor tidak ditemukan.')))
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: dataTersaring.length,
                          itemBuilder: (context, index) {
                            final transaksi = dataTersaring[index];
                            final formatRupiah = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
                            final formatTanggal = DateFormat('dd MMM yyyy, HH:mm').format(transaksi.tanggal);

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
                                      Text('BBM: ${transaksi.jenisBbm}'),
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
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}