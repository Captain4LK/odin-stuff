package gui

import "core:log"
import "vendor:sdl3"

Group :: struct
{
   using element: Element,
}

group_create :: proc(parent: ^Element, flags: ElementFlags) -> ^Group
{
   group: ^Group = &element_create(Group, parent, flags, group_msg).derived.(Group)

   return group
}

@(private="file")
group_msg :: proc(e: ^Element, msg: Msg, di: int, dp: rawptr) -> int
{
   group: ^Group = &e.derived.(Group)

   if msg == .GET_WIDTH
   {
      space: ^[2]i32 = cast(^[2]i32)dp

      if group.flags.style == 0
      {
         return int(max(space[0], group.size_min[0]))
      }
      else if group.flags.style == 1
      {
         return int(max(space[0], group.size_min[0])) + 2 * int(get_scale())
      }
   }
   else if msg == .GET_HEIGHT
   {
      space: ^[2]i32 = cast(^[2]i32)dp

      if group.flags.style == 0
      {
         return int(max(space[0], group.size_min[1]))
      }
      else if group.flags.style == 1
      {
         return int(max(space[0], group.size_min[1])) + 2 * int(get_scale())
      }
   }
   else if msg == .GET_CHILD_PAD
   {
      pad: ^[2][2]i32 = cast(^[2][2]i32)dp

      if group.flags.style == 1
      {
         pad[0][0] = get_scale()
         pad[0][1] = get_scale()
         pad[1][0] = get_scale()
         pad[1][1] = get_scale()
      }
   }
   else if msg == .DRAW
   {
      group_draw(group)
   }

   return 0
}

@(private="file")
group_draw :: proc(group: ^Group)
{
   if group.flags.style == 0
   {
      draw_rectangle_fill(group, group.bounds, {90, 90, 90, 255})
   }
   else if group.flags.style == 1
   {
      draw_rectangle_fill(group, group.bounds, {90, 90, 90, 255})
      draw_rectangle(group, group.bounds, {0, 0, 0, 255})
   }
}
