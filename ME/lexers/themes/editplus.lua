-- Copyright 2006-2012 Mitchell mitchell.att.foicica.com. See LICENSE.
-- Dark lexer theme for Scintillua.
-- Contributions by Ana Balan.


local l, color, style = lexer, lexer.color, lexer.style
local colors = require('color-def');

l.style_nothing    = style {                                  }
l.style_class      = style { fore = colors.LightYellow       }
l.style_comment    = style { fore = colors.Green4          }
l.style_constant   = style { fore = colors.Red                }
l.style_definition = style { fore = colors.LightYellow       }
l.style_error      = style { fore = colors.Red }
l.style_function   = style { fore = colors.Red     }
l.style_keyword    = style { fore = colors.Blue              }
l.style_label      = style { fore = color('80', '00', '80')             }
l.style_number     = style { fore = color('80', '00', '80')                }
l.style_operator   = style { fore = color('00', '80', '80')             }
l.style_regex      = style { fore = colors.LightGreen        }
l.style_string     = style { fore = color('FF', '00', 'FF')              }
l.style_preproc    = style { fore = colors.Purple3             }
l.style_tag        = style { fore = colors.Blue         }
l.style_type       = style { fore = colors.SlateBlue           }
l.style_variable   = style { fore = colors.CadetBlue         }
l.style_whitespace = style {                                    }
l.style_embedded   = l.style_tag..{ back = colors.LightBlack }
l.style_identifier = l.style_nothing
l.style_libaray    = style { fore = colors.Red           }

-- Default styles.
local font_face = '!Bitstream Vera Sans Mono'
local font_size = 11
if WIN32 then
  font_face =  '新宋体' or 'Courier New' or '!Courier New'
elseif OSX then
  font_face = '!Monaco'
  font_size = 12
end

l.style_default = style {
  font = font_face,
  size = font_size,
  fore = colors.Black,
  back = colors.White
}

l.style_line_number = style { font="新宋体", fore = colors.DarkGrey, back = colors.White , size=11}
l.style_bracelight  = style { fore = colors.LightBlue }
l.style_bracebad    = style { fore = colors.LightRed }
l.style_controlchar = l.style_nothing
l.style_indentguide = style { fore = colors.LightBlack, back = colors.LightBlack }
l.style_calltip     = style { fore = colors.Black, back = color('FF', 'FF', 'B0'), font='新宋体', size=12 }
