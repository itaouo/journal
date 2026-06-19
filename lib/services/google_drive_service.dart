import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'auth_service.dart';
import '../models/diary.dart';
import '../models/diary_date.dart';
import '../models/picture.dart';

class UploadedImage {
  final String fileId;
  final String pictureUrl;

  const UploadedImage({
    required this.fileId,
    required this.pictureUrl,
  });
}

class DriveDiaryFile {
  final String fileId;
  final String diaryId;

  const DriveDiaryFile({
    required this.fileId,
    required this.diaryId,
  });
}

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  final AuthService _authService;

  factory GoogleDriveService({AuthService? authService}) {
    if (authService != null) {
      return GoogleDriveService._withAuth(authService);
    }
    return _instance;
  }

  GoogleDriveService._internal() : _authService = AuthService();

  GoogleDriveService._withAuth(this._authService);

  static const _appRootFolderName = 'journal';
  static const _imagesFolderName = 'image';
  static const _contentFolderName = 'content';

  String? _appRootFolderId;
  String? _imagesFolderId;
  String? _contentFolderId;

  Future<drive.DriveApi> _getDriveApi() async {
    final client = await _authService.googleSignIn.authenticatedClient();
    if (client == null) {
      throw Exception('Google 登入已過期，請重新登入');
    }
    return drive.DriveApi(client);
  }

  Future<String> _getOrCreateFolder(
    drive.DriveApi api, {
    required String name,
    String? parentId,
  }) async {
    final parentQuery = parentId == null
        ? " and 'root' in parents"
        : " and '$parentId' in parents";
    final list = await api.files.list(
      q: "name='$name' and mimeType='application/vnd.google-apps.folder' "
          "and trashed=false$parentQuery",
      spaces: 'drive',
      $fields: 'files(id)',
    );

    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }

    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';
    if (parentId != null) {
      folder.parents = [parentId];
    }

    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
  }

  Future<String> _getOrCreateAppRootFolder(drive.DriveApi api) async {
    if (_appRootFolderId != null) return _appRootFolderId!;
    _appRootFolderId =
        await _getOrCreateFolder(api, name: _appRootFolderName);
    return _appRootFolderId!;
  }

  Future<String> _getOrCreateImagesFolder(drive.DriveApi api) async {
    if (_imagesFolderId != null) return _imagesFolderId!;
    final rootId = await _getOrCreateAppRootFolder(api);
    _imagesFolderId = await _getOrCreateFolder(
      api,
      name: _imagesFolderName,
      parentId: rootId,
    );
    return _imagesFolderId!;
  }

  Future<String> _getOrCreateContentFolder(drive.DriveApi api) async {
    if (_contentFolderId != null) return _contentFolderId!;
    final rootId = await _getOrCreateAppRootFolder(api);
    _contentFolderId = await _getOrCreateFolder(
      api,
      name: _contentFolderName,
      parentId: rootId,
    );
    return _contentFolderId!;
  }

  Future<UploadedImage> uploadImage(File file, String fileName) async {
    final api = await _getDriveApi();
    final folderId = await _getOrCreateImagesFolder(api);

    final driveFile = drive.File()
      ..name = fileName
      ..parents = [folderId];

    final media = drive.Media(
      file.openRead(),
      await file.length(),
      contentType: 'image/jpeg',
    );

    final uploaded = await api.files.create(
      driveFile,
      uploadMedia: media,
      $fields: 'id',
    );

    final fileId = uploaded.id!;
    await _setPublicReadPermission(api, fileId);

    return UploadedImage(
      fileId: fileId,
      pictureUrl: Picture.driveThumbnailUrl(fileId),
    );
  }

  Future<void> _setPublicReadPermission(
    drive.DriveApi api,
    String fileId,
  ) async {
    await api.permissions.create(
      drive.Permission(
        type: 'anyone',
        role: 'reader',
      ),
      fileId,
    );
  }

  Future<void> deleteFile(String fileId) async {
    final api = await _getDriveApi();
    await api.files.delete(fileId);
  }

  Map<String, dynamic> diaryToJsonMap(Diary diary) {
    return {
      'id': diary.id,
      'createTime': diary.createTime.toUtc().toIso8601String(),
      'updateTime': diary.updateTime.toUtc().toIso8601String(),
      'isDeleted': diary.isDeleted,
      'date': diary.date.toDateString(),
      'content': diary.content,
      'pictures': diary.pictures
          .map((picture) => {
                'pictureUrl': picture.pictureUrl,
                'caption': picture.caption,
                'driveFileId': picture.driveFileId,
              })
          .toList(),
    };
  }

  Diary diaryFromJsonMap(Map<String, dynamic> data) {
    final picturesData = data['pictures'] as List<dynamic>? ?? [];

    return Diary(
      id: data['id'] as String,
      createTime: DateTime.parse(data['createTime'] as String).toLocal(),
      updateTime: DateTime.parse(data['updateTime'] as String).toLocal(),
      isDeleted: data['isDeleted'] as bool? ?? false,
      date: DiaryDate.fromString(data['date'] as String),
      content: data['content'] as String? ?? '',
      pictures: picturesData
          .map((item) {
            final map = item as Map<String, dynamic>;
            final driveFileId = map['driveFileId'] as String?;
            final pictureUrl = map['pictureUrl'] as String? ??
                (driveFileId != null
                    ? Picture.driveThumbnailUrl(driveFileId)
                    : '');
            return Picture.fromUrl(
              pictureUrl,
              caption: map['caption'] as String?,
              driveFileId: driveFileId,
            );
          })
          .toList(),
    );
  }

  Future<String> uploadDiaryJson(Diary diary) async {
    final api = await _getDriveApi();
    final folderId = await _getOrCreateContentFolder(api);
    final jsonBytes = utf8.encode(jsonEncode(diaryToJsonMap(diary)));

    final driveFile = drive.File()
      ..name = '${diary.id}.json'
      ..parents = [folderId]
      ..mimeType = 'application/json';

    final uploaded = await api.files.create(
      driveFile,
      uploadMedia: drive.Media(
        Stream.value(jsonBytes),
        jsonBytes.length,
        contentType: 'application/json',
      ),
      $fields: 'id',
    );

    return uploaded.id!;
  }

  Future<String> updateDiaryJson(Diary diary, String fileId) async {
    final api = await _getDriveApi();
    final jsonBytes = utf8.encode(jsonEncode(diaryToJsonMap(diary)));

    await api.files.update(
      drive.File()..name = '${diary.id}.json',
      fileId,
      uploadMedia: drive.Media(
        Stream.value(jsonBytes),
        jsonBytes.length,
        contentType: 'application/json',
      ),
    );

    return fileId;
  }

  Future<Diary> downloadDiaryJson(String fileId) async {
    final api = await _getDriveApi();
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = await media.stream.toList();
    final content = utf8.decode(bytes.expand((chunk) => chunk).toList());
    final data = jsonDecode(content) as Map<String, dynamic>;
    return diaryFromJsonMap(data);
  }

  Future<List<DriveDiaryFile>> listAllDiaryJsonFiles() async {
    final api = await _getDriveApi();
    final folderId = await _getOrCreateContentFolder(api);
    final files = <DriveDiaryFile>[];
    String? pageToken;

    do {
      final response = await api.files.list(
        q: "'$folderId' in parents and mimeType='application/json' "
            "and trashed=false",
        spaces: 'drive',
        $fields: 'nextPageToken, files(id, name)',
        pageToken: pageToken,
      );

      for (final file in response.files ?? const []) {
        final name = file.name;
        if (name == null || !name.endsWith('.json')) continue;
        files.add(
          DriveDiaryFile(
            fileId: file.id!,
            diaryId: name.substring(0, name.length - 5),
          ),
        );
      }
      pageToken = response.nextPageToken;
    } while (pageToken != null);

    return files;
  }

  Future<void> deleteDiaryJson(String fileId) async {
    await deleteFile(fileId);
  }

  void resetFolderCache() {
    _appRootFolderId = null;
    _imagesFolderId = null;
    _contentFolderId = null;
  }
}
