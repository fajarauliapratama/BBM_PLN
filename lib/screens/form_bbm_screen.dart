import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart'; 
import '../providers/bbm_provider.dart';
import 'login_screen.dart';

class FormBbmScreen extends StatefulWidget {
  const FormBbmScreen({super.key});

  @override
  State<FormBbmScreen> createState() => _FormBbmScreenState();
}

class _FormBbmScreenState extends State<FormBbmScreen> {
  // Controller untuk input form
  final _platNomorController = TextEditingController();
  final _tanggalController = TextEditingController();
  DateTime _selectedTanggal = DateTime.now(); // Tanggal default hari ini

  String? _selectedJenisBbm;
  final List<String> _daftarBbm = [
    'Pertamax',
    'Dexlite',
    'Pertamina Dex',
    'Biosolar',
    'Pertalite'
  ];

  final _literController = TextEditingController();
  final _biayaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isScanning = false; // Indikator loading saat AI membaca gambar

  @override
  void initState() {
    super.initState();
    // Mengisi form tanggal secara otomatis saat halaman dibuka
    _tanggalController.text = DateFormat('dd/MM/yyyy').format(_selectedTanggal);
  }

  @override
  void dispose() {
    _platNomorController.dispose();
    _tanggalController.dispose();
    _literController.dispose();
    _biayaController.dispose();
    super.dispose();
  }

