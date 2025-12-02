package main

import "core:log"
import "core:math"

import "../prof"

image64_sample :: proc(img: ^Image64, width: i32, height: i32, sample_mode: i32, x_off: f32, y_off: f32) -> ^Image64
{
   prof.SCOPED_EVENT(#procedure)

   if img == nil
   {
      return nil
   }

   width := max(1, width)
   height := max(1, height)

   switch sample_mode
   {
   case 0:
      return sample_nearest(img, width, height, x_off, y_off)
   case 1:
      return sample_linear(img, width, height, x_off, y_off)
   case 2:
      return sample_bicubic(img, width, height, x_off, y_off)
   case 3:
      return sample_lanczos(img, width, height, x_off, y_off)
   case 4:
      return sample_cluster(img, width, height, x_off, y_off)
   }

   return nil
}

@(private="file")
sample_nearest :: proc(img: ^Image64, width: i32, height: i32, x_off: f32, y_off: f32) -> ^Image64 #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   out: ^Image64 = image64_new(width, height)

   w: f32 = f32(img.width - 1) / f32(width)
   h: f32 = f32(img.height - 1) / f32(height)

   for y in 0..<height
   {
      for x in 0..<width
      {
         dx: f32 = f32(x) + x_off + 0.5
         dy: f32 = f32(y) + y_off + 0.5

         ix: i32 = max(0, min(img.width - 1, i32(math.round(dx * w))))
         iy: i32 = max(0, min(img.height - 1, i32(math.round(dy * h))))
         out.data[y * width + x] = img.data[iy * img.width + ix]
      }
   }

   return out
}

@(private="file")
blend_linear :: proc "contextless" (sx, sy, c0, c1, c2, c3: f32) -> f32
{
   t0: f32 = (1 - sx) * c0 + sx * c1
   t1: f32 = (1 - sx) * c2 + sx * c3
   return (1 - sy) * t0 + sy * t1
}

@(private="file")
sample_linear :: proc(img: ^Image64, width: i32, height: i32, x_off: f32, y_off: f32) -> ^Image64 #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   out: ^Image64 = image64_new(width, height)
   fw: f32 = f32(img.width - 1) / f32(width)
   fh: f32 = f32(img.height - 1) / f32(height)

   for y in 0..<height
   {
      for x in 0..<width
      {
         ix: i32 = i32((f32(x) + x_off + 0.5) * fw)
         iy: i32 = i32((f32(y) + y_off + 0.5) * fh)
         six: f32 = (f32(x) + x_off + 0.5) * fw - f32(ix)
         siy: f32 = (f32(y) + y_off + 0.5) * fh - f32(iy)

         p0: [4]u16 = image64_get(img, ix, iy, {0, 0, 0, 255})
         p1: [4]u16 = image64_get(img, ix + 1, iy, {0, 0, 0, 255})
         p2: [4]u16 = image64_get(img, ix, iy + 1, {0, 0, 0, 255})
         p3: [4]u16 = image64_get(img, ix + 1, iy + 1, {0, 0, 0, 255})

         c0: f32 = blend_linear(six, siy, f32(p0[0]), f32(p1[0]), f32(p2[0]), f32(p3[0]))
         c1: f32 = blend_linear(six, siy, f32(p0[1]), f32(p1[1]), f32(p2[1]), f32(p3[1]))
         c2: f32 = blend_linear(six, siy, f32(p0[2]), f32(p1[2]), f32(p2[2]), f32(p3[2]))
         c3: f32 = blend_linear(six, siy, f32(p0[3]), f32(p1[3]), f32(p2[3]), f32(p3[3]))

         p: [4]u16
         p[0] = max(0, min(u16(max(i16)), u16(c0)))
         p[1] = max(0, min(u16(max(i16)), u16(c1)))
         p[2] = max(0, min(u16(max(i16)), u16(c2)))
         p[3] = max(0, min(u16(max(i16)), u16(c3)))
         out.data[y * out.width + x] = p
      }
   }

   return out
}

