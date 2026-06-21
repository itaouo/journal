class Picture {
  final String pictureUrl;
  final String? caption;
  final bool isLocalFile;
  final String? driveFileId;
  final bool isEncrypted;

  Picture({
    required this.pictureUrl,
    this.caption,
    this.isLocalFile = false,
    this.driveFileId,
    this.isEncrypted = false,
  });

  factory Picture.fromFile(String filePath, {String? caption, bool isEncrypted = false}) {
    return Picture(
      pictureUrl: filePath,
      caption: caption,
      isLocalFile: true,
      isEncrypted: isEncrypted,
    );
  }

  factory Picture.fromUrl(
    String url, {
    String? caption,
    String? driveFileId,
    bool isEncrypted = false,
  }) {
    return Picture(
      pictureUrl: url,
      caption: caption,
      isLocalFile: false,
      driveFileId: driveFileId,
      isEncrypted: isEncrypted,
    );
  }

  static String driveThumbnailUrl(String fileId) =>
      'https://drive.google.com/thumbnail?id=$fileId';

  bool isValid() {
    if (pictureUrl.isEmpty) return false;
    if (isLocalFile) return true;
    return pictureUrl.startsWith('http://') ||
        pictureUrl.startsWith('https://');
  }

  /// 當 pictureUrl 為空但仍有 driveFileId 時，改用 Drive 縮圖 URL 供列表顯示。
  Picture withDisplayFallback() {
    if (isValid()) return this;
    if (driveFileId != null) {
      return Picture.fromUrl(
        driveThumbnailUrl(driveFileId!),
        caption: caption,
        driveFileId: driveFileId,
        isEncrypted: isEncrypted,
      );
    }
    return this;
  }
}
