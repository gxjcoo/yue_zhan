import 'package:hive/hive.dart';

/// Hive适配器用于序列化和反序列化Duration对象
class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final int typeId = 1; // 确保这个ID在项目中是唯一的
  
  @override
  Duration read(BinaryReader reader) {
    // 读取微秒数并创建Duration对象
    final microseconds = reader.readInt();
    return Duration(microseconds: microseconds);
  }
  
  @override
  void write(BinaryWriter writer, Duration obj) {
    // 将Duration对象的微秒数写入
    writer.writeInt(obj.inMicroseconds);
  }
}