@(private="file")
blend_bicubic :: proc "contextless" (c0, c1, c2, c3, t: f32) -> f32
{
   a0: f32 = -0.5 * c0 + 1.5 * c1 - 1.5 * c2 + 0.5 * c3
   a1: f32 = c0 - 2.5 * c1 + 2 * c2 - 0.5 * c3
   a2: f32 = -0.5 * c0 + 0.5 * c2
   a3: f32 = c1

   return a0 * t * t * t + a1 * t * t + a2 * t + a3
}

@(private="file")
sample_bicubic :: proc(img: ^Image64, width: i32, height: i32, x_off: f32, y_off: f32) -> ^Image64 #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   out: ^Image64 = image64_new(width, height)
   fw: f32 = f32(img.width - 1) / f32(width)
   fh: f32 = f32(img.height - 1) / f32(height)

   for y in 0..<height
   {
      for x in 0..<width
      {
         ix: i32 = i32((f32(x) + x_off + 0.5) * fw)
         iy: i32 = i32((f32(y) + y_off + 0.5) * fh)
         six: f32 = (f32(x) + x_off + 0.5) * fw - f32(ix)
         siy: f32 = (f32(y) + y_off + 0.5) * fh - f32(iy)

         p00: [4]u16 = image64_get(img, ix - 1, iy - 1, {0, 0, 0, 255})
         p01: [4]u16 = image64_get(img, ix, iy - 1, {0, 0, 0, 255})
         p02: [4]u16 = image64_get(img, ix + 1, iy - 1, {0, 0, 0, 255})
         p03: [4]u16 = image64_get(img, ix + 2, iy - 1, {0, 0, 0, 255})

         p10: [4]u16 = image64_get(img, ix - 1, iy, {0, 0, 0, 255})
         p11: [4]u16 = image64_get(img, ix, iy, {0, 0, 0, 255})
         p12: [4]u16 = image64_get(img, ix + 1, iy, {0, 0, 0, 255})
         p13: [4]u16 = image64_get(img, ix + 2, iy, {0, 0, 0, 255})

         p20: [4]u16 = image64_get(img, ix - 1, iy + 1, {0, 0, 0, 255})
         p21: [4]u16 = image64_get(img, ix, iy + 1, {0, 0, 0, 255})
         p22: [4]u16 = image64_get(img, ix + 1, iy + 1, {0, 0, 0, 255})
         p23: [4]u16 = image64_get(img, ix + 2, iy + 1, {0, 0, 0, 255})

         p30: [4]u16 = image64_get(img, ix - 1, iy + 2, {0, 0, 0, 255})
         p31: [4]u16 = image64_get(img, ix, iy + 2, {0, 0, 0, 255})
         p32: [4]u16 = image64_get(img, ix + 1, iy + 2, {0, 0, 0, 255})
         p33: [4]u16 = image64_get(img, ix + 2, iy + 2, {0, 0, 0, 255})

         p: [4]u16
         c0, c1, c2, c3: f32

         for i in 0..<4
         {
            c0 = blend_bicubic(f32(p00[i]), f32(p01[i]), f32(p02[i]), f32(p03[i]), six)
            c1 = blend_bicubic(f32(p10[i]), f32(p11[i]), f32(p12[i]), f32(p13[i]), six)
            c2 = blend_bicubic(f32(p20[i]), f32(p21[i]), f32(p22[i]), f32(p23[i]), six)
            c3 = blend_bicubic(f32(p30[i]), f32(p31[i]), f32(p32[i]), f32(p33[i]), six)
            p[i] = max(0, min(u16(max(i16)), u16(blend_bicubic(c0, c1, c2, c3, siy))))
         }

         out.data[y * out.width + x] = p
      }
   }

   return out
}

@(private="file")
lanczos :: proc "contextless" (v: f32) -> f32
{
   if v == 0 do return 1
   if v > 3 || v < -3 do return 0

   return (3 * math.sin(math.PI * v) * math.sin(math.PI * v / 3)) / (math.PI * math.PI * v * v)
}

