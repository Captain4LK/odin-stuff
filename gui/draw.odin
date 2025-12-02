package gui

import "core:log"
import "vendor:sdl3"

import "../prof"

draw_disable_clip :: proc(e: ^Element)
{
   res: bool = sdl3.SetRenderClipRect(e.window.sdl_renderer, nil)
   if !res do log.errorf("GetRenderClipRect failed: %v", sdl3.GetError())
}

draw_set_clip_rect :: proc(e: ^Element, rect: Rect)
{
   /*
   old: Rect
   old_clip: bool = sdl3.RenderClipEnabled(e.window.sdl_renderer)
   old_sdl: sdl3.Rect
   res: bool = sdl3.GetRenderClipRect(e.window.sdl_renderer, &old_sdl)
   if !res do log.errorf("GetRenderClipRect failed: %v", sdl3.GetError())
   old.min = {old_sdl.x, old_sdl.y}
   old.max = old.min + {old_sdl.w, old_sdl.h}
   */

   new_sdl: sdl3.Rect
   new_sdl.x = rect.min[0]
   new_sdl.y = rect.min[1]
   new_sdl.w = rect.max[0] - rect.min[0]
   new_sdl.h = rect.max[1] - rect.min[1]
   res: bool = sdl3.SetRenderClipRect(e.window.sdl_renderer, &new_sdl)
   if !res do log.errorf("SetRenderClipRect failed: %v", sdl3.GetError())
   //return old, old_clip
}

draw_rectangle_fill :: proc(e: ^Element, rect: Rect, colour: [4]u8)
{
   window: ^Window = e.window
   rect := rect
   rect.min += window.translation
   rect.max += window.translation

   r: sdl3.FRect
   r.x = f32(rect.min[0])
   r.y = f32(rect.min[1])
   r.w = f32(rect.max[0] - rect.min[0])
   r.h = f32(rect.max[1] - rect.min[1])

   res: bool = sdl3.SetRenderDrawColor(window.sdl_renderer, colour[0], colour[1], colour[2], colour[3])
   if !res do log.errorf("SetRenderDrawColor failed: %v", sdl3.GetError())

   res = sdl3.RenderFillRect(window.sdl_renderer, &r)
   if !res do log.errorf("RenderFillRect failed: %v", sdl3.GetError())
}

draw_rectangle :: proc(e: ^Element, rect: Rect, colour: [4]u8)
{
   window: ^Window = e.window
   rect := rect
   rect.min += window.translation
   rect.max += window.translation

   rects: [4]sdl3.FRect
   rects[0].x = f32(rect.min[0])
   rects[0].y = f32(rect.min[1])
   rects[0].w = f32(rect.max[0] - rect.min[0])
   rects[0].h = f32(get_scale())

   rects[1].x = f32(rect.min[0])
   rects[1].y = f32(rect.min[1] + get_scale())
   rects[1].w = f32(get_scale())
   rects[1].h = f32(rect.max[1] - rect.min[1] - get_scale())

   rects[2].x = f32(rect.max[0] - get_scale())
   rects[2].y = f32(rect.min[1] + get_scale())
   rects[2].w = f32(get_scale())
   rects[2].h = f32(rect.max[1] - rect.min[1] - get_scale())

   rects[3].x = f32(rect.min[0])
   rects[3].y = f32(rect.max[1] - get_scale())
   rects[3].w = f32(rect.max[0] - rect.min[0])
   rects[3].h = f32(get_scale())

   res: bool = sdl3.SetRenderDrawColor(window.sdl_renderer, colour[0], colour[1], colour[2], colour[3])
   if !res do log.errorf("SetRenderDrawColor failed: %v", sdl3.GetError())

   res = sdl3.RenderFillRects(window.sdl_renderer, &rects[0], 4)
   if !res do log.errorf("RenderFillRects failed: %v", sdl3.GetError())
}

