import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:cached_network_image/cached_network_image.dart';

int? _siralananSutun; 
int _siralamaDurumu = 0; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  await Hive.openBox('kitaplikBox');

  runApp(const KutuphaneUygulamasi());
}

class KutuphaneUygulamasi extends StatelessWidget {
  const KutuphaneUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kitap Kataloğum Mobil',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AnaEkran(),
    );
  }
}

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  final _kitaplikKutusu = Hive.box('kitaplikBox');
  
  final List<Map<String, dynamic>> tumKitaplar = [
    {'isim': 'Suç ve Ceza', 'yazar': 'Fyodor Dostoyevski', 'tur': 'Roman', 'yayinevi': 'İş Bankası Kültür Yayınları'},
    {'isim': 'Sapiens', 'yazar': 'Yuval Noah Harari', 'tur': 'Tarih', 'yayinevi': 'Kolektif Kitap'},
    {'isim': 'Dune', 'yazar': 'Frank Herbert', 'tur': 'Bilim Kurgu', 'yayinevi': 'İthaki Yayınları'},
  ];

  List<Map<String, dynamic>> filtrelenmisKitaplar = [];
  final TextEditingController aramaKontrolcusu = TextEditingController();

  @override
  void initState() {
    super.initState();
    _veritabanindanYukle(); 
  }

  void _veritabanindanYukle() {
    setState(() {
      try {
        final veriler = _kitaplikKutusu.get('kitaplar', defaultValue: []);
        
        if (veriler != null && veriler is List && veriler.isNotEmpty) {
          tumKitaplar.clear(); 
          for (var e in veriler) {
            if (e is Map) {
              tumKitaplar.add({
                'isim': e['isim']?.toString() ?? '',
                'yazar': e['yazar']?.toString() ?? '',
                'tur': e['tur']?.toString() ?? '',
                'yayinevi': e['yayinevi']?.toString() ?? '',
              });
            }
          }
        } else {
          _veritabaninaKaydet();
        }
        _kitapFiltrele(''); 
      } catch (e) {
        debugPrint("Veritabanı yüklenirken bir hata oluştu: $e");
        _kitapFiltrele('');
      }
    });
  }
  
  void _veritabaninaKaydet() {
    _kitaplikKutusu.put('kitaplar', tumKitaplar);
  }

  void _kitapFiltrele(String arananKelime) {
    setState(() {
      if (arananKelime.trim().isEmpty) {
        filtrelenmisKitaplar = List.from(tumKitaplar);
      } else {
        final query = arananKelime.toLowerCase();
        filtrelenmisKitaplar = tumKitaplar.where((kitap) {
          final isim = (kitap['isim'] ?? '').toString().toLowerCase();
          final yazar = (kitap['yazar'] ?? '').toString().toLowerCase();
          final tur = (kitap['tur'] ?? '').toString().toLowerCase();
          final yayinevi = (kitap['yayinevi'] ?? '').toString().toLowerCase();

          return isim.contains(query) || yazar.contains(query) || tur.contains(query) || yayinevi.contains(query);
        }).toList();
      }
    });
  }

  void _silmeOnayiGoster(BuildContext context, Map<String, dynamic> kitap) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Silme Onayı'),
          content: Text('${kitap['isim']} adlı kitabı silmek istediğinize emin misiniz?'),
          actions: [
            TextButton(
              child: const Text('İptal'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop(); 
                _kitapSil(kitap); 
              },
            ),
          ],
        );
      },
    );
  }
  
  // Kamera ile barkod okuma fonksiyonu (Yeni ve Güncel Paket)
  Future<void> _kameradanBarkodOku(TextEditingController isbnKontrolcusu) async {
    try {
      var sonuc = await BarcodeScanner.scan();
      
      // Kullanıcı taramayı iptal etmediyse ve bir barkod okunduysa
      if (sonuc.type == ResultType.Barcode && sonuc.rawContent.isNotEmpty) {
        isbnKontrolcusu.text = sonuc.rawContent; // Okunan numarayı kutuya yaz
      }
    } catch (e) {
      debugPrint('Barkod okuma hatası: $e');
    }
  }

  Future<void> _isbnIleKitapBul(String isbn, TextEditingController isim, TextEditingController yazar, TextEditingController tur, TextEditingController yayinevi) async {
    final temizIsbn = isbn.replaceAll('-', '').replaceAll(' ', '').trim();
    if (temizIsbn.isEmpty) return;

    // Ekranın ortasında, alttaki pencerenin arkasında kalmayan özel bildirim tasarımı
    void uyariGoster(String mesaj) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mesaj, style: const TextStyle(color: Colors.white)),
          behavior: SnackBarBehavior.floating, // Bildirimi havaya kaldırır
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.4, // Ekranın %40 yukarı hizasına yerleştirir
            left: 20, right: 20
          ),
          backgroundColor: Colors.black87,
          duration: const Duration(seconds: 2),
        )
      );
    }

    if (temizIsbn.length != 10 && temizIsbn.length != 13) {
      uyariGoster('Hata: Barkod numarası 10 veya 13 haneli olmalıdır!');
      return; 
    }
    
    uyariGoster('OpenLibrary\'de aranıyor...');

    try {
      final url = Uri.parse('https://openlibrary.org/search.json?q=$temizIsbn');
      final response = await http.get(url);

      if (!mounted) return; 

      if (response.statusCode == 200) {
        final veri = json.decode(response.body);
        if (veri['numFound'] != null && veri['numFound'] > 0) {
          final bilgi = veri['docs'][0]; 
          isim.text = bilgi['title'] ?? '';
          yazar.text = (bilgi['author_name'] as List?)?.join(', ') ?? '';
          tur.text = (bilgi['subject'] as List?)?.take(3).join(', ') ?? '';
          yayinevi.text = (bilgi['publisher'] as List?)?.first?.toString() ?? '';
          uyariGoster('Kitap bulundu, bilgiler dolduruldu!');
        } else {
          uyariGoster('Kitap OpenLibrary arşivinde yok, elle girebilirsiniz.');
        }
      } else {
        uyariGoster('Sunucu hatası: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      uyariGoster('Bağlantı hatası: İnternetinizi kontrol edin.');
    }
  }

  void _kitapDuzenlemePenceresiniAc(BuildContext context, Map<String, dynamic> kitap) {
    final isimController = TextEditingController(text: kitap['isim']);
    final yazarController = TextEditingController(text: kitap['yazar']);
    final turController = TextEditingController(text: kitap['tur']);
    final yayineviController = TextEditingController(text: kitap['yayinevi']);
    final notlarController = TextEditingController(text: kitap['notlar'] ?? ''); // Notları getir

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 40, 
            top: 20, left: 20, right: 20,
          ),
          // Klavye açıldığında resmin yukarı kayabilmesi için SingleChildScrollView ekledik
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // YENİ: BÜYÜK KAPAK FOTOĞRAFI
                if (kitap['kapakUrl'] != null && kitap['kapakUrl'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      // KALICI RESİM KODU (Büyük Kapak)
                      child: CachedNetworkImage(
                        imageUrl: kitap['kapakUrl'], 
                        height: 150, 
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())), // Yüklenirken dönen ikon
                        errorWidget: (context, url, error) => const Icon(Icons.book, size: 80, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: Icon(Icons.book, size: 80, color: Colors.grey),
                  ),

                TextField(controller: isimController, decoration: const InputDecoration(labelText: 'Kitap Adı', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                TextField(controller: yazarController, decoration: const InputDecoration(labelText: 'Yazar', border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: turController, decoration: const InputDecoration(labelText: 'Tür', border: OutlineInputBorder(), isDense: true))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: yayineviController, decoration: const InputDecoration(labelText: 'Yayınevi', border: OutlineInputBorder(), isDense: true))),
                  ],
                ),
                const SizedBox(height: 10),
                // YENİ: KİŞİSEL NOTLAR ALANI
                TextField(
                  controller: notlarController, 
                  maxLines: 3, 
                  decoration: const InputDecoration(labelText: 'Kişisel Notlar / Yorumum', border: OutlineInputBorder(), alignLabelWithHint: true)
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () {
                      if (isimController.text.trim().isNotEmpty) {
                        setState(() {
                          kitap['isim'] = isimController.text.trim();
                          kitap['yazar'] = yazarController.text.trim().isEmpty ? 'Bilinmiyor' : yazarController.text.trim();
                          kitap['tur'] = turController.text.trim().isEmpty ? 'Bilinmiyor' : turController.text.trim();
                          kitap['yayinevi'] = yayineviController.text.trim().isEmpty ? 'Bilinmiyor' : yayineviController.text.trim();
                          kitap['notlar'] = notlarController.text.trim(); // Notları güncelle
                          _kitapFiltrele(aramaKontrolcusu.text); 
                          _veritabaninaKaydet(); 
                        });
                        Navigator.of(ctx).pop(); 
                      }
                    },
                    child: const Text('Değişiklikleri Kaydet', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _sutunaGoreSirala(int sutunIndex, String anahtar) {
    setState(() {
      if (_siralananSutun == sutunIndex) {
        _siralamaDurumu = (_siralamaDurumu + 1) % 3;
      } else {
        _siralananSutun = sutunIndex;
        _siralamaDurumu = 1;
      }

      if (_siralamaDurumu == 0) {
        _kitapFiltrele(aramaKontrolcusu.text); 
      } else {
        tumKitaplar.sort((a, b) {
          final degerA = (a[anahtar] ?? '').toString().toLowerCase();
          final degerB = (b[anahtar] ?? '').toString().toLowerCase();
          final karsilastirma = degerA.compareTo(degerB);
          return _siralamaDurumu == 1 ? karsilastirma : -karsilastirma;
        });
        _kitapFiltrele(aramaKontrolcusu.text); 
      }
    });
  }

  void _kitapEklemePenceresiniAc(BuildContext context) {
    final isbnController = TextEditingController();
    final isimController = TextEditingController();
    final yazarController = TextEditingController();
    final turController = TextEditingController();
    final yayineviController = TextEditingController();
    final notlarController = TextEditingController(); // YENİ: Yorum ve notlar için

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 40, 
            top: 20, left: 20, right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Yeni Kitap Ekle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: isbnController,
                      decoration: const InputDecoration(labelText: 'ISBN / Barkod', border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code), isDense: true),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _kameradanBarkodOku(isbnController),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(12), backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                    child: const Icon(Icons.camera_alt),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _isbnIleKitapBul(isbnController.text, isimController, yazarController, turController, yayineviController),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(12), backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white),
                    child: const Icon(Icons.search),
                  ),
                ],
              ),
              const Divider(height: 20),
              TextField(controller: isimController, decoration: const InputDecoration(labelText: 'Kitap Adı', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: yazarController, decoration: const InputDecoration(labelText: 'Yazar', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: turController, decoration: const InputDecoration(labelText: 'Tür', border: OutlineInputBorder(), isDense: true))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: yayineviController, decoration: const InputDecoration(labelText: 'Yayınevi', border: OutlineInputBorder(), isDense: true))),
                ],
              ),
              const SizedBox(height: 10),
              // YENİ: KİŞİSEL NOTLAR ALANI
              TextField(
                controller: notlarController, 
                maxLines: 3, 
                decoration: const InputDecoration(labelText: 'Kişisel Notlar / Yorumum', border: OutlineInputBorder(), alignLabelWithHint: true)
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () {
                    if (isimController.text.trim().isNotEmpty) {
                      // ISBN varsa kapağı OpenLibrary'den çekmek için link oluştur
                      String kapakUrl = '';
                      if (isbnController.text.trim().isNotEmpty) {
                        String temizIsbn = isbnController.text.replaceAll('-', '').replaceAll(' ', '').trim();
                        kapakUrl = 'https://covers.openlibrary.org/b/isbn/$temizIsbn-M.jpg'; // M: Medium boy resim
                      }

                      setState(() {
                        tumKitaplar.add({
                          'isim': isimController.text.trim(),
                          'yazar': yazarController.text.trim().isEmpty ? 'Bilinmiyor' : yazarController.text.trim(),
                          'tur': turController.text.trim().isEmpty ? 'Bilinmiyor' : turController.text.trim(),
                          'yayinevi': yayineviController.text.trim().isEmpty ? 'Bilinmiyor' : yayineviController.text.trim(),
                          'notlar': notlarController.text.trim(), // Notları kaydet
                          'kapakUrl': kapakUrl, // Kapak linkini kaydet
                        });
                        _kitapFiltrele(aramaKontrolcusu.text); 
                        _veritabaninaKaydet();
                      });
                      Navigator.of(ctx).pop(); 
                    }
                  },
                  child: const Text('Kitabı Kaydet', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _kitapSil(Map<String, dynamic> kitap) {
    final int silinenIndeks = tumKitaplar.indexOf(kitap); 

    setState(() {
      tumKitaplar.remove(kitap);
      _kitapFiltrele(aramaKontrolcusu.text);
      _veritabaninaKaydet(); 
    });

    ScaffoldMessenger.of(context).clearSnackBars(); 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${kitap['isim']} silindi.'),
        action: SnackBarAction(
          label: 'GERİ AL',
          onPressed: () {
            setState(() {
              tumKitaplar.insert(silinenIndeks, kitap); 
              _kitapFiltrele(aramaKontrolcusu.text);
              _veritabaninaKaydet();
            });
          },
        ),
      ),
    );
    
    Timer(const Duration(seconds: 4), () {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }
  
  @override
  void dispose() {
    aramaKontrolcusu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kitaplık',
          style: TextStyle(
            fontFamily: 'Georgia', // Yazı fontu
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        // Gradyan (renk geçişi) arka plan ayarı
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromARGB(255, 195, 0, 0), Color.fromARGB(255, 78, 3, 18)], // Koyu Kadife ve Kızıl tonları
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white), 
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
            child: TextField(
              controller: aramaKontrolcusu,
              onChanged: _kitapFiltrele, 
              decoration: InputDecoration(
                isDense: true, // Yüksekliği sıkıştırır
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), // İç kalınlığı daraltır
                hintText: 'Kitap, yazar vb. ara...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: aramaKontrolcusu.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          aramaKontrolcusu.clear();
                          _kitapFiltrele('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: filtrelenmisKitaplar.isEmpty
                ? const Center(child: Text('Eşleşen kitap bulunamadı.', style: TextStyle(fontSize: 16, color: Colors.grey)))
                : Expanded(
                  child: SizedBox(
                    width: double.infinity, 
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical, 
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal, 
                        child: DataTable(
                          // BURADAKİ İKİ DEĞER ARADAKİ BOŞLUKLARI ERİTİR:
                          columnSpacing: 20.0, // Sütunlar (Sayı ile Kitap adı) arasındaki boşluğu iyice daralttık
                          horizontalMargin: 20.0, // Tablonun sağ ve sol kenarından bırakılan boşluğu daralttık
                          
                          showCheckboxColumn: false,
                          headingRowHeight: 40.0,
                          // ... geri kalan kodların aynı şekilde devam ediyor ...
                          columns: [
                            // # Sütununu 25 piksel genişliğe sabitledik
                            const DataColumn(label: SizedBox(width: 15, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold)))),
                            DataColumn(label: const Text('Kitap Adı', style: TextStyle(fontWeight: FontWeight.bold)), onSort: (columnIndex, _) => _sutunaGoreSirala(columnIndex, 'isim')),
                            DataColumn(label: const Text('Yazar', style: TextStyle(fontWeight: FontWeight.bold)), onSort: (columnIndex, _) => _sutunaGoreSirala(columnIndex, 'yazar')),
                            const DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold))), // Sadece silme butonu kalacak
                          ],
                          rows: filtrelenmisKitaplar.asMap().entries.map((entry) {
                            int index = entry.key; // Satır numarası (0'dan başlar)
                            var kitap = entry.value;

                            return DataRow(
                              // Satırın herhangi bir yerine tıklandığında detay/düzenleme sayfasını aç
                              onSelectChanged: (secildi) {
                                _kitapDuzenlemePenceresiniAc(context, kitap);
                              },
                              cells: [
                                // Numaralandırma (+1 ekliyoruz çünkü indeks 0'dan başlar)
                                DataCell(Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                                // Kitap kapağı ve ismini yan yana gösteren hücre
                                DataCell(
                                  Row(
                                    children: [
                                      // Kapak resmi varsa göster, yoksa gri bir kitap ikonu koy
                                      (kitap['kapakUrl'] != null && kitap['kapakUrl'].toString().isNotEmpty)
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              // KALICI RESİM KODU (Küçük Kapak)
                                              child: CachedNetworkImage(
                                                imageUrl: kitap['kapakUrl'],
                                                width: 30,
                                                height: 45,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => const SizedBox(width: 30, height: 45, child: Center(child: CircularProgressIndicator(strokeWidth: 2))), // Yüklenirken dönen ikon
                                                errorWidget: (context, url, error) => const Icon(Icons.book, size: 30, color: Colors.grey),
                                              ),
                                            )
                                          : const Icon(Icons.book, size: 30, color: Colors.grey),
                                      const SizedBox(width: 10),
                                      // Uzun isimleri sığdırmak için SizedBox kullandık
                                      SizedBox(
                                        width: 100, 
                                        child: Text(kitap['isim']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(kitap['yazar']?.toString() ?? '')),
                                DataCell(
                                  // Artık sadece Silme butonu var, Düzenle butonu kaldırıldı
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red), 
                                    onPressed: () => _silmeOnayiGoster(context, kitap)
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        )
                      ),
                    ),
                  ),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _kitapEklemePenceresiniAc(context),
        backgroundColor: const Color(0xFF8B0000), // Üst barla aynı kadife kırmızı
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}