  // --- FUNGSI LOGOUT ---
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  // --- FUNGSI MENGUBAH TANGGAL MANUAL ---
  Future<void> _pilihTanggal(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedTanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // Membatasi agar tidak bisa pilih tanggal di masa depan
    );
    if (picked != null && picked != _selectedTanggal) {
      setState(() {
        _selectedTanggal = picked;
        _tanggalController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // --- FUNGSI AI UNTUK MEMBACA STRUK ---
  Future<void> _scanStrukOtomatis(String imagePath) async {
    setState(() {
      _isScanning = true;
    });

    // Kosongkan form sebelum dipindai agar data lama/sebelumnya tidak nyangkut
    _platNomorController.clear();
    _literController.clear();
    _biayaController.clear();
    setState(() {
      _selectedJenisBbm = null;
    });

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      String fullText = recognizedText.text.toUpperCase();

      // 1. MENDETEKSI TANGGAL STRUK (Pintar: bisa baca pakai / atau - atau . dan tahun 2/4 digit)
      RegExp dateRegExp = RegExp(r'([0-3]?[0-9])[\/\-\.]([0-1]?[0-9])[\/\-\.](20[0-9]{2}|[0-9]{2})\b');
      var dateMatch = dateRegExp.firstMatch(fullText);
      if (dateMatch != null) {
        int d = int.parse(dateMatch.group(1)!);
        int m = int.parse(dateMatch.group(2)!);
        String yearStr = dateMatch.group(3)!;
        // Jika tahun terbaca 2 digit (misal 24), jadikan 2024
        int y = yearStr.length == 2 ? 2000 + int.parse(yearStr) : int.parse(yearStr);
        
        setState(() {
          _selectedTanggal = DateTime(y, m, d);
          _tanggalController.text = DateFormat('dd/MM/yyyy').format(_selectedTanggal);
        });
      }
      
      // 2. MENDETEKSI PLAT NOMOR (Mencari teks NOPOL / POLISI / PLAT)
      RegExp nopolRegExp = RegExp(r'(?:NOPOL|POLISI|POL|PLAT)\s*[:\s]*([A-Z]{1,2}\s*\d{1,4}\s*[A-Z]{0,3})');
      var nopolMatch = nopolRegExp.firstMatch(fullText);
      if (nopolMatch != null) {
        _platNomorController.text = nopolMatch.group(1)!.trim();
      }

      // 3. MENDETEKSI JENIS BBM
      if (fullText.contains('PERTALITE')) {
        _selectedJenisBbm = 'Pertalite';
      } else if (fullText.contains('PERTAMAX')) {
        _selectedJenisBbm = 'Pertamax';
      } else if (fullText.contains('DEXLITE')) {
        _selectedJenisBbm = 'Dexlite';
      } else if (fullText.contains('BIOSOLAR') || fullText.contains('BIO SOLAR')) {
        _selectedJenisBbm = 'Biosolar';
      } else if (fullText.contains('PERTAMINA DEX')) {
        _selectedJenisBbm = 'Pertamina Dex';
      }

      // 4. MENDETEKSI VOLUME (LITER)
      String? rawVol;
      RegExp volRegExp1 = RegExp(r'VOLUME\s*[:\s]*([0-9\,\.]+)');
      RegExp volRegExp2 = RegExp(r'([0-9\,\.]+)\s*LITER');

      if (volRegExp1.hasMatch(fullText)) {
        rawVol = volRegExp1.firstMatch(fullText)?.group(1);
      } else if (volRegExp2.hasMatch(fullText)) {
        rawVol = volRegExp2.firstMatch(fullText)?.group(1);
      }

      if (rawVol != null) {
        rawVol = rawVol.replaceAll(',', '.'); // Ubah koma jadi titik untuk desimal
        if (rawVol.length <= 6) { // Cegah AI menangkap nomor seri mesin panjang
          _literController.text = rawVol;
        }
      }

      // 5. MENDETEKSI TOTAL BIAYA (DIBAYAR KONSUMEN)
      RegExp hargaRegExp = RegExp(r'KONSUMEN\s*[:\s]*([0-9\,\.]+)');
      var hargaMatch = hargaRegExp.firstMatch(fullText);
      if (hargaMatch != null) {
        String rawHarga = hargaMatch.group(1) ?? '';
        rawHarga = rawHarga.replaceAll(RegExp(r'[^0-9]'), ''); // Hapus semua pemisah ribuan
        _biayaController.text = rawHarga;
      }

      textRecognizer.close();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pemindaian selesai! Jika ada kolom kosong, silakan lengkapi manual.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memindai struk. Silakan isi manual.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bbmProvider = Provider.of<BbmProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Input BBM'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('1. Foto Struk Pembayaran (Otomatis Isi Form):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              // AREA KAMERA & FOTO
              InkWell(
                onTap: () async {
                  await bbmProvider.pickImage();
                  if (bbmProvider.imageFile != null) {
                    _scanStrukOtomatis(bbmProvider.imageFile!.path);
                  }
                }, 
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: bbmProvider.imageFile != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(bbmProvider.imageFile!.path),
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (_isScanning)
                              Container(
                                color: Colors.black.withValues(alpha: 0.5),
                                child: const Center(
                                  child: CircularProgressIndicator(color: Colors.white),
                                ),
                              ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                            Text('Ketuk untuk memindai struk BBM'),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              const Text('2. Koreksi Data Transaksi:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // FORM TANGGAL TRANSAKSI
              TextFormField(
                controller: _tanggalController,
                readOnly: true, // Tidak bisa diketik manual
                onTap: () => _pilihTanggal(context), // Membuka kalender
                decoration: const InputDecoration(
                  labelText: 'Tanggal Pengisian',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              // FORM PLAT NOMOR MANUAL
              TextFormField(
                controller: _platNomorController,
                textCapitalization: TextCapitalization.characters, // Otomatis Huruf Kapital
                decoration: const InputDecoration(
                  labelText: 'Plat Nomor',
                  hintText: 'Misal: BA 1234 PLN',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_car),
                ),
                validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              
              // DROPDOWN JENIS BBM
              DropdownButtonFormField<String>(
                value: _selectedJenisBbm, 
                decoration: const InputDecoration(
                  labelText: 'Jenis BBM',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_gas_station),
                ),
                items: _daftarBbm.map((String bbm) {
                  return DropdownMenuItem<String>(
                    value: bbm,
                    child: Text(bbm),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedJenisBbm = newValue;
                  });
                },
                validator: (value) => value == null ? 'Silakan pilih jenis BBM' : null,
              ),
              const SizedBox(height: 16),

              // BARIS LITER & BIAYA
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _literController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Volume (Liter)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value!.isEmpty ? 'Kosong' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _biayaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total (Rp)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value!.isEmpty ? 'Kosong' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // TOMBOL SIMPAN
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: (bbmProvider.isLoading || _isScanning)
                    ? null 
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          if (bbmProvider.imageFile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Harap foto struk terlebih dahulu!')),
                            );
                            return;
                          }

                          // Meneruskan data ke Provider dan Database
                          bool sukses = await bbmProvider.simpanData(
                            platNomor: _platNomorController.text,
                            jenisBbm: _selectedJenisBbm!, 
                            liter: double.parse(_literController.text),
                            biaya: double.parse(_biayaController.text),
                            tanggal: _selectedTanggal,
                          );

                          if (!mounted) return;

                          if (sukses) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Data berhasil disimpan!')),
                            );
                            
                            // Reset state setelah berhasil
                            setState(() {
                              _selectedJenisBbm = null;
                            });
                            _platNomorController.clear();
                            _literController.clear();
                            _biayaController.clear();
                            _tanggalController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gagal menyimpan data.')),
                            );
                          }
                        }
                      },
                child: bbmProvider.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Simpan Data', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}