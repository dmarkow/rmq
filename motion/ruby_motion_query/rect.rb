module RubyMotionQuery

  class RMQ
    # @example
    # left = rmq(my_view).frame.left
    def frame(params = nil)
      if params
        frame = params
        self
      else
        if selected.length == 1
          Rect.frame_for_view(selected.first)
        else
          selected.map{|s| Rect.frame_for_view(s)}
        end
      end
    end

    # @example
    # rmq(my_view).frame = :full
    # rmq(my_view).frame = {l: 10, t: 20, w: 100, h: 150}
    def frame=(value)
      selected.each do |view| 
        Rect.update_view_frame(view, value)
      end
    end

    def bounds
      if selected.length == 1
        Rect.bounds_for_view(selected.first)
      else
        selected.map{|s| Rect.bounds_for_view(s)}
      end
    end

    # @example
    # rmq(my_view).bounds = :full
    # rmq(my_view).bounds = {l: 10, t: 20, w: 100, h: 150}
    def bounds=(value)
      selected.each do |view| 
        Rect.bounds_for_view(view).update(value, self.grid).apply_to_bounds
      end
    end

  end


  # RMQ Rect   
  #
  #    *******************---*******---***************************   value options
  #    *                   |         |                           *   -------------
  #    *                   |         |                           *   integer
  #    *                   |         |                           *   signed integer
  #    *                  top        |                           *   float
  #    *                   |         |                           *   :prev
  #    *                   |         |                           *   'a1:b4' 
  #    *                  ---        |                           *   
  #    *              ***************|*****   ---                *   additional size options
  #    *              * view         |    *    |                 *   -----------------------
  #    *              *              |    *    |                 *   :full
  #    *              *           bottom  *    |                 *   :half
  #    *              *              |    *    |                 *   :quarter
  #    *|--- left ---|*              |    *    |                 *                          
  #    *              *              |    * height               *   centered options
  #    *              *              |    *    |                 *   ---------
  #    *              *              |    *    |                 *   :horizontal
  #    *|-------------------- right -+---|*    |                 *   :vertical
  #    *              *              |    *    |                 *   :both
  #    *              *              |    * |--+--from_right----|*
  #    *              *             ---   *    |                 *
  #    *              ***************---***   ---                *
  #    *                              |                          *
  #    *              |------ width - + -|                       *
  #    *                              |                          *
  #    *                              |                          *
  #    *                          from_bottom                    *
  #    *                              |                          *
  #    *                              |                          *
  #    *                             ---                         *
  #    ***********************************************************
  #
  class Rect
    attr_reader :view

    class << self

      def update_view_frame(view, params)
        view.frame = view_rect_updated(view, view.frame, params)
      end
      def update_view_bounds(view, params)
        view.bounds = view_rect_updated(view, view.bounds, params)
      end

      # In singleton for performance # TODO, test if this is necessary
      def view_rect_updated(view, rect, params)
        if params == :full # Thanks teacup for the name
          view.superview.bounds
        elsif params.is_a?(Hash)

          params_l = params[:l] || params[:left] || params[:x]
          l = params_l || rect.origin.x
          params_t = params[:t] || params[:top] || params[:y]
          t = params_t || rect.origin.y
          params_w = params[:w] || params[:width]
          w = params_w || rect.size.width
          params_h = params[:h] || params[:height]
          h = params_h || rect.size.height
          r = params[:r] || params[:right]
          b = params[:b] || params[:bottom]
          fr = params[:from_right] || params[:fr]
          fb = params[:from_bottom] || params[:fb]

          # From right, from_bottom
          if (fr || fb) && (sv = view.superview)
            if fr
              if params_w
                l = sv.bounds.size.width - w - fr
              else
                w = sv.bounds.size.width - l - fr
              end
            end

            if fb
              if params_h
                t = sv.bounds.size.height - h - fb
              else
                h = sv.bounds.size.height - t - fb
              end
            end
          end

          # Right and bottom
          if r && !fr && !params_l
            l = r - w
          end
          if b && !fb && !params_t
            t = b - h
          end

          # Done
          rect.origin.x = l
          rect.origin.y = t
          rect.size.width = w
          rect.size.height = h
          rect

        elsif params.is_a?(String)
        else
          params 
        end
      end

      def frame_for_view(view)
        Rect.new(view.frame, view)
      end

      def bounds_for_view(view)
        Rect.new(view.bounds, view)
      end
    end # << self

    def initialize(params, view = nil, grid = nil)
      @view = view
      update params, grid
    end

    def update(params, grid = nil)
      if params == :full
        if @view
          update @view.superview.bounds
        else
          update rmq.rootview.bounds
        end
      elsif params.is_a?(RubyMotionQuery::Rect)
        @left, @top, @width, @height = params.l, params.t, params.w, params.h
      elsif params.is_a?(Hash)
        update hash_to_rect(params, grid), grid
      elsif grid && params.is_a?(String) 
        if point_or_rect = grid[string]
          if point_or_rect.is_a?(CGPoint)
            @left = point_or_rect.x
            @top = point_or_rect.y
          else
            update point_or_rect, grid
          end
        end
      elsif params.is_a?(CGRect)
        @left, @top, @width, @height = params.origin.x, params.origin.y, params.size.width, params.size.height
      elsif params.is_a?(NSArray)
        @left, @top, @width, @height = params
      else
        @left, @top, @width, @height = params.to_a
      end

      @left = 0 unless @left
      @top = 0 unless @top
      @width = 0 unless @width
      @height = 0 unless @height
    end

    def apply_to_frame
      @view.frame = to_cgrect if @view
    end
    def apply_to_bounds
      @view.bounds = to_cgrect if @view
    end

    def hash_to_rect(h, grid = nil)
      Rect.new(self, [0,0,0,0], grid)
    end

    def left
      @left
    end
    alias :l :left
    alias :x :left

    def right
      @left + @width
    end
    alias :r :right

    def from_right
      if @view && (sv = @view.superview)
        sv.size.width - right
      end
    end
    alias :fr :from_right

    def top
      @top
    end
    alias :t :top
    alias :y :top

    def bottom
      @top + @height
    end
    alias :b :bottom

    def from_bottom
      if @view && (sv = @view.superview)
        sv.size.height - bottom
      end
    end
    alias :fb :from_bottom

    def width
      @width
    end
    alias :w :width
    
    def height
      @height
    end
    alias :h :height

    def z_order
      if @view
        @view.superview.subviews.to_a.index(@view) # is there a better way??
      end
    end

    def origin
      to_cgpoint
    end

    def size
      to_cgsize
    end

    def z_position
      if @view
        @view.layer.zPosition
      end
    end

    def to_cgpoint
      CGPointMake(@left, @top)
    end

    def to_cgsize
      CGSizeMake(@width, @height)
    end

    def to_cgrect
      CGRectMake(@left,@top, @width, @height)
    end
    def to_a
      [@left, @top, @width, @height]
    end
    def to_h
      {left: @left, top: @top, width: @width, height: @height}
    end

    def inspect
      format = '#0.#'
      s = "Rect {l: #{RMQ.format.numeric(left, format)}"
      s << ", t: #{RMQ.format.numeric(top, format)}"
      s << ", w: #{RMQ.format.numeric(width, format)}"
      s << ", h: #{RMQ.format.numeric(height, format)}}"
      s
    end

    def log
      def i_f_to_s(int_or_float)
        if int_or_float % 1 == 0
          int_or_float.to_i.to_s
        else
          int_or_float.to_s
        end
      end

      l = i_f_to_s(left.round(2)).ljust(5)
      t = i_f_to_s(top.round(2)).rjust(5)
      w = i_f_to_s(width.round(2)).ljust(5)
      h = i_f_to_s(height.round(2)).ljust(5)
      b = i_f_to_s(bottom.round(2)).rjust(5)
      r = i_f_to_s(right.round(2)).ljust(5)
      fr = i_f_to_s(from_right.round(2)).ljust(5)
      fb = i_f_to_s(from_bottom.round(2)).rjust(5)

      ww = i_f_to_s(rmq.app.window.size.width.round(2))
      wh = i_f_to_s(rmq.app.window.size.height.round(2))

      if @view && (sv = @view.superview)
        sw = i_f_to_s(sv.size.width.round(2))
        sh = i_f_to_s(sv.size.height.round(2))
      end

      out = %(
 *****************---*******---**************************  
 *                 |         |                          *    window
 *          #{ t} top        |                          *    {w: #{ww}, h: #{wh}}
 *                 |         |                          *
 *                ---        |                          *    superview 
 *            ***************|*****   ---               *    {w: #{sw}, h: #{sh}} 
 *            *              |    *    |                *
 *            *              |    *    |                *
 *            *     #{ b} bottom  *    |                *    view
 *    #{ l}   *              |    *    |                *    {l: #{l.strip}, t: #{t.strip},
 *|-- left --|*              |    *    |                *     w: #{w.strip}, h: #{h.strip}}
 *            *              |    * height #{ h}        *
 *            *              |    *    |                *    z_order: #{z_order}
 *            *       #{ r}  |    *    |                *    z_position: #{z_position}
 *|------------------ right -+---|*    |                *
 *            *              |    *    |    #{fr}       *
 *            *              |    * |--+--from_right---|*
 *            *             ---   *    |                *
 *            ***************---***   ---               *
 *                            |                         *
 *            |------ width - + --|                     *
 *                    #{ w}   |                         *
 *                            |                         *
 *                            |                         *
 *                  #{fb} from_bottom                   *
 *                            |                         *
 *                           ---                        *
 ********************************************************
)
      puts out
    end

  end
end
