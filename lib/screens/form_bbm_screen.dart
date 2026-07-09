import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Untuk fitur Logout
import '../providers/bbm_provider.dart';
import 'login_screen.dart'; // Import halaman login untuk arah kembali

class FormBbmScreen extends StatefulWidget {
  const FormBbmScreen({super.key});

  @override
  State<FormBbmScreen> createState() => _FormBbmScreenState();
}

class _FormBbmScreenState extends State<FormBbmScreen> {
  // Variabel untuk Dropdown Plat Nomor
  String? _selectedPlatNomor;
  // Daftar kendaraan operasional PLN (bisa disesuaikan atau diambil dari Firebase nantinya)
  final List<String> _daftarMobil = [
    'BA 1234 PLN (Hilux)',
    'BA 5678 PLN (Avanza)',
    'BA 9101 PLN (Innova)',
    'B 9999 UPT (Triton)'
  ];

  final _kilometerController = TextEditingController();
  final _literController = TextEditingController();
  final _biayaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _kilometerController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final bbmProvider = Provider.of<BbmProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Input BBM'),
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        actions: [
          // Tombol Logout
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () {
              // Dialog konfirmasi sebelum logout
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
                        Navigator.pop(context); // Tutup dialog
                        _logout(); // Eksekusi fungsi logout
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
              // --- DROPDOWN PLAT NOMOR ---
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
              
              TextFormField(
                controller: _kilometerController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Odometer saat ini (KM)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.speed),
                ),
                validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
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

              // AREA FOTO STRUK
              const Text('Bukti Struk Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => bbmProvider.pickImage(), 
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: bbmProvider.imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(bbmProvider.imageFile!.path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
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

              // TOMBOL SIMPAN
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: bbmProvider.isLoading
                    ? null 
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          if (bbmProvider.imageFile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Harap foto struk terlebih dahulu!')),
                            );
                            return;
                          }

                          // Jalankan proses simpan dengan nilai Dropdown
                          bool sukses = await bbmProvider.simpanData(
                            platNomor: _selectedPlatNomor!, // Ambil dari dropdown
                            kilometer: int.parse(_kilometerController.text),
                            liter: double.parse(_literController.text),
                            biaya: double.parse(_biayaController.text),
                          );

                          if (!mounted) return;

                          if (sukses) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Data berhasil disimpan!')),
                            );
                            
                            // Reset form (termasuk dropdown)
                            setState(() {
                              _selectedPlatNomor = null;
                            });
                            _kilometerController.clear();
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