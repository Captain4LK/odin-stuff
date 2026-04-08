package rw

import "core:os"
import "core:bufio"
import "core:io"
import "core:fmt"

FileFlag :: enum
{
   Read,
   Write,
   Append,
   Create,
   Truncate,
}

ErrorType :: enum
{
   UnsupportedOperation,
   Unknown,
}

Error :: union
{
   ErrorType,
}

FileFlags :: distinct bit_set[FileFlag; u32]

SEEK_CUR :: 1
SEEK_END :: 2
SEEK_SET :: 0

Endian :: enum
{
   LittleEndian,
   BigEndian,
}

File :: struct
{
   fp: ^os.File,
   stream: io.Stream,
   writer: bufio.Writer,
   reader: bufio.Reader,
   has_reader: bool,
   has_writer: bool,
   pos: i64,
}

ConstantMemory :: struct
{
   data: []u8,
   pos: i64,
}

Memory :: struct
{
   data: []u8,
   pos: i64,
}

Rw :: struct
{
   endian: Endian,

   as: union
   {
      File,
      ConstantMemory,
      Memory,
   }
}

init_path :: proc(rw: ^Rw, path: string, mode: FileFlags)
{
   rw.as = nil
   rw.endian = .LittleEndian

   file_flags: os.File_Flags
   if .Read in mode do file_flags += {.Read}
   if .Write in mode do file_flags += {.Write}
   if .Append in mode do file_flags += {.Append}
   if .Create in mode do file_flags += {.Create}
   if .Truncate in mode do file_flags += {.Trunc}
   fp, err := os.open(path, file_flags)
   if err != nil do return

   file: File
   file.fp = fp
   file.pos = 0
   file.stream = os.to_stream(file.fp)

   if .Read in mode
   {
      file.has_reader = true
      bufio.reader_init(&file.reader, file.stream)
   }
   if .Write in mode
   {
      file.has_writer = true
      bufio.writer_init(&file.writer, file.stream)
   }

   rw.as = file
}

init_const_memory :: proc(rw: ^Rw, mem: []u8)
{
   rw.as = nil
   rw.endian = .LittleEndian

   cmem: ConstantMemory
   cmem.data = mem
   cmem.pos = 0

   rw.as = cmem
}

init_memory :: proc(rw: ^Rw, mem: []u8)
{
   rw.as = nil
   rw.endian = .LittleEndian

   rwmem: Memory
   rwmem.data = mem
   rwmem.pos = 0

   rw.as = rwmem
}

close :: proc(rw: ^Rw) -> Error
{
   switch &f in rw.as
   {
   case File:
      flush(rw)
      if f.has_reader do bufio.reader_destroy(&f.reader)
      if f.has_writer do bufio.writer_destroy(&f.writer)
      io.close(f.stream)

      return nil
   case ConstantMemory:
      return .UnsupportedOperation
   case Memory:
      return .UnsupportedOperation
   }
   return nil
}

valid :: proc(rw: ^Rw) -> bool
{
   return rw.as != nil
}

endian_set :: proc(rw: ^Rw, endian: Endian)
{
   rw.endian = endian
}

flush :: proc(rw: ^Rw) -> Error
{
   switch &f in rw.as
   {
   case File:
      if f.has_writer
      {
         err := bufio.writer_flush(&f.writer)
         if err != nil do return .Unknown
      }

      return nil
   case ConstantMemory:
      return nil
   case Memory:
      return nil
   }

   return nil
}

seek :: proc(rw: ^Rw, offset: i64, whence: int)
{
   switch &f in rw.as
   {
   case File:
            err: io.Error
      flush(rw)
      f.pos, err = io.seek(f.stream,offset,io.Seek_From(whence))
      if f.has_writer do bufio.writer_reset(&f.writer, f.stream)
      if f.has_reader do bufio.reader_reset(&f.reader, f.stream)
   case ConstantMemory:
      if whence == SEEK_SET do f.pos = offset
      else if whence == SEEK_CUR do f.pos += offset
      else if whence == SEEK_END do f.pos = i64(len(f.data) - 1 + int(offset))
   case Memory:
      if whence == SEEK_SET do f.pos = offset
      else if whence == SEEK_CUR do f.pos += offset
      else if whence == SEEK_END do f.pos = i64(len(f.data) - 1 + int(offset))
   }
}

