// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_song.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalSongAdapter extends TypeAdapter<LocalSong> {
  @override
  final int typeId = 0;

  @override
  LocalSong read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalSong(
      id: fields[0] as String,
      title: fields[1] as String,
      artist: fields[2] as String,
      album: fields[3] as String,
      albumArt: fields[4] as String?,
      filePath: fields[5] as String,
      duration: fields[6] as Duration,
      lastModified: fields[7] as DateTime,
      fileSize: fields[8] as int,
      lyric: fields[9] as String?,
      onlineId: fields[10] as String?,
      source: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalSong obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.artist)
      ..writeByte(3)
      ..write(obj.album)
      ..writeByte(4)
      ..write(obj.albumArt)
      ..writeByte(5)
      ..write(obj.filePath)
      ..writeByte(6)
      ..write(obj.duration)
      ..writeByte(7)
      ..write(obj.lastModified)
      ..writeByte(8)
      ..write(obj.fileSize)
      ..writeByte(9)
      ..write(obj.lyric)
      ..writeByte(10)
      ..write(obj.onlineId)
      ..writeByte(11)
      ..write(obj.source);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalSongAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
