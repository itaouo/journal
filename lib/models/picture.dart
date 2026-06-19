class Picture {
  final String pictureUrl;
  final String? caption;
  final bool isLocalFile;
  final String? driveFileId;

  Picture({
    required this.pictureUrl,
    this.caption,
    this.isLocalFile = false,
    this.driveFileId,
  });

  factory Picture.fromFile(String filePath, {String? caption}) {
    return Picture(
      pictureUrl: filePath,
      caption: caption,
      isLocalFile: true,
    );
  }

  factory Picture.fromUrl(
    String url, {
    String? caption,
    String? driveFileId,
  }) {
    return Picture(
      pictureUrl: url,
      caption: caption,
      isLocalFile: false,
      driveFileId: driveFileId,
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
}