size :: proc(rw: ^Rw) -> (size: i64)
{
   size = 0
   switch f in rw.as
   {
   case File:
      err: os.Error
      size, err = os.file_size(f.fp)
   case ConstantMemory:
      size = i64(len(f.data))
   case Memory:
      size = f.pos
   }

   return size
}

tell :: proc(rw: ^Rw) -> (pos: i64)
{
   pos = 0
   switch f in rw.as
   {
   case File:
      pos = f.pos
   case ConstantMemory:
      pos = f.pos
   case Memory:
      pos = f.pos
   }

   return pos
}

eof :: proc(rw: ^Rw) -> (eof: bool)
{
   eof = true
   switch f in rw.as
   {
   case File:
      eof = f.pos >= size(rw)
   case ConstantMemory:
      eof = f.pos >= size(rw)
   case Memory:
      eof = f.pos >= size(rw)
   }

   return eof
}

read :: proc(rw: ^Rw, data: []u8) -> (total_read: int)
{
   total_read = 0

   switch &f in rw.as
   {
   case File:
      err: io.Error = .None
      for err == .None && total_read < len(data)
      {
         read: int
         read, err = bufio.reader_read(&f.reader, data)
         total_read += read
      }
      f.pos += i64(total_read)
   case ConstantMemory:
      total_read = min(len(data),len(f.data) - int(f.pos))
      copy(data[0:total_read],f.data[f.pos:int(f.pos) + total_read])
      f.pos += i64(total_read)
   case Memory:
   }

   return total_read
}

write :: proc(rw: ^Rw, data: []u8) -> (total_writ: int)
{
   total_writ = 0

   switch &f in rw.as
   {
   case File:
      err: io.Error
      total_writ, err = bufio.writer_write(&f.writer,data)
      f.pos += i64(total_writ)
   case ConstantMemory:
   case Memory:
      total_writ = min(len(data), len(f.data) - int(f.pos))
      copy(f.data[f.pos:],data)
      f.pos += i64(total_writ)
   }

   return total_writ
}


write_u8 :: proc(rw: ^Rw, val: u8) -> (total_writ: int)
{
   return write(rw,[]u8{val})
}

write_i8 :: proc(rw: ^Rw, val: i8) -> (total_writ: int)
{
   return write_u8(rw, transmute(u8)val)
}

write_u16 :: proc(rw: ^Rw, val: u16) -> (total_writ: int)
{
   total_writ = 0

   if rw.endian == .LittleEndian
   {
      total_writ += write_u8(rw,u8(val & 0xff))
      total_writ += write_u8(rw,u8((val >> 8) & 0xff))
   }
   else if rw.endian == .BigEndian
   {
      total_writ += write_u8(rw,u8((val >> 8) & 0xff))
      total_writ += write_u8(rw,u8(val & 0xff))
   }

   return total_writ
}

write_i16 :: proc(rw: ^Rw, val: i16) -> (total_writ: int)
{
   return write_u16(rw, transmute(u16)val)
}

write_u32 :: proc(rw: ^Rw, val: u32) -> (total_writ: int)
{
   total_writ = 0

   if rw.endian == .LittleEndian
   {
      total_writ += write_u8(rw,u8(val & 0xff))
      total_writ += write_u8(rw,u8((val >> 8) & 0xff))
      total_writ += write_u8(rw,u8((val >> 16) & 0xff))
      total_writ += write_u8(rw,u8((val >> 24) & 0xff))
   }
   else if rw.endian == .BigEndian
   {
      total_writ += write_u8(rw,u8((val >> 24) & 0xff))
      total_writ += write_u8(rw,u8((val >> 16) & 0xff))
      total_writ += write_u8(rw,u8((val >> 8) & 0xff))
      total_writ += write_u8(rw,u8(val & 0xff))
   }

   return total_writ
}

