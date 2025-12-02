package main

import "core:log"
import "core:math"

import "../prof"

image64_hscb :: proc(img: ^Image64, hue, saturation, contrast, brightness: f32) #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   if img == nil do return

   t: f32 = (1 - contrast) / 2

   sr: f32 = (1 - saturation) * 0.3086
   sg: f32 = (1 - saturation) * 0.6094
   sb: f32 = (1 - saturation) * 0.0820

   rr: f32 = contrast * (sr + saturation)
   rg: f32 = contrast * sr
   rb: f32 = contrast * sr

   gr: f32 = contrast * sg
   gg: f32 = contrast * (sg + saturation)
   gb: f32 = contrast * sg

   br: f32 = contrast * sb
   bg: f32 = contrast * sb
   bb: f32 = contrast * (sb + saturation)

   wr: f32 = (t + brightness) * f32(max(i16))
   wg: f32 = (t + brightness) * f32(max(i16))
   wb: f32 = (t + brightness) * f32(max(i16))

   for y in 0..<img.height
   {
      for x in 0..<img.width
      {
         pin: [4]u16 = img.data[y * img.width + x]
         p: [4]u16 = pin

         if hue != 0
         {
            pin = hue_adjust(pin, hue)
         }

         fr: f32 = f32(pin[0])
         fg: f32 = f32(pin[1])
         fb: f32 = f32(pin[2])

         p[0] = max(0, min(u16(max(i16)), u16(rr * fr + gr * fg + br * fb + wr)))
         p[1] = max(0, min(u16(max(i16)), u16(rg * fr + gg * fg + bg * fb + wg)))
         p[2] = max(0, min(u16(max(i16)), u16(rb * fr + gb * fg + bb * fb + wb)))

         img.data[y * img.width + x] = p
      }
   }
}

@(private="file")
hue_adjust :: proc(colour: [4]u16, hue: f32) -> [4]u16
{
   h, s, v: f32

   {
      r: f32 = f32(colour[0]) / f32(max(i16))
      g: f32 = f32(colour[1]) / f32(max(i16))
      b: f32 = f32(colour[2]) / f32(max(i16))
      cmax: f32 = max(r, g, b)
      cmin: f32 = min(r, g, b)
      diff: f32 = cmax - cmin

      if cmax == cmin do h = 0
      else if cmax == r do h = math.mod(((g - b) / diff), 6)
      else if cmax== g do h = (b - r) / diff + 2
      else if cmax == b do h = (r - g) / diff + 4

      h *= 60
      s = diff / cmax
      v = cmax
   }

   h += hue

   r, g, b: f32

   for h < 0 do h += 360
   for h > 360 do h -= 360

   c: f32 = v * s
   x: f32 = c * (1 - abs(math.mod(h / 60, 2) - 1))
   m : f32 = v - c

   if h >= 0 && h < 60
   {
      r = c + m
      g = x + m
      b = m
   }
   else if h >= 60 && h < 120
   {
      r = x + m
      g = c + m
      b = m
   }
   else if h >= 120 && h < 180
   {
      r = m
      g = c + m
      b = x + m
   }
   else if h >= 180 && h < 240
   {
      r = m
      g = x + m
      b = c + m
   }
   else if h >= 240 && h < 300
   {
      r = x + m
      g = m
      b = c + m
   }
   else if h >= 300 && h < 360
   {
      r = c + m
      g = m
      b = x + m
   }

   p: [4]u16
   p[0] = max(0, min(u16(max(i16)), u16(32767 * r)))
   p[1] = max(0, min(u16(max(i16)), u16(32767 * g)))
   p[2] = max(0, min(u16(max(i16)), u16(32767 * b)))
   p[3] = colour[3]

   return p
}
