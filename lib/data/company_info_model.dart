import 'dart:typed_data';

class CompanyInfo {
  final String name;
  final String address;
  final String phoneNo;
  final String email;
  final Uint8List? pictureBytes;
  final String pictureMime;

  const CompanyInfo({
    required this.name,
    required this.address,
    required this.phoneNo,
    required this.email,
    required this.pictureBytes,
    required this.pictureMime,
  });

  static const empty = CompanyInfo(
    name: '',
    address: '',
    phoneNo: '',
    email: '',
    pictureBytes: null,
    pictureMime: '',
  );

  CompanyInfo copyWith({
    String? name,
    String? address,
    String? phoneNo,
    String? email,
    Uint8List? pictureBytes,
    String? pictureMime,
  }) {
    return CompanyInfo(
      name: name ?? this.name,
      address: address ?? this.address,
      phoneNo: phoneNo ?? this.phoneNo,
      email: email ?? this.email,
      pictureBytes: pictureBytes ?? this.pictureBytes,
      pictureMime: pictureMime ?? this.pictureMime,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'ID': 1,
      'Name': name,
      'Address': address,
      'Phone_No': phoneNo,
      'E_Mail': email,
      'Picture_Blob': pictureBytes,
      'Picture_Mime': pictureMime,
    };
  }

  factory CompanyInfo.fromMap(Map<String, Object?> map) {
    final blob = map['Picture_Blob'];
    Uint8List? picture;
    if (blob is Uint8List) {
      picture = blob;
    } else if (blob is List<int>) {
      picture = Uint8List.fromList(blob);
    }

    return CompanyInfo(
      name: (map['Name'] as String?)?.trim() ?? '',
      address: (map['Address'] as String?)?.trim() ?? '',
      phoneNo: (map['Phone_No'] as String?)?.trim() ?? '',
      email: (map['E_Mail'] as String?)?.trim() ?? '',
      pictureBytes: picture,
      pictureMime: (map['Picture_Mime'] as String?)?.trim() ?? '',
    );
  }
}
