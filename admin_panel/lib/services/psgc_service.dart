import 'dart:convert';
import 'package:http/http.dart' as http;

class PsgcPlace {
  final String code;
  final String name;
  const PsgcPlace(this.code, this.name);
}

/// Fetches cities/municipalities and barangays for Albay 1st District.
/// Strictly scoped to: Tabaco City, Bacacay, Malilipot, Malinao, Santo Domingo, and Tiwi.
class PsgcService {
  static const String _base = 'https://psgc.gitlab.io/api';
  static final Map<String, List<PsgcPlace>> _cache = {};

  /// Official Albay 1st District Cities & Municipalities (PSGC codes).
  static const List<PsgcPlace> albayFirstDistrictMunicipalities = [
    PsgcPlace('050517000', 'Tabaco City'),
    PsgcPlace('050501000', 'Bacacay'),
    PsgcPlace('050509000', 'Malilipot'),
    PsgcPlace('050510000', 'Malinao'),
    PsgcPlace('050516000', 'Santo Domingo'),
    PsgcPlace('050518000', 'Tiwi'),
  ];

  static const Map<String, List<String>> _fallbackBarangays = {
    '050517000': [
      'Agnas (San Miguel Island)',
      'Bacolod',
      'Bangkilingan',
      'Bantayan',
      'Baranghawon',
      'Basagan',
      'Basud (Pob.)',
      'Bogñabong',
      'Bombon (Pob.)',
      'Bonot',
      'San Isidro (Boring)',
      'Buang',
      'Buhian',
      'Cabagnan',
      'Cobo',
      'Comon',
      'Cormidal',
      'Divino Rostro (Pob.)',
      'Fatima',
      'Guinobat',
      'Hacienda (San Miguel Island)',
      'Magapo',
      'Mariroc',
      'Matagbac',
      'Oras',
      'Oson',
      'Panal',
      'Pawa',
      'Pinagbobong',
      'Quinale Cabasan (Pob.)',
      'Quinastillojan',
      'Rawis (San Miguel Island)',
      'Sagurong (San Miguel Island)',
      'Salvacion',
      'San Antonio',
      'San Carlos',
      'San Juan (Pob.)',
      'San Lorenzo',
      'San Ramon',
      'San Roque',
      'San Vicente',
      'Santo Cristo (Pob.)',
      'Sua-Igot',
      'Tabiguian',
      'Tagas',
      'Tayhi (Pob.)',
      'Visita (San Miguel Island)',
    ],
    '050501000': [
      'Baclayon',
      'Banao',
      'Barangay 1 (Pob.)',
      'Barangay 2 (Pob.)',
      'Barangay 3 (Pob.)',
      'Barangay 4 (Pob.)',
      'Barangay 5 (Pob.)',
      'Barangay 6 (Pob.)',
      'Barangay 7 (Pob.)',
      'Barangay 8 (Pob.)',
      'Barangay 9 (Pob.)',
      'Barangay 10 (Pob.)',
      'Barangay 11 (Pob.)',
      'Barangay 12 (Pob.)',
      'Barangay 13 (Pob.)',
      'Barangay 14 (Pob.)',
      'Bariw',
      'Basud',
      'Bayandong',
      'Bonga (Upper)',
      'Buang',
      'Cabasan',
      'Cagbulacao',
      'Cagraray',
      'Cajogutan',
      'Cawayan',
      'Damacan',
      'Gubat Ilawod',
      'Gubat Iraya',
      'Hindi',
      'Igang',
      'Langaton',
      'Manaet',
      'Mapulang Daga',
      'Mataas',
      'Misibis',
      'Nahapunan',
      'Namanday',
      'Namantao',
      'Napao',
      'Panarayon',
      'Pigcobohan',
      'Pili Ilawod',
      'Pili Iraya',
      'Pongco (Lower Bonga)',
      'Busdac (San Jose)',
      'San Pablo',
      'San Pedro',
      'Sogod',
      'Sula',
      'Tambilagao (Tambognon)',
      'Tambongon (Tambilagao)',
      'Tanagan',
      'Uson',
      'Vinisitahan-Basud (Mainland)',
      'Vinisitahan-Napao (Island)',
    ],
    '050509000': [
      'Binitayan',
      'Barangay I (Pob.)',
      'Barangay II (Pob.)',
      'Barangay III (Pob.)',
      'Barangay IV (Pob.)',
      'Barangay V (Pob.)',
      'Calbayog',
      'Canaway',
      'Salvacion',
      'San Antonio Santicon (Pob.)',
      'San Antonio Sulong',
      'San Francisco',
      'San Isidro Ilawod',
      'San Isidro Iraya',
      'San Jose',
      'San Roque',
      'Santa Cruz',
      'Santa Teresa',
    ],
    '050510000': [
      'Awang',
      'Bagatangki',
      'Balading',
      'Balza',
      'Bariw',
      'Baybay',
      'Bulang',
      'Burabod',
      'Cabunturan',
      'Comun',
      'Diaro',
      'Estancia',
      'Jonop',
      'Labnig',
      'Libod',
      'Malolos',
      'Matalipni',
      'Ogob',
      'Pawa',
      'Payahan',
      'Poblacion',
      'Bagumbayan',
      'Quinarabasahan',
      'Santa Elena',
      'Soa',
      'Sugcad',
      'Tagoytoy',
      'Tanawan',
      'Tuliw',
    ],
    '050516000': [
      'Alimsog',
      'Buhatan',
      'Calayucay',
      'Fidel Surtida',
      'Lidong',
      'Market Site (Pob.)',
      'Pandayan (Pob.)',
      'San Andres',
      'San Fernando',
      'San Isidro',
      'San Juan (Pob.)',
      'San Pedro (Pob.)',
      'San Rafael (Pob.)',
      'San Roque',
      'San Vicente Pedro (Pob.)',
      'Santa Misericordia',
      'Santo Domingo (Pob.)',
      'Santo Niño',
      'Sarao',
      'Del Rosario (Pob.)',
      'San Francisco (Pob.)',
      'Nagsiya (Pob.)',
      'Salvacion',
    ],
    '050518000': [
      'Bagumbayan',
      'Bariis',
      'Baybay',
      'Belen',
      'Biyong',
      'Bolo',
      'Cale',
      'Cararayan',
      'Coro-coro',
      'Dap-dap',
      'Gajo',
      'Joroan',
      'Libjo',
      'Libtong',
      'Matalibong',
      'Maynonong',
      'Mayong',
      'Misibis',
      'Naga',
      'Nagas',
      'Oyama',
      'Putsan',
      'San Bernardo',
      'Sogod',
      'Tigbi (Pob.)',
    ],
  };

  static Future<List<PsgcPlace>> getCitiesMunicipalities(
    String provinceCode,
  ) async {
    return albayFirstDistrictMunicipalities;
  }

  static Future<List<PsgcPlace>> getBarangays(String cityCode) async {
    final url = '$_base/cities-municipalities/$cityCode/barangays.json';
    final cached = _cache[url];
    if (cached != null) return cached;

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final list = data
            .map(
              (e) => PsgcPlace(
                e['code'] as String,
                (e['name'] as String).trim(),
              ),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        if (list.isNotEmpty) {
          _cache[url] = list;
          return list;
        }
      }
    } catch (_) {
      // Fallback to built-in Albay 1st District barangay list
    }

    final fallback = _fallbackBarangays[cityCode] ?? ['Poblacion'];
    final list = fallback
        .asMap()
        .entries
        .map((e) => PsgcPlace('${cityCode}_${e.key}', e.value))
        .toList();
    _cache[url] = list;
    return list;
  }
}
