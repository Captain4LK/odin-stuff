package main

import "core:log"

import "../prof"

image64_blur :: proc(img: ^Image64, sz: f32) #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   if img == nil do return
   if sz <= 0.01 do return

   //Can't blur images this small
   if img.width <= i32(sz) || img.height <= i32(sz) do return

   // Horizontal
   {
      buffer0 := make([][4]u16, img.width)
      buffer1 := make([][4]u16, img.width)
      defer delete(buffer0)
      defer delete(buffer1)

      for y in 0..<img.height
      {
         boxblur_line(img.data[y * img.width : y * img.width + img.width], buffer0[:], sz)
         boxblur_line(buffer0[:], buffer1[:], sz)
         boxblur_line(buffer1[:], img.data[y * img.width : y * img.width + img.width], sz)
      }
   }

   // Vertical
   {
      buffer0 := make([][4]u16, img.width)
      buffer1 := make([][4]u16, img.width)
      defer delete(buffer0)
      defer delete(buffer1)

      for x in 0..<img.width
      {
         for y in 0..<img.height
         {
            buffer0[y] = img.data[y * img.width + x]
         }

         boxblur_line(buffer0[:], buffer1[:], sz)
         boxblur_line(buffer1[:], buffer0[:], sz)
         boxblur_line(buffer0[:], buffer1[:], sz)

         for y in 0..<img.height
         {
            img.data[y * img.width + x] = buffer0[y]
         }
      }
   }
}