draw_text :: proc(e: ^Element, rect: Rect, text: string, colour: [4]u8, do_wrap: bool)
{
   prof.SCOPED_EVENT(#procedure)

   // TODO: merge old and new clip rect
   //old_clip: Rect
   //old_do_clip: bool
   //old_clip, old_do_clip = draw_set_clip_rect(e, e.bounds, true)
   rect := rect
   rect.min += e.window.translation
   rect.max += e.window.translation

   scale: i32 = get_scale()
   pos: [2]i32 = rect.min

   res: bool = sdl3.SetTextureColorMod(e.window.sdl_font, colour[0], colour[1], colour[2])
   if !res do log.errorf("SetTextureColorMod failed: %v", sdl3.GetError())

   src: sdl3.FRect
   src.y = 0
   src.w = 8
   src.h = 16
   for i in 0..<len(text)
   {
      if do_wrap && text[i] == ' '
      {
         word_width: i32 = 1
         for w in i + 1..<len(text)
         {
            if text[w] == ' ' do break
            word_width += 1
         }

         if pos[0] + word_width * GLYPH_WIDTH * scale > rect.max[0]
         {
            pos[0] = rect.min[0]
            pos[1] += GLYPH_HEIGHT * scale
            continue
         }
      }
      if text[i] == '\n'
      {
         pos[0] = rect.min[0]
         pos[1] += GLYPH_HEIGHT * scale
         continue
      }
      c: u8 = text[i]
      if c > 127 do c = '?'

      dst: sdl3.FRect
      dst.x = f32(pos[0])
      dst.y = f32(pos[1])
      dst.w = f32(8 * scale)
      dst.h = f32(16 * scale)
      src.x = f32(c) * 8
      res = sdl3.RenderTexture(e.window.sdl_renderer, e.window.sdl_font, &src, &dst)
      if !res do log.errorf("RenderTexture failed: %v", sdl3.GetError())
      
      pos[0] += GLYPH_WIDTH * scale
   }

   //draw_set_clip_rect(e, old_clip, old_do_clip)
}

draw_label :: proc(e: ^Element, rect: Rect, text: string, colour: [4]u8, center: bool)
{
   prof.SCOPED_EVENT(#procedure)

   // TODO: merge old and new clip rect
   //old_clip: Rect
   //old_do_clip: bool
   //old_clip, old_do_clip = draw_set_clip_rect(e, e.bounds, true)
   rect := rect
   rect.min += e.window.translation
   rect.max += e.window.translation

   scale: i32 = get_scale()
   pos: [2]i32 = rect.min
   pos[1] = (rect.min[1] + rect.max[1] - GLYPH_HEIGHT * scale) / 2
   if center
   {
      pos[0] += (rect.max[0] - rect.min[0] - i32(len(text)) * GLYPH_WIDTH * scale) / 2
   }
   if pos[0] < rect.min[0]
   {
      pos[0] = rect.min[0] + ((rect.max[0] -rect.min[0]) - i32(len(text)) * GLYPH_WIDTH * scale)
   }

   res: bool = sdl3.SetTextureColorMod(e.window.sdl_font, colour[0], colour[1], colour[2])
   if !res do log.errorf("SetTextureColorMod failed: %v", sdl3.GetError())

   for i in 0..<len(text)
   {
      c: u8 = text[i]
      if c > 127 do c = '?'

      dst: sdl3.FRect
      dst.x = f32(pos[0])
      dst.y = f32(pos[1])
      dst.w = f32(8 * scale)
      dst.h = f32(16 * scale)
      src: sdl3.FRect
      src.x = f32(c) * 8
      src.y = 0
      src.w = 8
      src.h = 16
      res = sdl3.RenderTexture(e.window.sdl_renderer, e.window.sdl_font, &src, &dst)
      if !res do log.errorf("RenderTexture failed: %v", sdl3.GetError())
      
      pos[0] += GLYPH_WIDTH * scale
   }

   //draw_set_clip_rect(e, old_clip, old_do_clip)
}
