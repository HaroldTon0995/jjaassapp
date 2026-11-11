import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';

class CompliancePermitModel {
  final String id;
  final String title;
  final String category;
  String fileName;
  String? imageData; // Base64 Data URL or storage URL
  String status;
  String uploadedAt;
  String expiryDate;
  bool isUploaded;

  CompliancePermitModel({
    required this.id,
    required this.title,
    required this.category,
    required this.fileName,
    this.imageData,
    this.status = 'Valid & Uploaded',
    required this.uploadedAt,
    required this.expiryDate,
    this.isUploaded = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'fileName': fileName,
        'imageData': imageData,
        'status': status,
        'uploadedAt': uploadedAt,
        'expiryDate': expiryDate,
        'isUploaded': isUploaded,
      };

  factory CompliancePermitModel.fromJson(Map<String, dynamic> json) =>
      CompliancePermitModel(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Station Compliance Document',
        category: json['category'] as String? ?? 'Regulatory Permit',
        fileName: json['fileName'] as String? ?? 'Permit_Document.png',
        imageData: json['imageData'] as String?,
        status: json['status'] as String? ?? 'Valid & Uploaded',
        uploadedAt: json['uploadedAt'] as String? ?? '2026-01-15',
        expiryDate: json['expiryDate'] as String? ?? '2026-12-31',
        isUploaded: json['isUploaded'] == true,
      );
}

class CompliancePermitService extends ChangeNotifier {
  static final CompliancePermitService instance = CompliancePermitService._();
  CompliancePermitService._() {
    _initDefaults();
    loadPermits();
  }

  final List<CompliancePermitModel> _permits = [];
  List<CompliancePermitModel> get permits => List.unmodifiable(_permits);

  bool get isSupabaseConfigured => AppConstants.isSupabaseConfigured;

  void _initDefaults() {
    _permits.clear();
    _permits.addAll([
      CompliancePermitModel(
        id: 'permit_mayor',
        title: "Mayor's / Business Permit (LGU Albay)",
        category: 'LGU Local Governance & Operation License',
        fileName: 'Mayors_Permit_TabacoCity_2026.png',
        status: 'Valid & Uploaded',
        uploadedAt: '2026-01-15',
        expiryDate: '2026-12-31',
        isUploaded: true,
      ),
      CompliancePermitModel(
        id: 'permit_sanitary',
        title: 'DOH Sanitary Permit & Health Certificates',
        category: 'DOH & City Health Office Sanitation Clearance',
        fileName: 'DOH_Sanitary_Permit_Albay_2026.png',
        status: 'Valid & Uploaded',
        uploadedAt: '2026-01-20',
        expiryDate: '2026-12-31',
        isUploaded: true,
      ),
      CompliancePermitModel(
        id: 'permit_water_lab',
        title: 'Physical & Chemical Laboratory Water Test',
        category: 'PNSDW Philippine National Drinking Water Potability Certificate',
        fileName: 'Water_Bacteriological_LabTest_2026.png',
        status: 'Valid & Uploaded',
        uploadedAt: '2026-02-01',
        expiryDate: '2026-12-31',
        isUploaded: true,
      ),
      CompliancePermitModel(
        id: 'permit_dti',
        title: 'DTI Business Name Registration Certificate',
        category: 'Department of Trade and Industry National Business Registry',
        fileName: 'DTI_Registration_JJAASS_2026.png',
        status: 'Valid & Uploaded',
        uploadedAt: '2026-01-10',
        expiryDate: '2026-12-31',
        isUploaded: true,
      ),
      CompliancePermitModel(
        id: 'permit_fsic',
        title: 'Fire Safety Inspection Certificate (FSIC)',
        category: 'Bureau of Fire Protection Safety & Hazard Clearance',
        fileName: 'FSIC_BureauOfFire_2026.png',
        status: 'Valid & Uploaded',
        uploadedAt: '2026-01-18',
        expiryDate: '2026-12-31',
        isUploaded: true,
      ),
    ]);
  }

  Future<void> loadPermits() async {
    if (isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        final res = await client.from('station_permits').select();
        if (res.isNotEmpty) {
          for (var item in res) {
            final map = Map<String, dynamic>.from(item as Map);
            final id = map['id']?.toString() ?? '';
            final idx = _permits.indexWhere((p) => p.id == id);
            final model = CompliancePermitModel.fromJson(map);
            if (idx != -1) {
              _permits[idx] = model;
            } else {
              _permits.add(model);
            }
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Customer app load station_permits notice: $e');
      }
    }
  }
}
