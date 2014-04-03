# Unlike the hme module, this is a straight port of the version in
# TiVo's Java SDK. (I've even kept the original comments.) As such, it's
# a derivative work, released under the Common Public License.
#
# Original version credited authors: Adam Doppelt, Arthur van Hoff,
# Brigham Stevens, Jonathan Payne, Steven Samorodin
# Copyright 2004, 2005 TiVo Inc.
#
# python version: William McBrine, 2008-2013
# ruby version: Matt Conway

require 'tivohme'
include TivoHME

TITLE = 'Tic-Tac-Toe'

class TicTacToe < Application

  attr_accessor :pieces_view, :pieces, :gridx, :gridy, :num_moves, :tokens

  def startup
    # a View to contain all the pieces
    self.pieces_view = View.new(self)

    # the pieces themselves
    self.pieces = [[nil] * 3, [nil] * 3, [nil] * 3]

    # the origin of the pieces grid on screen
    self.gridx = (self.root.width - 300) / 2
    self.gridy = 130

    # number of elapsed moves 0-9
    self.num_moves = 0

    # layout the screen
    self.root.set_image(File.expand_path("../bg.jpg", __FILE__))
    self.root.child(xpos: self.gridx - 5, ypos: self.gridy - 5, width: 310, height: 310,
                    image: File.expand_path("../grid.png", __FILE__))

    # the X and O pieces
    Font.new(self, size: 72, style: FONT_BOLD)
    self.tokens = [Text.new(self, 'X'), Text.new(self, 'O')]
  end


  def handle_key_press(keynum, rawcode)
    if keynum >= KEY_NUM1 && keynum <= KEY_NUM9
      pos = keynum - KEY_NUM1
      # convert pos to x/y and make a move
      self.make_move(pos % 3, pos / 3)
    elsif keynum == KEY_LEFT
      self.active = false
    else
      self.sound('bonk')
    end
  end

  def make_move(x, y)
    # is this a valid move?
    if ! self.pieces[x][y].nil?
      self.sound('bonk')
      return
    end
    player = self.num_moves % 2
    self.num_moves += 1

    # create the piece
    self.pieces[x][y] = Piece.new(self.pieces_view,
                                  self.gridx + (x * 100),
                                  self.gridy + (y * 100),
                                  100, 100, player)

    # is the game over?
    victory = self.is_victory()
    draw = (! victory) && self.num_moves == 9
    if victory || draw
      if victory
        snd = 'tivo'
      else
        snd = 'thumbsdown'
      end
      self.sound(snd)

      self.sleep(2)

      # if this is a victory, explode the pieces
      # if this is a victory or a draw, make the pieces fade away
      anim = Animation.new(self, 1)
      3.times do |i|
        3.times do |j|
          v = self.pieces[i][j]
          if ! v.nil?
            if victory
              v.set_bounds(xpos: v.xpos + (i - 1) * 400,
                           ypos: v.ypos + (j - 1) * 300,
                           animation: anim)
            end
            v.set_transparency(1, animation: anim)
            v.remove(animation: anim)
            self.pieces[i][j] = nil
          end
        end
      end
      self.num_moves = 0
    end
  end

  # Returns true if there is a victory on the board.
  def is_victory
    3.times do |i|
      if self.is_victory_run(0, i, 1, 0) || self.is_victory_run(i, 0, 0, 1)
        return true
      end
    end

    return self.is_victory_run(0, 0, 1, 1) || self.is_victory_run(0, 2, 1, -1)
  end

  # Return true if there is a victory (three pieces in a row) starting
  # at ox,oy and proceeding according to dx,dy. This will highlight
  # the winning moves if there is a victory.

  def is_victory_run(ox, oy, dx, dy)
    x = ox
    y = oy
    3.times do |i|
      if self.pieces[x][y].nil?
        return false
      end
      if i > 0 && self.pieces[x][y].player != self.pieces[x - dx][y - dy].player
        return false
      end
      x += dx
      y += dy
    end

    # yes - we win! highlight the pieces.
    x = ox
    y = oy
    3.times do |i|
      self.pieces[x][y].set_color(0xffa000)
      x += dx
      y += dy
    end

    return true
  end

end

# An X or O piece. Notice that the X/O is placed in a child instead of
# in the view itself. We do this so that we can highlight the background
# of the piece later by calling set_resource().
class Piece < View

  attr_accessor :player

  def initialize(parent, x, y, w, h, player)
    super(parent.app, xpos: x, ypos: y, width: w, height: h, parent: parent)
    self.player = player
    self.child(resource: self.app.tokens[player])
  end
end
