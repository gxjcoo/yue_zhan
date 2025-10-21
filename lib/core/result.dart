/// 统一的结果类型，用于处理成功和失败情况
/// 
/// 使用示例：
/// ```dart
/// Future<Result<User>> getUser(String id) async {
///   try {
///     final user = await api.fetchUser(id);
///     return Result.success(user);
///   } catch (e) {
///     return Result.failure('获取用户失败', error: e);
///   }
/// }
/// 
/// // 使用
/// final result = await getUser('123');
/// if (result.isSuccess) {
///   print(result.data!.name);
/// } else {
///   print(result.message);
/// }
/// ```
class Result<T> {
  /// 数据（成功时非空）
  final T? data;
  
  /// 错误消息
  final String? message;
  
  /// 原始错误对象
  final Object? error;
  
  /// 堆栈追踪
  final StackTrace? stackTrace;
  
  /// 是否成功
  final bool isSuccess;
  
  /// 是否失败
  bool get isFailure => !isSuccess;
  
  /// 错误代码（可选）
  final String? errorCode;
  
  /// 私有构造函数
  Result._({
    required this.isSuccess,
    this.data,
    this.message,
    this.error,
    this.stackTrace,
    this.errorCode,
  });
  
  /// 创建成功结果
  factory Result.success(T data) {
    return Result._(
      isSuccess: true,
      data: data,
    );
  }
  
  /// 创建失败结果
  factory Result.failure(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? errorCode,
  }) {
    return Result._(
      isSuccess: false,
      message: message,
      error: error,
      stackTrace: stackTrace,
      errorCode: errorCode,
    );
  }
  
  /// 从异常创建失败结果
  factory Result.fromException(
    Exception exception, {
    String? customMessage,
    String? errorCode,
  }) {
    return Result._(
      isSuccess: false,
      message: customMessage ?? exception.toString(),
      error: exception,
      errorCode: errorCode,
    );
  }
  
  /// 从错误创建失败结果
  factory Result.fromError(
    Object error, {
    String? customMessage,
    StackTrace? stackTrace,
    String? errorCode,
  }) {
    return Result._(
      isSuccess: false,
      message: customMessage ?? error.toString(),
      error: error,
      stackTrace: stackTrace,
      errorCode: errorCode,
    );
  }
  
  /// 映射数据（如果成功）
  Result<R> map<R>(R Function(T data) mapper) {
    if (isSuccess && data != null) {
      try {
        return Result.success(mapper(data as T));
      } catch (e, stackTrace) {
        return Result.failure(
          '数据转换失败',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    return Result.failure(
      message ?? '操作失败',
      error: error,
      stackTrace: stackTrace,
      errorCode: errorCode,
    );
  }
  
  /// 扁平映射（避免嵌套 Result）
  Result<R> flatMap<R>(Result<R> Function(T data) mapper) {
    if (isSuccess && data != null) {
      try {
        return mapper(data as T);
      } catch (e, stackTrace) {
        return Result.failure(
          '操作失败',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    return Result.failure(
      message ?? '操作失败',
      error: error,
      stackTrace: stackTrace,
      errorCode: errorCode,
    );
  }
  
  /// 当成功时执行操作
  void onSuccess(void Function(T data) action) {
    if (isSuccess && data != null) {
      action(data as T);
    }
  }
  
  /// 当失败时执行操作
  void onFailure(void Function(String message) action) {
    if (isFailure && message != null) {
      action(message!);
    }
  }
  
  /// 折叠（处理成功和失败两种情况）
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(String message) onFailure,
  }) {
    if (isSuccess && data != null) {
      return onSuccess(data as T);
    }
    return onFailure(message ?? '未知错误');
  }
  
  /// 获取数据或默认值
  T getOrElse(T defaultValue) {
    return data ?? defaultValue;
  }
  
  /// 获取数据或抛出异常
  T getOrThrow() {
    if (isSuccess && data != null) {
      return data as T;
    }
    throw Exception(message ?? '操作失败');
  }
  
  @override
  String toString() {
    if (isSuccess) {
      return 'Result.success($data)';
    }
    return 'Result.failure(message: $message, error: $error)';
  }
}

/// 针对无返回值操作的 Result
class VoidResult extends Result<void> {
  VoidResult._({
    required super.isSuccess,
    super.message,
    super.error,
    super.stackTrace,
    super.errorCode,
  }) : super._();
  
  /// 创建成功结果
  factory VoidResult.success() {
    return VoidResult._(isSuccess: true);
  }
  
  /// 创建失败结果
  factory VoidResult.failure(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? errorCode,
  }) {
    return VoidResult._(
      isSuccess: false,
      message: message,
      error: error,
      stackTrace: stackTrace,
      errorCode: errorCode,
    );
  }
}

/// Result 扩展方法
extension ResultExtensions<T> on Future<Result<T>> {
  /// 当成功时执行操作
  Future<Result<T>> onSuccess(void Function(T data) action) async {
    final result = await this;
    result.onSuccess(action);
    return result;
  }
  
  /// 当失败时执行操作
  Future<Result<T>> onFailure(void Function(String message) action) async {
    final result = await this;
    result.onFailure(action);
    return result;
  }
}

/// 常用错误代码
class ErrorCodes {
  static const String networkError = 'NETWORK_ERROR';
  static const String timeout = 'TIMEOUT';
  static const String unauthorized = 'UNAUTHORIZED';
  static const String notFound = 'NOT_FOUND';
  static const String validationError = 'VALIDATION_ERROR';
  static const String serverError = 'SERVER_ERROR';
  static const String unknown = 'UNKNOWN_ERROR';
  static const String cancelled = 'CANCELLED';
  static const String fileNotFound = 'FILE_NOT_FOUND';
  static const String permissionDenied = 'PERMISSION_DENIED';
  static const String duplicateOperation = 'DUPLICATE_OPERATION';
}

