enum LicenseType {
  display,
  commercial,
  transfer;

  String get displayName {
    switch (this) {
      case LicenseType.display:
        return 'Display';
      case LicenseType.commercial:
        return 'Commercial';
      case LicenseType.transfer:
        return 'Full Transfer';
    }
  }

  String get description {
    switch (this) {
      case LicenseType.display:
        return 'Personal display rights only';
      case LicenseType.commercial:
        return 'Commercial usage rights';
      case LicenseType.transfer:
        return 'Full copyright transfer';
    }
  }

  double get price {
    switch (this) {
      case LicenseType.display:
        return 1.00;
      case LicenseType.commercial:
        return 5.00;
      case LicenseType.transfer:
        return 10.00;
    }
  }

  int get contractValue {
    return index;
  }

  static LicenseType fromString(String value) {
    return LicenseType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => LicenseType.display,
    );
  }
}

class Token {
  final int tokenId;
  final String name;
  final String description;
  final String? previewUrl;
  final String creator;
  final String currentOwner;
  final LicenseType licenseType;
  final DateTime mintedAt;
  final String? watermarkId;
  final String? transactionHash;
  final String? encryptedBlobUri;
  final String? metadataUri;

  Token({
    required this.tokenId,
    required this.name,
    this.description = '',
    this.previewUrl,
    required this.creator,
    required this.currentOwner,
    required this.licenseType,
    required this.mintedAt,
    this.watermarkId,
    this.transactionHash,
    this.encryptedBlobUri,
    this.metadataUri,
  });

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      tokenId: json['tokenId'] as int,
      name: json['name'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      previewUrl: json['previewUrl'] as String?,
      creator: json['creator'] as String,
      currentOwner: json['currentOwner'] as String,
      licenseType: LicenseType.fromString(json['licenseType'] as String? ?? 'display'),
      mintedAt: DateTime.parse(json['mintedAt'] as String),
      watermarkId: json['watermarkId'] as String?,
      transactionHash: json['transactionHash'] as String?,
      encryptedBlobUri: json['encryptedBlobUri'] as String?,
      metadataUri: json['metadataUri'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tokenId': tokenId,
      'name': name,
      'description': description,
      'previewUrl': previewUrl,
      'creator': creator,
      'currentOwner': currentOwner,
      'licenseType': licenseType.name,
      'mintedAt': mintedAt.toIso8601String(),
      'watermarkId': watermarkId,
      'transactionHash': transactionHash,
      'encryptedBlobUri': encryptedBlobUri,
      'metadataUri': metadataUri,
    };
  }

  bool get isOwnedBy => (wallet) => currentOwner.toLowerCase() == wallet.toLowerCase();
}

class MintResult {
  final bool success;
  final int? tokenId;
  final String? transactionHash;
  final String? watermarkId;
  final String? encryptedBlobUri;
  final String? previewUri;
  final String? metadataUri;
  final String? error;

  MintResult({
    required this.success,
    this.tokenId,
    this.transactionHash,
    this.watermarkId,
    this.encryptedBlobUri,
    this.previewUri,
    this.metadataUri,
    this.error,
  });

  factory MintResult.fromJson(Map<String, dynamic> json) {
    return MintResult(
      success: json['success'] as bool? ?? false,
      tokenId: json['tokenId'] as int?,
      transactionHash: json['transactionHash'] as String?,
      watermarkId: json['watermarkId'] as String?,
      encryptedBlobUri: json['encryptedBlobUri'] as String?,
      previewUri: json['previewUri'] as String?,
      metadataUri: json['metadataUri'] as String?,
      error: json['error'] as String?,
    );
  }

  factory MintResult.error(String message) {
    return MintResult(success: false, error: message);
  }
}