@(private="file")
sample_lanczos :: proc(img: ^Image64, width: i32, height: i32, x_off: f32, y_off: f32) -> ^Image64 #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   out: ^Image64 = image64_new(width, height)
   fw: f32 = f32(img.width - 1) / f32(width)
   fh: f32 = f32(img.height - 1) / f32(height)

   for y in 0..<height
   {
      for x in 0..<width
      {
         ix: i32 = i32((f32(x) + x_off + 0.5) * fw)
         iy: i32 = i32((f32(y) + y_off + 0.5) * fh)
         six: f32 = (f32(x) + x_off + 0.5) * fw - f32(ix)
         siy: f32 = (f32(y) + y_off + 0.5) * fh - f32(iy)

         a0: f32 = lanczos(six + 2)
         a1: f32 = lanczos(six + 1)
         a2: f32 = lanczos(six)
         a3: f32 = lanczos(six - 1)
         a4: f32 = lanczos(six - 2)
         a5: f32 = lanczos(six - 3)
         b0: f32 = lanczos(siy + 2)
         b1: f32 = lanczos(siy + 1)
         b2: f32 = lanczos(siy)
         b3: f32 = lanczos(siy - 1)
         b4: f32 = lanczos(siy - 2)
         b5: f32 = lanczos(siy - 3)

         c: [6][4]f32

         for i in 0..<i32(6)
         {
            p00: [4]u16 = image64_get(img, ix - 2, iy - 2 + i, {0, 0, 0, 255})
            p01: [4]u16 = image64_get(img, ix - 1, iy - 2 + i, {0, 0, 0, 255})
            p02: [4]u16 = image64_get(img, ix, iy - 2 + i, {0, 0, 0, 255})
            p03: [4]u16 = image64_get(img, ix + 1, iy - 2 + i, {0, 0, 0, 255})
            p04: [4]u16 = image64_get(img, ix + 2, iy - 2 + i, {0, 0, 0, 255})
            p05: [4]u16 = image64_get(img, ix + 3, iy - 2 + i, {0, 0, 0, 255})

            for j in 0..<4
            {
               c[i][j] = a0 * f32(p00[j]) + a1 * f32(p01[j]) + a2 * f32(p02[j]) + a3 * f32(p03[j]) + a4 * f32(p04[j]) + a5 * f32(p05[j])
            }
         }

         p: [4]u16
         for i in 0..<4
         {
            p[i] = max(0, min(u16(max(i16)), u16(b0 * c[0][i] + b1 * c[1][i] + b2 * c[2][i] + b3 * c[3][i] + b4 * c[4][i] + b5 * c[5][i])))
         }

         out.data[y * out.width + x] = p
      }
   }

   return out
}

