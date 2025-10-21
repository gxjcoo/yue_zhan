class PermissionDeniedException implements Exception {
  final String message;

  PermissionDeniedException([this.message = '权限被拒绝']);

  @override
  String toString() => 'PermissionDeniedException: $message';
}