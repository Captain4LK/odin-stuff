package gui

import "core:log"
import "core:strings"
import "vendor:sdl3"

Text :: struct
{
   using element: Element,

   text: string,
   width_min: i32,
}

text_create :: proc(parent: ^Element, flags: ElementFlags, str: string) -> ^Text
{
   text: ^Text = &element_create(Text, parent, flags, text_msg).derived.(Text)
   text.text = strings.clone(str)
   text.width_min = text_width_min(text)

   return text
   //window: ^Window = &element_create(Window, nil, {}, window_msg).derived.(Window)
}

@(private="file")
text_msg :: proc(e: ^Element, msg: Msg, di: int, dp: rawptr) -> int
{
   text: ^Text = &e.derived.(Text)

   if msg == .GET_WIDTH
   {
      return int(max(text.size_min[0], text.width_min * GLYPH_WIDTH * get_scale()))
   }
   else if msg == .GET_HEIGHT
   {
      space: ^[2]i32 = cast(^[2]i32)dp
      return int(max(text.size_min[0], text_height_by_width(text, space[1])))
   }
   else if msg == .DRAW
   {
      text_draw(text)
   }
   else if msg == .DESTROY
   {
      delete(text.text)
   }

   return 0
}

@(private="file")
text_draw :: proc(text: ^Text)
{
   if text.flags.style == 0
   {
      //draw_rectangle_fill(text, text.bounds, {90, 90, 90, 255})
      draw_text(text, text.bounds, text.text, {200, 200, 200, 255}, true)
   }
   else if text.flags.style == 1
   {
      //draw_rectangle_fill(text, text.bounds, {90, 90, 90, 255})
      //draw_rectangle(text, text.bounds, {0, 0, 0, 255})
      draw_text(text, text.bounds, text.text, {200, 200, 200, 255}, true)
   }
}

@(private="file")
text_width_min:: proc(text: ^Text) -> i32
{
   width_min: i32 = 0
   width: i32 = 0
   for i in 0..<len(text.text)
   {
      if text.text[i] != ' ' &&
         text.text[i] != '\n' &&
         text.text[i] != '\r' &&
         text.text[i] != '\t'
      {
         width += 1
         width_min = max(width_min, width)
      }
      else
      {
         width = 0
      }
   }

   return width_min
}

@(private="file")
text_height_by_width :: proc(text: ^Text, width: i32) -> i32
{
   scale: i32 = get_scale()
   pos: [2]i32
   for i in 0..<len(text.text)
   {
      if text.text[i] == ' '
      {
         word_width: i32 = 1
         for w in i + 1..<len(text.text)
         {
            if text.text[w] == ' ' do break
            word_width += 1
         }

         if pos[0] + word_width * GLYPH_WIDTH * scale > width
         {
            pos[0] = 0
            pos[1] += GLYPH_HEIGHT * scale
            continue
         }
      }
      if text.text[i] == '\n'
      {
         pos[0] = 0
         pos[1] += GLYPH_HEIGHT * scale
         continue
      }
      
      pos[0] += GLYPH_WIDTH * scale
   }
   return pos[1] + GLYPH_HEIGHT * scale
}
