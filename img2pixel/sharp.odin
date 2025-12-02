package main

import "core:log"

import "../prof"


image64_sharpen :: proc(img: ^Image64, amount: f32) #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   if amount < 1e-2 do return

   blur: ^Image64 = image64_dup(img)
   defer free(blur)
   image64_blur(blur, 1)

   amount_fixed: i32 = i32(amount * 256)

   for y in 0..<img.height
   {
      for x in 0..<img.width
      {
         pi: [4]u16 = img.data[y * img.width + x]
         pb: [4]u16 = blur.data[y * img.width + x]
         p: [4]u16 = {0, 0, 0, 255}

         for i in 0..<3
         {
            c: i32 = i32(pi[i])
            cb: i32 = i32(pb[i])
            p[i] = max(0, min(u16(max(i16)), u16(c + ((c - cb) * amount_fixed) / 256)))
         }
         
         img.data[y * img.width + x] = p
      }
   }
}
