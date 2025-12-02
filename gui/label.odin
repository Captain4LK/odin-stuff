package gui

import "core:log"
import "core:strings"
import "vendor:sdl3"

import "../prof"

Label :: struct
{
   using element: Element,

   text: string,
}

label_create :: proc(parent: ^Element, flags: ElementFlags, str: string) -> ^Label
{
   prof.SCOPED_EVENT(#procedure)

   label: ^Label = &element_create(Label, parent, flags, label_msg).derived.(Label)
   label.text = strings.clone(str)

   return label
}

@(private="file")
label_msg :: proc(e: ^Element, msg: Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   label: ^Label = &e.derived.(Label)

   if msg == .GET_WIDTH
   {
      return i64(i32(len(label.text)) * GLYPH_WIDTH * get_scale() + 2 * get_scale())
   }
   else if msg == .GET_HEIGHT
   {
      return i64(GLYPH_HEIGHT * get_scale() + 2 * get_scale())
   }
   else if msg == .DRAW
   {
      draw_label(label, label.bounds, label.text, {31, 31, 31, 255}, true)
   }
   else if msg == .DESTROY
   {
      delete(label.text)
   }

   return 0
}
