class Collection {
  final String id;
  final DateTime createTime;
  final DateTime updateTime;
  final bool isDeleted;

  Collection({
    required this.id,
    required this.createTime,
    required this.updateTime,
    this.isDeleted = false,
  });
}
