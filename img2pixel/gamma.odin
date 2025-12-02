package main

import "core:log"
import "core:math"

import "../prof"

image64_gamma :: proc(img: ^Image64, gamma: f32) #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   for y in 0..<img.height
   {
      for x in 0..<img.width
      {
         p: [4]u16 = img.data[y * img.width + x]

         fr: f32 = f32(p[0])
         fg: f32 = f32(p[1])
         fb: f32 = f32(p[2])

         p[0] = max(0, min(u16(max(i16)), u16(32767 * math.pow(fr / 32767, gamma))))
         p[1] = max(0, min(u16(max(i16)), u16(32767 * math.pow(fg / 32767, gamma))))
         p[2] = max(0, min(u16(max(i16)), u16(32767 * math.pow(fb / 32767, gamma))))

         img.data[y * img.width + x] = p
      }
   }
}