@(private="file")
sample_cluster :: proc(img: ^Image64, width: i32, height: i32, x_off: f32, y_off: f32) -> ^Image64 #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   out: ^Image64 = image64_new(width, height)
   w: f32 = f32(img.width - 1) / f32(width)
   h: f32 = f32(img.height - 1) / f32(height)

   grid_x: f32 = f32(img.width) / f32(width)
   grid_y: f32 = f32(img.height) / f32(height)
   igrid_x: i32 = i32(grid_x)
   igrid_y: i32 = i32(grid_y)
   if igrid_x <= 0 || igrid_y <= 0
   {
      return sample_nearest(img, width, height, x_off, y_off)
   }

   {
      cluster: ^Image32 = image32_new(igrid_x, igrid_y)
      defer free(cluster)
      colours: [256][4]u8

      for y in 0..<height
      {
         for x in 0..<width
         {
            dx: f32 = f32(x) + x_off + 0.5
            dy: f32 = f32(y) + y_off + 0.5
            ix: i32 = max(0, min(img.width - 1, i32(math.round(dx * w))))
            iy: i32 = max(0, min(img.height - 1, i32(math.round(dy * h))))
            p: [4]u16 = img.data[iy * img.width + ix]

            for gy in 0..<igrid_y
            {
               for gx in 0..<igrid_x
               {
                  fx: f32 = f32(x)
                  fy: f32 = f32(y)
                  fgx: f32 = f32(gx)
                  fgy: f32 = f32(gy)

                  cluster.data[gy * igrid_x + gx] = {0, 0, 0, 255}
                  if fx * grid_x + fgx >= 0 && fx * grid_x + fgx < f32(img.width) &&
                     fy * grid_y + fgy >= 0 && fy * grid_y + fgy < f32(img.height)
                  {
                     cluster.data[gy * igrid_x+ gx] = colour64_to_32(img.data[(i32(fy * grid_y) + gy) * img.width + i32(fx * grid_x) + gx])
                  }
               }
            }

            c: [4]u16 = colour32_to_64(image32_kmeans_largest(cluster, &colours, 3, 0xdeadbeef))
            c[3] = p[3]

            out.data[y * width + x] = c
         }
      }
   }

   return out
   /*
            uint64_t c = color32_to_64(image32_kmeans_largest(cluster,colors,3,0xdeadbeef));
            uint64_t r = color64_r(c);
            uint64_t g = color64_g(c);
            uint64_t b = color64_b(c);
            out->data[y*width+x] = (r)|(g<<16)|(b<<32)|(a<<48);
         }
      }

      free(cluster);
   }

   return out;
   */

   /*
   out: ^Image64 = image64_new(width, height)
   fw: f32 = f32(img.width - 1) / f32(width)
   fh: f32 = f32(img.height - 1) / f32(height)

   for y in 0..<height
   {
      for x in 0..<width
      {
         ix: i32 = i32((f32(x) + x_off + 0.5) * fw)
         iy: i32 = i32((f32(y) + y_off + 0.5) * fh)
         six: f32 = (f32(x) + x_off + 0.5) * fw - f32(ix)
         siy: f32 = (f32(y) + y_off + 0.5) * fh - f32(iy)

         a0: f32 = lanczos(six + 2)
         a1: f32 = lanczos(six + 1)
         a2: f32 = lanczos(six)
         a3: f32 = lanczos(six - 1)
         a4: f32 = lanczos(six - 2)
         a5: f32 = lanczos(six - 3)
         b0: f32 = lanczos(siy + 2)
         b1: f32 = lanczos(siy + 1)
         b2: f32 = lanczos(siy)
         b3: f32 = lanczos(siy - 1)
         b4: f32 = lanczos(siy - 2)
         b5: f32 = lanczos(siy - 3)

         c: [6][4]f32

         for i in 0..<i32(6)
         {
            p00: [4]u16 = image64_get(img, ix - 2, iy - 2 + i, {0, 0, 0, 255})
            p01: [4]u16 = image64_get(img, ix - 1, iy - 2 + i, {0, 0, 0, 255})
            p02: [4]u16 = image64_get(img, ix, iy - 2 + i, {0, 0, 0, 255})
            p03: [4]u16 = image64_get(img, ix + 1, iy - 2 + i, {0, 0, 0, 255})
            p04: [4]u16 = image64_get(img, ix + 2, iy - 2 + i, {0, 0, 0, 255})
            p05: [4]u16 = image64_get(img, ix + 3, iy - 2 + i, {0, 0, 0, 255})

            for j in 0..<4
            {
               c[i][j] = a0 * f32(p00[j]) + a1 * f32(p01[j]) + a2 * f32(p02[j]) + a3 * f32(p03[j]) + a4 * f32(p04[j]) + a5 * f32(p05[j])
            }
         }

         p: [4]u16
         for i in 0..<4
         {
            p[i] = max(0, min(u16(max(i16)), u16(b0 * c[0][i] + b1 * c[1][i] + b2 * c[2][i] + b3 * c[3][i] + b4 * c[4][i] + b5 * c[5][i])))
         }

         out.data[y * out.width + x] = p
      }
   }

   return out
   */
}
