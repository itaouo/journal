class Picture {
  final String pictureUrl;
  final String? caption;
  final bool isLocalFile; // 標記是否為本地檔案

  Picture({
    required this.pictureUrl,
    this.caption,
    this.isLocalFile = false, // 預設為網路圖片
  });

  /// 從本地檔案路徑創建圖片
  factory Picture.fromFile(String filePath, {String? caption}) {
    return Picture(
      pictureUrl: filePath,
      caption: caption,
      isLocalFile: true,
    );
  }

  /// 從網路URL創建圖片
  factory Picture.fromUrl(String url, {String? caption}) {
    return Picture(
      pictureUrl: url,
      caption: caption,
      isLocalFile: false,
    );
  }

  /// 檢查圖片是否有效（基本驗證）
  bool isValid() {
    if (pictureUrl.isEmpty) return false;
    if (isLocalFile) return true; // 本地檔案只要路徑不為空就視為有效
    return pictureUrl.startsWith('http://') || pictureUrl.startsWith('https://');
  }
}
