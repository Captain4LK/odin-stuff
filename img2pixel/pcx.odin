package main

import "core:fmt"
import "../rw"

pcx_save :: proc(img: ^Image8, path: string) #no_bounds_check
{
   if img == nil || len(path) <= 0
   {
      return
   }

   rw_out: rw.Rw
   rw.init_path(&rw_out, path, {.Create, .Write, .Truncate})

   // Header
   rw.write_u8(&rw_out, 0x0a)
   rw.write_u8(&rw_out, 0x05)
   rw.write_u8(&rw_out, 0x01)
   rw.write_u8(&rw_out, 0x08)
   rw.write_u16(&rw_out, 0x0000)
   rw.write_u16(&rw_out, 0x0000)
   rw.write_u16(&rw_out, u16(img.width - 1))
   rw.write_u16(&rw_out, u16(img.height - 1))
   rw.write_u16(&rw_out, 0x0048)
   rw.write_u16(&rw_out, 0x0048)
   for i in 0..<48
   {
      rw.write_u8(&rw_out, 0x00)
   }
   rw.write_u8(&rw_out, 0x00)
   rw.write_u8(&rw_out, 0x01)
   rw.write_u16(&rw_out, u16(img.width))
   rw.write_u16(&rw_out, 0x0001)
   rw.write_u16(&rw_out, 0x0000)
   rw.write_u16(&rw_out, 0x0000)
   for i in 0..<54
   {
      rw.write_u8(&rw_out, 0x00)
   }

   // RLE encode
   for y in 0..<img.height
   {
      current: u8 = img.data[y * img.width]
      length: i32 = 1
      for x in 1..<img.width
      {
         if img.data[y * img.width + x] == current
         {
            length += 1
         }
         else
         {
            for length > 0
            {
               if length > 1 || current > 191
               {
                  part_len: i32 = min(length, 63)
                  rw.write_u8(&rw_out, u8(part_len | 0xc0))
                  rw.write_u8(&rw_out, current)
                  length -= part_len
               }
               else
               {
                  rw.write_u8(&rw_out, current)
                  length -= 1
               }
            }

            length = 1
            current = img.data[y * img.width + x]
         }

         for length > 0
         {
            if length > 1 || current > 191
            {
               part_len: i32 = min(length, 63)
               rw.write_u8(&rw_out, u8(part_len | 0xc0))
               rw.write_u8(&rw_out, current)
               length -= part_len
            }
            else
            {
               rw.write_u8(&rw_out, current)
               length -= 1
            }
         }
      }
   }

   // Palette
   rw.write_u8(&rw_out, 0x0c)
   for i in 0..<256
   {
      rw.write_u8(&rw_out, img.palette[i].r)
      rw.write_u8(&rw_out, img.palette[i].g)
      rw.write_u8(&rw_out, img.palette[i].b)
   }

   rw.close(&rw_out)
}
