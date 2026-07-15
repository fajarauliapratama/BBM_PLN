class TransaksiModel {
  final String id;
  final String platNomor;
  final String jenisBbm; // Dulu kilometer
  final double jumlahLiter;
  final double totalBiaya;
  final String imageUrl;
  final DateTime tanggal;
  final String petugas;

  TransaksiModel({
    required this.id,
    required this.platNomor,
    required this.jenisBbm,
    required this.jumlahLiter,
    required this.totalBiaya,
    required this.imageUrl,
    required this.tanggal,
    required this.petugas,
  });

  factory TransaksiModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TransaksiModel(
      id: documentId,
      platNomor: map['plat_nomor'] ?? '',
      jenisBbm: map['jenis_bbm'] ?? '-', // Mengambil data jenis BBM
      jumlahLiter: (map['jumlah_liter'] ?? 0).toDouble(),
      totalBiaya: (map['total_biaya'] ?? 0).toDouble(),
      imageUrl: map['image_url'] ?? '',
      tanggal: map['tanggal']?.toDate() ?? DateTime.now(),
      petugas: map['petugas'] ?? 'Unknown',
    );
  }
}