import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Package baru
import '../providers/bbm_provider.dart';
import 'login_screen.dart';

class FormBbmScreen extends StatefulWidget {
  const FormBbmScreen({super.key});

  @override
  State<FormBbmScreen> createState() => _FormBbmScreenState();
}

class _FormBbmScreenState extends State<FormBbmScreen> {
  String? _selectedPlatNomor;
  final List<String> _daftarMobil = [
    'BA 1234 PLN (Hilux)',
    'BA 5678 PLN (Avanza)',
    'BA 9101 PLN (Innova)',
    'B 9999 UPT (Triton)'
  ];

  String? _selectedJenisBbm;
  final List<String> _daftarBbm = [
    'Dexlite',
    'Pertamina Dex',
    'Biosolar',
    'Pertamax',
    'Pertalite'
  ];

  final _literController = TextEditingController();
  final _biayaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isScanning = false; // Indikator saat AI sedang membaca struk

  @override
  void dispose() {
    _literController.dispose();
    _biayaController.dispose();
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

  // --- FUNGSI AI UNTUK MEMBACA STRUK ---
  Future<void> _scanStrukOtomatis(String imagePath) async {
    setState(() {
      _isScanning = true;
    });

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      // Ubah semua teks menjadi huruf besar agar mudah dicari
      String fullText = recognizedText.text.toUpperCase();
      
      // 1. MENDETEKSI JENIS BBM
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

      // 2. MENDETEKSI VOLUME (LITER)
      // Mencari kata "VOLUME" lalu mengambil angka di sebelahnya
      RegExp volRegExp = RegExp(r'VOLUME\s*[:\s]*([0-9\,\.]+)');
      var volMatch = volRegExp.firstMatch(fullText);
      if (volMatch != null) {
        String rawVol = volMatch.group(1) ?? '';
        rawVol = rawVol.replaceAll(',', '.'); // Pastikan format desimal menggunakan titik
        _literController.text = rawVol;
      }

      // 3. MENDETEKSI TOTAL BIAYA
      // Pada struk Pertamina, biasanya menggunakan kata "DIBAYAR KONSUMEN"
      RegExp hargaRegExp = RegExp(r'KONSUMEN\s*[:\s]*([0-9\,\.]+)');
      var hargaMatch = hargaRegExp.firstMatch(fullText);
      if (hargaMatch != null) {
        String rawHarga = hargaMatch.group(1) ?? '';
        rawHarga = rawHarga.replaceAll(RegExp(r'[^0-9]'), ''); // Hapus semua titik/koma
        _biayaController.text = rawHarga;
      }

      textRecognizer.close();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pemindaian berhasil! Periksa kembali data yang terisi.'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedPlatNomor,
                decoration: const InputDecoration(
                  labelText: 'Pilih Kendaraan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_car),
                ),
                items: _daftarMobil.map((String plat) {
                  return DropdownMenuItem<String>(
                    value: plat,
                    child: Text(plat),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedPlatNomor = newValue;
                  });
                },
                validator: (value) => value == null ? 'Silakan pilih kendaraan' : null,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedJenisBbm, // Gunakan value agar bisa diubah paksa oleh AI
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
              const SizedBox(height: 24),

              const Text('Bukti Struk Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              // AREA FOTO STRUK
              InkWell(
                // PERUBAHAN: Setelah ambil foto, langsung jalankan fungsi pemindai AI
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
                            // Menampilkan loading saat AI sedang membaca gambar
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
                            Text('Ketuk untuk foto struk BBM'),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),

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

                          bool sukses = await bbmProvider.simpanData(
                            platNomor: _selectedPlatNomor!,
                            jenisBbm: _selectedJenisBbm!, 
                            liter: double.parse(_literController.text),
                            biaya: double.parse(_biayaController.text),
                          );

                          if (!mounted) return;

                          if (sukses) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Data berhasil disimpan!')),
                            );
                            
                            setState(() {
                              _selectedPlatNomor = null;
                              _selectedJenisBbm = null;
                            });
                            _literController.clear();
                            _biayaController.clear();
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