@(private="file")
boxblur_line :: proc(src: [][4]u16, dst: [][4]u16, rad: f32) #no_bounds_check
{
   log.assertf(len(src) == len(dst), "length mismatch")

   r: i32 = i32(rad)
   alpha: i32 = i32(rad * 64) & 63
   alpha1: i32 = 64 - alpha
   s2: i32 = -((r + 1) / 2) * 4
   d: i32 = 0

   amp: i32 = (65536 * 64) / max(1, (2 * r + 1) * 64 + alpha * 2)
   sum: [4]i32

   sum[0] += i32(src[0][0]) * (alpha + alpha1) * r
   sum[1] += i32(src[0][1]) * (alpha + alpha1) * r
   sum[2] += i32(src[0][2]) * (alpha + alpha1) * r
   sum[3] += i32(src[0][3]) * (alpha + alpha1) * r

   sum[0] += i32(src[0][0]) * alpha
   sum[1] += i32(src[0][1]) * alpha
   sum[2] += i32(src[0][2]) * alpha
   sum[3] += i32(src[0][3]) * alpha
   sum[0] += i32(src[0][0]) * alpha
   sum[1] += i32(src[0][1]) * alpha
   sum[2] += i32(src[0][2]) * alpha
   sum[3] += i32(src[0][3]) * alpha
   s1: i32 = 0

   for i in 0..<r
   {
      sum[0] += i32(src[0][0]) * alpha1 + i32(src[s1 + 1][0]) * alpha
      sum[1] += i32(src[0][1]) * alpha1 + i32(src[s1 + 1][1]) * alpha
      sum[2] += i32(src[0][2]) * alpha1 + i32(src[s1 + 1][2]) * alpha
      sum[3] += i32(src[0][3]) * alpha1 + i32(src[s1 + 1][3]) * alpha
      s1 += 1
   }

   for i in 0..<r+1
   {
      sum[0] += i32(src[s1][0]) * alpha1 + i32(src[s1 + 1][0]) * alpha
      sum[1] += i32(src[s1][1]) * alpha1 + i32(src[s1 + 1][1]) * alpha
      sum[2] += i32(src[s1][2]) * alpha1 + i32(src[s1 + 1][2]) * alpha
      sum[3] += i32(src[s1][3]) * alpha1 + i32(src[s1 + 1][3]) * alpha
      s1 += 1

      cr: u16 = u16((u64(sum[0]) * u64(amp)) / (65536 * 64))
      cg: u16 = u16((u64(sum[1]) * u64(amp)) / (65536 * 64))
      cb: u16 = u16((u64(sum[2]) * u64(amp)) / (65536 * 64))
      ca: u16 = u16((u64(sum[3]) * u64(amp)) / (65536 * 64))
      dst[d][0] = cr
      dst[d][1] = cg
      dst[d][2] = cb
      dst[d][3] = ca
      d += 1

      sum[0] -= i32(src[0][0]) * (alpha + alpha1)
      sum[1] -= i32(src[0][1]) * (alpha + alpha1)
      sum[2] -= i32(src[0][2]) * (alpha + alpha1)
      sum[3] -= i32(src[0][3]) * (alpha + alpha1)
      s2 += 1
   }
   s2 = 0

   for i in 0 ..< i32(len(src)) - 2 * r - 2
   {
      sum[0] += i32(src[s1][0]) * alpha1 + i32(src[s1 + 1][0]) * alpha
      sum[1] += i32(src[s1][1]) * alpha1 + i32(src[s1 + 1][1]) * alpha
      sum[2] += i32(src[s1][2]) * alpha1 + i32(src[s1 + 1][2]) * alpha
      sum[3] += i32(src[s1][3]) * alpha1 + i32(src[s1 + 1][3]) * alpha
      s1 += 1

      cr: u16 = u16((u64(sum[0]) * u64(amp)) / (65536 * 64))
      cg: u16 = u16((u64(sum[1]) * u64(amp)) / (65536 * 64))
      cb: u16 = u16((u64(sum[2]) * u64(amp)) / (65536 * 64))
      ca: u16 = u16((u64(sum[3]) * u64(amp)) / (65536 * 64))
      dst[d][0] = cr
      dst[d][1] = cg
      dst[d][2] = cb
      dst[d][3] = ca
      d += 1

      sum[0] -= i32(src[s2][0]) * alpha + i32(src[s2 + 1][0]) * alpha1
      sum[1] -= i32(src[s2][1]) * alpha + i32(src[s2 + 1][1]) * alpha1
      sum[2] -= i32(src[s2][2]) * alpha + i32(src[s2 + 1][2]) * alpha1
      sum[3] -= i32(src[s2][3]) * alpha + i32(src[s2 + 1][3]) * alpha1
      s2 += 1
   }

   for i in 0..<r+1
   {
      sum[0] += i32(src[len(src) - 1][0]) * (alpha1 + alpha)
      sum[1] += i32(src[len(src) - 1][1]) * (alpha1 + alpha)
      sum[2] += i32(src[len(src) - 1][2]) * (alpha1 + alpha)
      sum[3] += i32(src[len(src) - 1][3]) * (alpha1 + alpha)

      cr: u16 = u16((u64(sum[0]) * u64(amp)) / (65536 * 64))
      cg: u16 = u16((u64(sum[1]) * u64(amp)) / (65536 * 64))
      cb: u16 = u16((u64(sum[2]) * u64(amp)) / (65536 * 64))
      ca: u16 = u16((u64(sum[3]) * u64(amp)) / (65536 * 64))
      dst[d][0] = cr
      dst[d][1] = cg
      dst[d][2] = cb
      dst[d][3] = ca
      d += 1

      sum[0] -= i32(src[s2][0]) * alpha + i32(src[s2 + 1][0]) * alpha1
      sum[1] -= i32(src[s2][1]) * alpha + i32(src[s2 + 1][1]) * alpha1
      sum[2] -= i32(src[s2][2]) * alpha + i32(src[s2 + 1][2]) * alpha1
      sum[3] -= i32(src[s2][3]) * alpha + i32(src[s2 + 1][3]) * alpha1
      s2 += 1
   }
   /*
   for(int i = 0;i<r+1;i++)
   {
      sum_r+=src[(width-1)*4]*(alpha1+alpha);
      sum_g+=src[(width-1)*4+1]*(alpha1+alpha);
      sum_b+=src[(width-1)*4+2]*(alpha1+alpha);
      sum_a+=src[(width-1)*4+3]*(alpha1+alpha);

      uint16_t cr = (uint16_t)(((uint64_t)sum_r*amp)/(65536*64));
      uint16_t cg = (uint16_t)(((uint64_t)sum_g*amp)/(65536*64));
      uint16_t cb = (uint16_t)(((uint64_t)sum_b*amp)/(65536*64));
      uint16_t ca = (uint16_t)(((uint64_t)sum_a*amp)/(65536*64));
      dst[d] = cr;
      dst[d+1] = cg;
      dst[d+2] = cb;
      dst[d+3] = ca;
      d+=4;

      sum_r-=src[s2]*alpha+src[s2+4]*alpha1;
      sum_g-=src[s2+1]*alpha+src[s2+5]*alpha1;
      sum_b-=src[s2+2]*alpha+src[s2+6]*alpha1;
      sum_a-=src[s2+3]*alpha+src[s2+7]*alpha1;
      s2+=4;
   }
   */
}
