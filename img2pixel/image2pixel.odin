package main

// TODO:
// json presets
// oklab distance
// palette loading
// x-means for down sampling
// dithering by preditherd patterns

ColourDist :: enum
{
   RGB_Euclidian,
   RGB_Weighted,
   RGB_Redmean,
   LAB_CIE76,
   LAB_CIE94,
   LAB_CIEDE2000,
}

DitherMode :: enum
{
   None,
   Bayer8x8,
   Bayer4x4,
   Bayer2x2,
   Cluster8x8,
   Cluster4x4,
   Floyd,
   Floyd2,
   MedianCut,
}

Config :: struct
{
   scale_relative: bool,
   size_absolute_x: i32,
   size_absolute_y: i32,
   size_relative_x: i32,
   size_relative_y: i32,

   sharp_amount: f32,

   hue: f32,
   saturation: f32,
   brightness: f32,
   contrast: f32,
   gamma: f32,
   tint: [3]u8,

   x_offset: f32,
   y_offset: f32,

   sample_mode: i32,
   blur_amount: f32,

   colour_dist:  ColourDist,

   target_colours: i32,

   dither_amount: f32,
   dither_mode: DitherMode,

   kmeanspp: bool,

   colour_selected: i32,

   alpha_threshold: i32,

   palette: [256][4]u8,
   colour_count: i32,
}

load_preset :: proc(path: string, conf: ^Config)
{
   conf.blur_amount = 0.
   conf.sample_mode = 0
   conf.x_offset = 0.
   conf.y_offset = 0.
   conf.scale_relative = false
   conf.size_relative_x = 2
   conf.size_relative_y = 2
   conf.size_absolute_x = 64
   conf.size_absolute_y = 64
   conf.sharp_amount = 0.
   conf.brightness = 0.
   conf.contrast = 1.
   conf.saturation = 1.
   conf.hue = 0.
   conf.gamma = 1.
   //conf.color_selected = 0
   conf.kmeanspp = true
   conf.tint = {255, 255, 255}
   conf.alpha_threshold = 128
   conf.dither_amount = 0.2
   conf.dither_mode = .Bayer8x8
   conf.colour_dist = .RGB_Redmean
   conf.target_colours = 8
   conf.colour_selected = 0

   //Dawnbringer-32 palette
   conf.colour_count = 32;
   conf.palette[0] = {0, 0, 0, 255}
   conf.palette[1] = {34, 32, 52, 255}
   conf.palette[2] = {69, 40, 60, 255}
   conf.palette[3] = {102, 57, 49, 255}
   conf.palette[4] = {143, 86, 59, 255}
   conf.palette[5] = {223, 113, 38, 255}
   conf.palette[6] = {217, 160, 102, 255}
   conf.palette[7] = {238, 195, 154, 255}
   conf.palette[8] = {251, 242, 54, 255}
   conf.palette[9] = {153, 229, 80, 255}
   conf.palette[10] = {106, 190, 48, 255}
   conf.palette[11] = {55, 148, 110, 255}
   conf.palette[12] = {75, 105, 47, 255}
   conf.palette[13] = {82, 75, 36, 255}
   conf.palette[14] = {50, 60, 57, 255}
   conf.palette[15] = {63, 63, 116, 255}
   conf.palette[16] = {48, 96, 130, 255}
   conf.palette[17] = {91, 110, 225, 255}
   conf.palette[18] = {99, 155, 255, 255}
   conf.palette[19] = {95, 205, 228, 255}
   conf.palette[20] = {203, 219, 252, 255}
   conf.palette[21] = {255, 255, 255, 255}
   conf.palette[22] = {155, 173, 183, 255}
   conf.palette[23] = {132, 126, 135, 255}
   conf.palette[24] = {105, 106, 106, 255}
   conf.palette[25] = {89, 86, 82, 255}
   conf.palette[26] = {118, 66, 138, 255}
   conf.palette[27] = {172, 50, 50, 255}
   conf.palette[28] = {217, 87, 99, 255}
   conf.palette[29] = {215, 123, 186, 255}
   conf.palette[30] = {143, 151, 74, 255}
   conf.palette[31] = {138, 111, 48, 255}
}
