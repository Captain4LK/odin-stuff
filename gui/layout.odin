package gui

import "core:log"

import "../prof"

@(private="file",rodata)
layout_axes: [Layout][2]int = {.VERTICAL= {1,0}, .HORIZONTAL = {0,1}, .WRAP = {1, 0}}

element_layout :: proc(e: ^Element, space: Rect)
{
   prof.SCOPED_EVENT(#procedure)

   if element_ignored(e) do return

   element_calculate_width(e)
   if !e.flags.overlay
   {
      element_calculate_grow_width(e, space.max - space.min)
   }
   else
   {
      element_calculate_grow_width(e, {e.size.x, space.max.y - space.min.y})
   }
   element_calculate_height(e)
   element_calculate_grow_height(e, space.max - space.min)
   element_calculate_position(e, {space.min, space.min + e.size})
   // TODO: for floating containers, given size is calculated size of e
}

@(private="file")
element_calculate_width :: proc(e: ^Element)
{
   prof.SCOPED_EVENT(#procedure)

   major: int = layout_axes[e.flags.layout][0]
   minor: int = layout_axes[e.flags.layout][1]
   size: [2]i32

   e.size = {0, 0}

   for child in e.children
   {
      if child.flags.ignore do continue

      element_calculate_width(child)

      size[major] += child.size[major]
      size[minor] = max(child.size[minor], size[minor])
   }

   size += e.pad[0] + e.pad[1]
   size[minor] += e.child_gap * i32(len(e.children) - 1)
   space: [2]i32 = {size[0], 0}
   e.size[0] = i32(element_msg_direct(e, .GET_WIDTH, 0, &space))
}

@(private="file")
element_calculate_height :: proc(e: ^Element)
{
   prof.SCOPED_EVENT(#procedure)

   log.assertf(e != nil, "nil passed to function")
   major: int = layout_axes[e.flags.layout][0]
   minor: int = layout_axes[e.flags.layout][1]

   if e.flags.layout == .WRAP
   {
      size: [2]i32
      height_local: i32
      width: i32 = e.size[0]
      width_local: i32 = 0

      for child in e.children
      {
         if child.flags.ignore do continue

         element_calculate_height(child)

         if width_local != 0 && width_local + child.size[0] > width
         {
            size[1] += height_local
            width_local = 0
            height_local = 0
         }

         height_local = max(height_local, child.size[1])
         width_local += child.size[0]
      }

      size += e.pad[0] + e.pad[1]
      size[minor] += e.child_gap * i32(len(e.children) - 1)
      space: [2]i32 = {size[1], e.size[0]}
      e.size[1] = i32(element_msg_direct(e, .GET_HEIGHT, 0, &space))
   }
   else
   {
      //major: int = layout_axes[e.flags.layout][0]
      //minor: int = layout_axes[e.flags.layout][1]
      size: [2]i32

      for child in e.children
      {
         if child.flags.ignore do continue

         element_calculate_height(child)

         size[major] += child.size[major]
         size[minor] = max(child.size[minor], size[minor])
      }

      size += e.pad[0] + e.pad[1]
      size[minor] += e.child_gap * i32(len(e.children) - 1)
      space: [2]i32 = {size[1], e.size[0]}
      e.size[1] = i32(element_msg_direct(e, .GET_HEIGHT, 0, &space))
   }
}

@(private="file")
element_calculate_grow_width :: proc(e: ^Element, available: [2]i32)
{
   prof.SCOPED_EVENT(#procedure)

   major: int = layout_axes[e.flags.layout][0]
   minor: int = layout_axes[e.flags.layout][1]

   child_pad: [2][2]i32
   element_msg_direct(e, .GET_CHILD_PAD, 0, &child_pad)

   available := available
   available -= e.pad[0] + e.pad[1] + child_pad[0] + child_pad[1]

   for child in e.children
   {
      available[major] -= child.size[major]
   }
   available[major] -= e.child_gap * i32(len(e.children) - 1)

   // Expand against layout direction
   for child in e.children
   {
      fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
      if fill[minor] && minor == 0 do child.size[minor] = available[minor]
   }

   // Expand in layouting direction
   remaining: i32 = available[major]
   for remaining > 0
   {
      smallest: i32 = max(i32)
      second_smallest: i32 = max(i32)
      to_add: i32 = remaining
      if major != 0 do break

      for child in e.children
      {
         size: i32 = child.size[major]
         fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
         if !fill[major] do continue

         if size < smallest
         {
            second_smallest = smallest
            smallest = size
         }

         if size > smallest
         {
            second_smallest = min(second_smallest, size)
         }
      }

      if second_smallest != max(i32)
      {
         to_add = second_smallest - smallest
      }
      to_add = min(remaining, to_add)

      num_to_add: int = 0
      for child in e.children
      {
         size: i32 = child.size[major]
         fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
         if !fill[major] do continue

         if size == smallest do num_to_add += 1
      }

      if num_to_add == 0 do break

      cur: int = 0
      rem: int = int(to_add) % num_to_add
      for child in e.children
      {
         size: i32 = child.size[major]
         fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
         if !fill[major] do continue

         if size != smallest do continue

         add: i32 = to_add / i32(num_to_add)
         if cur < rem do add += 1
         child.size[major] += add
         remaining -= add
         cur += 1
      }
   }

   // Children
   for child in e.children
   {
      if child.flags.ignore do continue

      element_calculate_grow_width(child, child.size)
   }
}

@(private="file")
element_calculate_grow_height:: proc(e: ^Element, available: [2]i32)
{
   prof.SCOPED_EVENT(#procedure)

   major: int = layout_axes[e.flags.layout][0]
   minor: int = layout_axes[e.flags.layout][1]

   child_pad: [2][2]i32
   element_msg_direct(e, .GET_CHILD_PAD, 0, &child_pad)

   available := available
   available -= e.pad[0] + e.pad[1] + child_pad[0] + child_pad[1]

   for child in e.children
   {
      available[major] -= child.size[major]
   }
   available[major] -= e.child_gap * i32(len(e.children) - 1)

   // Expand against layout direction
   for child in e.children
   {
      fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
      if fill[minor] && minor == 1 do child.size[minor] = available[minor]
   }

   // Expand in layouting direction
   remaining: i32 = available[major]
   for remaining > 0
   {
      smallest: i32 = max(i32)
      second_smallest: i32 = max(i32)
      to_add: i32 = remaining
      if major != 1 do break

      for child in e.children
      {
         size: i32 = child.size[major]
         fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
         if !fill[major] do continue

         if size < smallest
         {
            second_smallest = smallest
            smallest = size
         }

         if size > smallest
         {
            second_smallest = min(second_smallest, size)
         }
      }

      if second_smallest != max(i32)
      {
         to_add = second_smallest - smallest
      }
      to_add = min(remaining, to_add)

      num_to_add: int = 0
      for child in e.children
      {
         size: i32 = child.size[major]
         fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
         if !fill[major] do continue

         if size == smallest do num_to_add += 1
      }

      if num_to_add == 0 do break

      cur: int = 0
      rem: int = int(to_add) % num_to_add
      for child in e.children
      {
         size: i32 = child.size[major]
         fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
         if !fill[major] do continue

         if size != smallest do continue

         add: i32 = to_add / i32(num_to_add)
         if cur < rem do add += 1
         child.size[major] += add
         remaining -= add
         cur += 1
      }
   }

   // Children
   for child in e.children
   {
      if child.flags.ignore do continue

      element_calculate_grow_height(child, child.size)
   }
}

@(private="file")
element_calculate_position :: proc(e: ^Element, available: Rect) #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   e.bounds = available
   e.size_children = {0, 0}

   if len(e.children) == 0 do return

   if e.flags.layout == .WRAP
   {
      major: int = layout_axes[e.flags.layout][0]
      minor: int = layout_axes[e.flags.layout][1]

      child_pad: [2][2]i32
      element_msg(e, .GET_CHILD_PAD, 0, &child_pad)

      child_space: Rect = e.bounds
      child_space.min += e.pad[0] + child_pad[0]
      child_space.max -= e.pad[1] + child_pad[1]

      pos: [2]i32 = child_space.min
      height_local: i32
      width: i32 = e.size[0]
      width_local: i32 = 0

      for child in e.children
      {
         if child.flags.ignore do continue
         //if element_ignored(child) do continue

         if width_local != 0 && width_local + child.size[0] > width
         {
            child_space.min[major] += child.size[major]
            child_space.min[major] += e.child_gap
            child_space.min.x = pos.x
            width_local = 0
            height_local = 0
         }

         element_calculate_position(child, {child_space.min, child_space.min + child.size})

         child_space.min[minor] += child.size[minor]
         child_space.min[minor] += e.child_gap

         height_local = max(height_local, child.size[1])
         width_local += child.size[0]

         e.size_children[major] += child.size[major] + e.child_gap
         e.size_children[minor] = max(e.size_children[minor], child.size[minor])
      }
   }
   else if e.flags.layout == .VERTICAL
   {
//layout_axes: [Layout][2]int = {.VERTICAL= {1,0}, .HORIZONTAL = {0,1}, .WRAP = {1, 0}}
      major: int = layout_axes[e.flags.layout][0]
      minor: int = layout_axes[e.flags.layout][1]

      child_pad: [2][2]i32
      element_msg(e, .GET_CHILD_PAD, 0, &child_pad)

      child_space: Rect = e.bounds
      child_space.min += e.pad[0] + child_pad[0]
      child_space.max -= e.pad[1] + child_pad[1]
      for child in e.children
      {
         if child.flags.ignore do continue

         origin: [2]i32 = child_space.min
         if child.flags.center_x
         {
            origin.x += (child_space.max.x - child_space.min.x - child.size.x) / 2
         }

         element_calculate_position(child, {origin, origin + child.size})
         child_space.min[1] += child.size[1]
         child_space.min[1] += e.child_gap

         e.size_children[1] += child.size[1] + e.child_gap
         e.size_children[0] = max(e.size_children[0], child.size[0])
      }
   }
   else if e.flags.layout == .HORIZONTAL
   {
      major: int = layout_axes[e.flags.layout][0]
      minor: int = layout_axes[e.flags.layout][1]

      child_pad: [2][2]i32
      element_msg(e, .GET_CHILD_PAD, 0, &child_pad)

      child_space: Rect = e.bounds
      child_space.min += e.pad[0] + child_pad[0]
      child_space.max -= e.pad[1] + child_pad[1]
      for child in e.children
      {
         if child.flags.ignore do continue

         element_calculate_position(child, {child_space.min, child_space.min + child.size})
         child_space.min[major] += child.size[major]
         child_space.min[major] += e.child_gap

         e.size_children[major] += child.size[major] + e.child_gap
         e.size_children[minor] = max(e.size_children[minor], child.size[minor])
      }
   }
}
