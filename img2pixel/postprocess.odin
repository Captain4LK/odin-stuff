package main

import "core:log"

import "../prof"

image32_postprocess :: proc(img: ^Image32, color_inline: [4]u8, color_outline: [4]u8) -> ^Image32
{
   prof.SCOPED_EVENT(#procedure)
   out: ^Image32 = image32_dup(img)

   for y in 0..<img.height
   {
      for x in 0..<img.width
      {
         if color_inline[3] != 0
         {
            empty: i32 = 0
            if image32_get(img, x, y - 1, {0, 0, 0, 255})[3] == 0 do empty += 1
            if image32_get(img, x, y + 1, {0, 0, 0, 255})[3] == 0 do empty += 1
            if image32_get(img, x - 1, y, {0, 0, 0, 255})[3] == 0 do empty += 1
            if image32_get(img, x + 1, y, {0, 0, 0, 255})[3] == 0 do empty += 1

            if empty != 0
            {
               out.data[y * img.width + x] = color_inline
            }
         }
         if color_outline[3] != 0
         {
            empty: i32 = 0
            if image32_get(img, x, y - 1, {0, 0, 0, 255})[3] != 0 do empty += 1
            if image32_get(img, x, y + 1, {0, 0, 0, 255})[3] != 0 do empty += 1
            if image32_get(img, x - 1, y, {0, 0, 0, 255})[3] != 0 do empty += 1
            if image32_get(img, x + 1, y, {0, 0, 0, 255})[3] != 0 do empty += 1

            if empty != 0
            {
               out.data[y * img.width + x] = color_outline
            }
         }
      }
   }

   return out
}
