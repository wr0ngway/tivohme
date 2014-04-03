# Unlike the hme module, this is a fairly straight port of the version
# in TiVo's Java SDK. (I've even kept the original comments.) As such,
# it's a derivative work, released under the Common Public License.
#
# Original version Copyright 2004, 2005 TiVo Inc.
# No credited authors
#
# python version: William McBrine, 2009-2012
# ruby version: Matt Conway

require 'tivohme'
include TivoHME

# Simple application to test new transition feature.

COLORS = [0xff0000, 0xffff00, 0x00ff00, 0x0000ff]

class Transition < Application

  attr_accessor :params, :cur_color,
                :depth_view, :entry_view, :return_view,
                :color_view, :hilight_view, :error_view

  def startup
    self.params = {'depth' => 0, 'entry' => -1, 'return' => -1}
    self.cur_color = 0

    x = SAFE_ACTION_H
    w = self.root.width - 2 * x

    TextView.new(self, x, SAFE_ACTION_V, w, 40,
                 fontsize: 30, text: 'HME Transition Test')

    self.depth_view = TextView.new(self, x, 70, w, 40)
    self.entry_view = TextView.new(self, x, 100, w / 2 - 10, 40)
    self.return_view = TextView.new(self, x + w / 2 + 20, 100,
                                    w / 2 - 10, 40)
    self.color_view = TextView.new(self, x, 130, w, 40)

    TextView.new(self, x, 400, w, 40, fontsize: 14,
                 text: 'Move up and down to select a color.  ' +
                       'Move left to go back, right to go forward.')

    x = SAFE_ACTION_H + 75
    w = self.root.width - 2 * x
    self.hilight_view = View.new(self, xpos: x, ypos: 175, width: w, height: 50, colornum: 0xffffff)
    self.update_hilight()

    x = SAFE_ACTION_H + 80
    w = self.root.width - 2 * x
    COLORS.each_with_index do |col, i|
      View.new(self, xpos: x, ypos: 180 + i * 50, width: w, height: 40, colornum: col)
    end

    self.error_view = TextView.new(self, x, 440, w, 40,
                                  fontsize: 18, textcolor: 0xff0000)
  end


  # This method handles the incoming INIT_INFO event.  Here we
  # determine if we were entered via a "forward" transition or a
  # "back" transition (or possibly no transition at all).
  def handle_init_info(params, memento)
    logger.debug("Params: #{params.inspect}")
    logger.debug("Memento: #{memento.inspect}")

    self.params.merge!(params)
    self.update_inits()

    if memento
      self.cur_color = memento[0].ord
      self.update_hilight()
    end
  end

  def handle_key_press(code, rawcode)
    if code == KEY_UP
      self.cur_color = (self.cur_color - 1) % COLORS.size
      self.update_hilight()
    elsif code == KEY_DOWN
      self.cur_color = (self.cur_color + 1) % COLORS.size
      self.update_hilight()
    elsif code == KEY_RIGHT
      mem = self.cur_color.chr
      params = {'entry' => self.cur_color,
                'depth' => self.params['depth'].to_i + 1}
      self.transition(TRANSITION_FORWARD, params,
                      context['url'],
                      mem)
    elsif code == KEY_LEFT
      params = {'return' => self.cur_color,
                'depth' => self.params['depth'].to_i - 1}
      self.transition(TRANSITION_BACK, params)
    end
  end

  def handle_error(code, text)
    self.error_view.set_value(text)
  end

  def update_inits
    self.depth_view.set_value('Current depth is %s.' %
                              self.params['depth'])

    ec = self.params['entry'].to_i
    if ec < 0
      self.entry_view.set_value('No entry color.', 0x7f7f7f)
    else
      self.entry_view.set_value('%#08x' % COLORS[ec], COLORS[ec])
    end

    rc = self.params['return'].to_i
    if rc < 0
      self.return_view.set_value('No return color', 0x7f7f7f)
    else
      self.return_view.set_value('%#08x' % COLORS[rc], COLORS[rc])
    end
  end

  def update_hilight
    y = 180 + self.cur_color * 50 - 5
    self.hilight_view.set_bounds(ypos: y, animtime: 0.25)
    self.color_view.set_value('The currently selected color is %#08x' %
                              COLORS[self.cur_color],
                              COLORS[self.cur_color])
  end

end

class TextView < View

  attr_accessor :font, :value, :fg

  def initialize(app, x, y, width, height,
                 text: '', fontsize: 20, textcolor: 0xffffff)
    super(app, xpos: x, ypos: y, width: width, height: height)
    self.font = Font.new(self.app, size: fontsize)
    self.set_value(text, textcolor)
  end

  def set_value(text, colornum=nil)
    self.value = text
    if ! colornum.nil?
      self.fg = Color.new(self.app, colornum)
    end
    self.set_text(self.value, font: self.font, color: self.fg)
  end

end

