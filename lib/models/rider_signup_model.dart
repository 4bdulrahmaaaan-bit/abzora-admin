enum VehicleType { bike, cycle, evScooter }

enum WorkType { fullTime, partTime }

class RiderSignupModel {
  const RiderSignupModel({
    this.phone = '',
    this.fullName = '',
    this.email = '',
    this.dob,
    this.gender = 'Male',
    this.city = '',
    this.profilePhotoPath,
    this.vehicleType = VehicleType.bike,
    this.vehicleNumber = '',
    this.licenseNumber = '',
    this.rcPath,
    this.insurancePath,
    this.aadhaar = '',
    this.pan = '',
    this.licenseDocPath,
    this.selfiePath,
    this.accountHolder = '',
    this.bankName = '',
    this.accountNumber = '',
    this.ifsc = '',
    this.upi = '',
    this.referral = '',
    this.workType = WorkType.fullTime,
    this.shift = 'Morning',
    this.acceptedTerms = false,
    this.signature = '',
  });

  final String phone;
  final String fullName;
  final String email;
  final DateTime? dob;
  final String gender;
  final String city;
  final String? profilePhotoPath;
  final VehicleType vehicleType;
  final String vehicleNumber;
  final String licenseNumber;
  final String? rcPath;
  final String? insurancePath;
  final String aadhaar;
  final String pan;
  final String? licenseDocPath;
  final String? selfiePath;
  final String accountHolder;
  final String bankName;
  final String accountNumber;
  final String ifsc;
  final String upi;
  final String referral;
  final WorkType workType;
  final String shift;
  final bool acceptedTerms;
  final String signature;

  RiderSignupModel copyWith({
    String? phone,
    String? fullName,
    String? email,
    DateTime? dob,
    String? gender,
    String? city,
    String? profilePhotoPath,
    VehicleType? vehicleType,
    String? vehicleNumber,
    String? licenseNumber,
    String? rcPath,
    String? insurancePath,
    String? aadhaar,
    String? pan,
    String? licenseDocPath,
    String? selfiePath,
    String? accountHolder,
    String? bankName,
    String? accountNumber,
    String? ifsc,
    String? upi,
    String? referral,
    WorkType? workType,
    String? shift,
    bool? acceptedTerms,
    String? signature,
  }) {
    return RiderSignupModel(
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      city: city ?? this.city,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      rcPath: rcPath ?? this.rcPath,
      insurancePath: insurancePath ?? this.insurancePath,
      aadhaar: aadhaar ?? this.aadhaar,
      pan: pan ?? this.pan,
      licenseDocPath: licenseDocPath ?? this.licenseDocPath,
      selfiePath: selfiePath ?? this.selfiePath,
      accountHolder: accountHolder ?? this.accountHolder,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifsc: ifsc ?? this.ifsc,
      upi: upi ?? this.upi,
      referral: referral ?? this.referral,
      workType: workType ?? this.workType,
      shift: shift ?? this.shift,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      signature: signature ?? this.signature,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'fullName': fullName,
      'email': email,
      'dob': dob?.toIso8601String(),
      'gender': gender,
      'city': city,
      'profilePhotoPath': profilePhotoPath,
      'vehicleType': vehicleType.name,
      'vehicleNumber': vehicleNumber,
      'licenseNumber': licenseNumber,
      'rcPath': rcPath,
      'insurancePath': insurancePath,
      'aadhaar': aadhaar,
      'pan': pan,
      'licenseDocPath': licenseDocPath,
      'selfiePath': selfiePath,
      'accountHolder': accountHolder,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifsc': ifsc,
      'upi': upi,
      'referral': referral,
      'workType': workType.name,
      'shift': shift,
      'acceptedTerms': acceptedTerms,
      'signature': signature,
    };
  }

  static RiderSignupModel fromJson(Map<String, dynamic> json) {
    VehicleType parseVehicle(String? v) {
      return VehicleType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => VehicleType.bike,
      );
    }

    WorkType parseWork(String? v) {
      return WorkType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => WorkType.fullTime,
      );
    }

    return RiderSignupModel(
      phone: (json['phone'] ?? '') as String,
      fullName: (json['fullName'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      dob: json['dob'] == null ? null : DateTime.tryParse(json['dob'] as String),
      gender: (json['gender'] ?? 'Male') as String,
      city: (json['city'] ?? '') as String,
      profilePhotoPath: json['profilePhotoPath'] as String?,
      vehicleType: parseVehicle(json['vehicleType'] as String?),
      vehicleNumber: (json['vehicleNumber'] ?? '') as String,
      licenseNumber: (json['licenseNumber'] ?? '') as String,
      rcPath: json['rcPath'] as String?,
      insurancePath: json['insurancePath'] as String?,
      aadhaar: (json['aadhaar'] ?? '') as String,
      pan: (json['pan'] ?? '') as String,
      licenseDocPath: json['licenseDocPath'] as String?,
      selfiePath: json['selfiePath'] as String?,
      accountHolder: (json['accountHolder'] ?? '') as String,
      bankName: (json['bankName'] ?? '') as String,
      accountNumber: (json['accountNumber'] ?? '') as String,
      ifsc: (json['ifsc'] ?? '') as String,
      upi: (json['upi'] ?? '') as String,
      referral: (json['referral'] ?? '') as String,
      workType: parseWork(json['workType'] as String?),
      shift: (json['shift'] ?? 'Morning') as String,
      acceptedTerms: (json['acceptedTerms'] ?? false) as bool,
      signature: (json['signature'] ?? '') as String,
    );
  }
}
