package main

import "core:log"
import "core:fmt"
import "core:image/png"
import "core:image/qoi"
import "core:image/tga"
import "core:image/bmp"
import "core:image/netpbm"
import "core:image"
import "core:bytes"
import "../../gui/"

main :: proc()
{
   res: bool = gui.init()

   w: ^gui.Window = gui.window_create("Test", 640, 480, "test.png")

   menus: [3]^gui.Element
   menus[0] = gui.menu_create(w, {no_parent = true, overlay = true, style = 1}, {fill_x = true}, {"New", "Save", "Save As", "Load"}, nil)
   menus[1] = gui.menu_create(w, {no_parent = true, overlay = true, style = 1}, {fill_x = true}, {"Test", "Save", "Save As", "Load"}, nil)
   menus[2] = gui.menu_create(w, {no_parent = true, overlay = true, style = 1}, {fill_x = true}, {"Test", "Save", "Test"}, nil)

   root: ^gui.Group = gui.group_create(w, {fill_x = true, fill_y = true, layout = .VERTICAL})
   gui.menubar_create(root, {fill_x = true, layout = .HORIZONTAL}, {}, {"File", "Edit", "Help"}, menus[:], nil)
   gui.separator_create(root, {fill_x = true}, false)

   g0: ^gui.Group = gui.group_create(root, {fill_x = true, fill_y = true, layout = .HORIZONTAL})
   g1: ^gui.Group = gui.group_create(g0, {style = 1, layout = .HORIZONTAL, fill_x = true, fill_y = true})
   g2: ^gui.Group = gui.group_create(g1, {style = 1, })
   s0: ^gui.ScrollGroup = gui.scroll_group_create(g1, {fill_x = true, fill_y = true, layout = .HORIZONTAL})
   g0.pad = {{16, 16}, {16, 16}}
   g1.pad = {{8, 8}, {8, 8}}
   g1.child_gap = 24
   g2.size_min = {128, 128}

   b1: ^gui.CheckButton = gui.checkbutton_create(s0, {}, "Test2")
   t0: ^gui.Text = gui.text_create(s0, 
      {style = 1, fill_x = true, fill_y = true}, 
      `I was far from home, and the spell of the eastern sea was upon me. In the twilight I heard it pounding on the rocks, and I knew it lay just over the hill where the twisting willows writhed against the clearing sky and the first stars of evening. And because my fathers had called me to the old town beyond, I pushed on through the shallow, new-fallen snow along the road that soared lonely up to where Aldebaran twinkled among the trees; on toward the very ancient town I had never seen but often dreamed of.

It was the Yuletide, which men call Christmas, though they know in their hearts it is older than Bethlehem and Babylon, older than Memphis and mankind. It was the Yuletide, and I had come at last to the ancient sea town where my people had dwelt and kept festival in the elder time when festival was forbidden; where also they had commanded their sons to keep festival once every century, that the memory of primal secrets might not be forgotten. Mine were an old people, old even when this land was settled three hundred years before. And they were strange, because they had come as dark, furtive folk from opiate southern gardens of orchids, and spoken another tongue before they learnt the tongue of the blue-eyed fishers. And now they were scattered, and shared only the rituals of mysteries that none living could understand. I was the only one who came back that night to the old fishing town as legend bade, for only the poor and the lonely remember.
Then beyond the hill's crest I saw Kingsport outspread frostily in the gloaming; snowy Kingsport with its ancient vanes and steeples, ridgepoles and chimneypots, wharves and small bridges, willow trees and graveyards; endless labyrinths of steep, narrow, crooked streets, and dizzy church-crowned central peak that time durst not touch; ceaseless mazes of colonial houses piled and scattered at all angles and levels like a child's disordered blocks; antiquity hovering on gray wings over winter-whitened gables and gambrel roofs. And against the rotting wharves the sea pounded; the secretive, immemorial sea out of which the people had come in the elder time.

Beside the road at its crest a still higher summit rose, bleak and wind-swept, and I saw that it was a burying-ground where black gravestones stuck ghoulishly through the snow like the decayed fingernails of a gigantic corpse. The printless road was very lonely, and sometimes I thought I heard a distant horrible creaking as of a gibbet in the wind. They had hanged four kinsmen of mine for witchcraft in 1692, but I did not know just where. 
As the road wound down the seaward slope I listened for the merry sounds of a village at evening, but did not hear them. Then I thought of the season, and felt that these old Puritan folk might well have Christmas customs strange to me, and full of silent hearthside prayer. So after that I did not listen for merriment or look for wayfarers, but kept on down past the hushed, lighted farmhouses and shadowy stone walls to where the signs of ancient shops and sea taverns creaked in the salt breeze, and the grotesque knockers of pillared doorways glistened along deserted, unpaved lanes in the light of little, curtained windows.

I had seen maps of the town, and knew where to find the home of my people. It was told that I should be known and welcomed, for village legend lives long; so I hastened through Back Street to Circle Court, and across the fresh snow on the one full flagstone pavement in the town, to where Green Lane leads off behind the Market House. I was glad I had chosen to walk. The white village had seemed very beautiful from the hill; and now I was eager to knock at the door of my people, the seventh house on the left in Green Lane, with an ancient peaked roof and jutting second story, all built before 1650.

There were lights inside the house when I came upon it, and I saw from the diamond window-panes that it must have been kept very close to its antique state. The upper part overhung the narrow, grass-grown street and nearly met the overhanging part of the house opposite, so that I was almost in a tunnel, with the low stone doorstep wholly free from snow. There was no sidewalk, but many houses had high doors reached by double flights of steps with iron railings. It was an odd scene, and because I was strange to New England I had never known its like before. Though it pleased me, I would have relished it better if there had been footprints in the snow, and people in the streets, and a few windows without drawn curtains. `
       )
   rb0: ^gui.RadioButton= gui.radiobutton_create(g2, {}, "Test")
   rb1: ^gui.RadioButton= gui.radiobutton_create(g2, {}, "Test")
   rb2: ^gui.RadioButton= gui.radiobutton_create(g2, {}, "Test")
   entry: ^gui.Entry = gui.entry_create(g2, {}, 16)

   gui.msg_loop()
}
