class PhProvince {
  final String code;
  final String name;
  final String regionCode;
  final String islandGroupCode;
  final String psgc10DigitCode;

  const PhProvince(
    this.code,
    this.name,
    this.regionCode,
    this.islandGroupCode,
    this.psgc10DigitCode,
  );
}

/// Service area restricted strictly to Albay Province (1st District).
List<PhProvince> get phProvincesSorted =>
    List<PhProvince>.of(phProvinces)..sort((a, b) => a.name.compareTo(b.name));

const List<PhProvince> phProvinces = [
  PhProvince('050500000', 'Albay', '050000000', 'luzon', '0500500000'),
];
