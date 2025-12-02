package main

import "core:log"

import "../prof"

image64_tint :: proc(img: ^Image64, tint: [3]u8) #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   if tint == {255, 255, 255} do return

   t: [4]u64
   t[0] = u64(tint[0])
   t[1] = u64(tint[1])
   t[2] = u64(tint[2])
   t[3] = 255

   for y in 0..<img.height
   {
      for x in 0..<img.width
      {
         p: [4]u16 = img.data[y * img.width + x]
         p64: [4]u64
         p64[0] = u64(p[0])
         p64[1] = u64(p[1])
         p64[2] = u64(p[2])
         p64[3] = u64(p[3])
         p64 = (p64 * t) / 255

         p[0] = u16(p64[0])
         p[1] = u16(p64[1])
         p[2] = u16(p64[2])
         p[3] = u16(p64[3])
         img.data[y * img.width + x] = p
      }
   }
}