write_i32 :: proc(rw: ^Rw, val: i32) -> (total_writ: int)
{
   return write_u32(rw,transmute(u32)val)
}

write_u64 :: proc(rw: ^Rw, val: u64) -> (total_writ: int)
{
   total_writ = 0

   if rw.endian == .LittleEndian
   {
      total_writ += write_u8(rw,u8(val & 0xff))
      total_writ += write_u8(rw,u8((val >> 8) & 0xff))
      total_writ += write_u8(rw,u8((val >> 16) & 0xff))
      total_writ += write_u8(rw,u8((val >> 24) & 0xff))
      total_writ += write_u8(rw,u8((val >> 32) & 0xff))
      total_writ += write_u8(rw,u8((val >> 40) & 0xff))
      total_writ += write_u8(rw,u8((val >> 48) & 0xff))
      total_writ += write_u8(rw,u8((val >> 56) & 0xff))
   }
   else if rw.endian == .BigEndian
   {
      total_writ += write_u8(rw,u8((val >> 56) & 0xff))
      total_writ += write_u8(rw,u8((val >> 48) & 0xff))
      total_writ += write_u8(rw,u8((val >> 40) & 0xff))
      total_writ += write_u8(rw,u8((val >> 32) & 0xff))
      total_writ += write_u8(rw,u8((val >> 24) & 0xff))
      total_writ += write_u8(rw,u8((val >> 16) & 0xff))
      total_writ += write_u8(rw,u8((val >> 8) & 0xff))
      total_writ += write_u8(rw,u8(val & 0xff))
   }

   return total_writ
}

write_i64 :: proc(rw: ^Rw, val: i64) -> (total_writ: int)
{
   return write_u64(rw,transmute(u64)val)
}

read_u8 :: proc(rw: ^Rw) -> u8
{
   total_read: int = 0
   slice: [1]u8 = {0}

   total_read = read(rw,slice[:])

   return slice[0]
}

read_i8 :: proc(rw: ^Rw) -> i8
{
   return transmute(i8)read_u8(rw)
}

read_u16 :: proc(rw: ^Rw) -> u16
{
   value: u16 = 0

   if rw.endian == .LittleEndian
   {
      for i := 0; i < 2; i += 1 
      {
         b := read_u8(rw)
         value += u16(b) << u16(i * 8)
      }
   }
   else if rw.endian == .BigEndian
   {
      for i := 0; i < 2; i += 1 
      {
         b := read_u8(rw)
         value += u16(b) << u16((1 - i) * 8)
      }
   }

   return value
}

read_i16 :: proc(rw: ^Rw) -> i16
{
   return transmute(i16)read_u16(rw)
}

read_u32 :: proc(rw: ^Rw) -> u32
{
   value: u32 = 0

   if rw.endian == .LittleEndian
   {
      for i := 0; i < 4; i += 1 
      {
         b := read_u8(rw)
         value += u32(b) << u32(i * 8)
      }
   }
   else if rw.endian == .BigEndian
   {
      for i := 0; i < 4; i += 1 
      {
         b := read_u8(rw)
         value += u32(b) << u32((3 - i) * 8)
      }
   }

   return value
}

read_i32 :: proc(rw: ^Rw) -> i32
{
   val := read_u32(rw)
   return transmute(i32)val
}

read_u64 :: proc(rw: ^Rw) -> u64
{
   value: u64 = 0

   if rw.endian == .LittleEndian
   {
      for i := 0; i < 8; i += 1 
      {
         b := read_u8(rw)
         value += u64(b) << u64(i * 8)
      }
   }
   else if rw.endian == .BigEndian
   {
      for i := 0; i < 8; i += 1 
      {
         b := read_u8(rw)
         value += u64(b) << u64((7 - i) * 8)
      }
   }

   return value
}

read_i64 :: proc(rw: ^Rw) -> i64
{
   val := read_u64(rw)

   return transmute(i64)val
}
