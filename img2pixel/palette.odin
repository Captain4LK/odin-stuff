package main

import "core:log"
import "core:strings"
import "core:bytes"
import "core:mem"
import "core:strconv"
import "core:path/filepath"
import "core:math"
import "core:os"
import "core:io"
import "core:fmt"
import "core:image/png"
import "core:image/qoi"
import "core:image/tga"
import "core:image/bmp"
import "core:image/jpeg"
import "core:image/netpbm"
import "core:image"

import "../prof"

@(private="file")
char_to_u8 :: proc(ch: u8) -> u8
{
   if ch >= '0' && ch <= '9' do return ch - '0'
   if ch >= 'a' && ch <= 'f' do return ch - 'a' + 10
   if ch >= 'A' && ch <= 'F' do return ch - 'A' + 10

   return 0
}

palette_load :: proc(path: string, colours: ^[256][4]u8, colour_count: ^i32)
{
   prof.SCOPED_EVENT(#procedure)

   if len(path) == 0 do return

   ext: string = filepath.ext(path)
   ext_lower: string = strings.to_lower(ext)
   defer delete(ext_lower)

   data, ok := os.read_entire_file_from_path(path, context.allocator)
   defer delete(data)

   it := string(data)

   if strings.compare(ext_lower, ".hex") == 0
   {
      line_idx: i32 = 0
      for line_full in strings.split_lines_iterator(&it)
      {
         defer line_idx += 1
         if len(line_full) < 6 do continue

         colours[line_idx][0] = char_to_u8(line_full[0]) * 16 + char_to_u8(line_full[1])
         colours[line_idx][1] = char_to_u8(line_full[2]) * 16 + char_to_u8(line_full[3])
         colours[line_idx][2] = char_to_u8(line_full[4]) * 16 + char_to_u8(line_full[5])
         colours[line_idx][3] = 255
      }

      colour_count^ = line_idx
   }
   else if strings.compare(ext_lower, ".pal") == 0
   {
      line_idx: int = 0
      colour_idx: i32 = 0
      for line_full in strings.split_lines_iterator(&it)
      {
         defer line_idx += 1

         if line_idx <= 0 || len(line_full) < 1
         {
            continue
         }

         component: int = 0
         colour: [4]u8
         colour[3] = 255
         line_full := line_full
         for part in strings.split_multi_iterate(&line_full, {" "})
         {
            c, ok := strconv.parse_uint(part)
            if !ok do continue
            colour[component] = u8(c)

            component += 1
            if component >= 3 do break
         }

         colours[colour_idx] = colour
         colour_idx += 1
         if colour_idx >= 256 do break
      }

      colour_count^ = colour_idx
   }
   else if strings.compare(ext_lower, ".gpl") == 0
   {
      line_idx: int = 0
      colour_idx: i32 = 0
      for line_full in strings.split_lines_iterator(&it)
      {
         defer line_idx += 1

         if line_idx <= 0 do continue
         if len(line_full) < 1 do continue
         if line_full[0] == '#' do continue

         component: int = 0
         colour: [4]u8
         colour[3] = 255
         line_full := line_full
         for part in strings.split_multi_iterate(&line_full, {" ", "\t"})
         {

            c, ok := strconv.parse_uint(part)
            if !ok do continue
            colour[component] = u8(c)

            component += 1
            if component >= 3 do break
         }

         colours[colour_idx] = colour
         colour_idx += 1
         if colour_idx >= 256 do break
      }

      colour_count^ = colour_idx
   }
   else // Assume png
   {
      img: ^image.Image
      err: image.Error
      img, err = image.load_from_file(path)
      defer image.destroy(img)
      if err != nil
      {
         log.errorf("Failed to load image \"%v\": %v", path, err)
         return
      }
      image.alpha_add_if_missing(img)
      
      data: []u8 = bytes.buffer_to_bytes(&img.pixels)
      img32: ^Image32 = image32_new(i32(img.width), i32(img.height))
      defer free(img32)
      #no_bounds_check {
         mem.copy(&img32.data[0], raw_data(data), len(data))
      }

      colour_count^ = min(256, img32.width * img32.height)
      for i in 0..<colour_count^
      {
         #no_bounds_check colours[i] = img32.data[i]
      }
   }
}

palette_save:: proc(path: string, colours: [256][4]u8, colour_count: i32)
{
   prof.SCOPED_EVENT(#procedure)

   if len(path) == 0 do return

   ext: string = filepath.ext(path)
   ext_lower: string = strings.to_lower(ext)
   defer delete(ext_lower)

   fp, err := os.create(path)
   if err != nil
   {
      return
   }
   defer os.close(fp)
   stream: io.Stream = os.to_stream(fp)

   if strings.compare(ext_lower, ".hex") == 0
   {
      for i in 0..<colour_count
      {
         fmt.wprintf(stream, "%02x%02x%02x\n", colours[i].r, colours[i].g, colours[i].b)
      }
   }
   else if strings.compare(ext_lower, ".gpl") == 0
   {
      fmt.wprintf(stream, "GIMP Palette\n#Colors: %v\n", colour_count)
      for i in 0..<colour_count
      {
         fmt.wprintf(stream, "%v\t%v\t%v\t%02x%02x%02x\n", colours[i].r, colours[i].g, colours[i].b,
            colours[i].r, colours[i].g, colours[i].b)
      }
   }
   else
   {
      fmt.wprintf(stream, "JASC-PAL\n0100\n%v\n", colour_count)
      for i in 0..<colour_count
      {
         fmt.wprintf(stream, "%v %v %v\n", colours[i].r, colours[i].g, colours[i].b)
      }
   }
}
