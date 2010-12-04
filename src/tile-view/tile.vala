/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

using Gtk;

namespace UI.Widgets
{
  public class Tile: Table
  {
    private Button add_remove_button;
    private Box button_box;

    private Label title;
    private Image tile_image;
    private WrapLabel description;
    private Label sub_description;
    private Image add_image;
    private Image remove_image;

    private int icon_size;

    public unowned TileView owner { get; set; }
    public AbstractTileObject owned_object { get; private set; }
    public bool last { get; private set; }

    public signal void active_changed ();

    public Tile (AbstractTileObject obj, int icon_size)
    {
      GLib.Object (n_rows: 3, n_columns: 3, homogeneous: false);

      IconSize isz = IconSize.SMALL_TOOLBAR;
      add_image = new Image.from_stock (obj.add_button_stock, isz);
      remove_image = new Image.from_stock (obj.remove_button_stock, isz);
      
      owned_object = obj;
      owned_object.icon_updated.connect (this.set_image);
      owned_object.text_updated.connect (this.set_text);
      owned_object.buttons_updated.connect (this.update_buttons);
      owned_object.notify["enabled"].connect (this.update_state);

      this.icon_size = icon_size;

      build_tile ();
    }

    private void build_tile ()
    {
      this.border_width = 5;
      this.row_spacing = 1;
      this.column_spacing = 5;

      tile_image = new Image ();

      tile_image.yalign = 0.0f;
      this.attach (tile_image, 0, 1, 0, 3,
                   AttachOptions.SHRINK,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   0, 0);

      title = new Label ("");
      title.xalign = 0.0f;
      this.attach (title, 1, 3, 0, 1,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   0, 0);
      title.show ();

      description = new WrapLabel ();
      this.attach (description, 1, 3, 1, 2,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   0, 0);
      description.show ();

      sub_description = new Label ("");
      sub_description.xalign = 0.0f;
      this.attach (sub_description, 1, 2, 2, 3,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   0, 4);
      sub_description.show ();

      set_text ();

      button_box = new HBox (false, 3);

      add_remove_button = new Button ();
      // FIXME: could cause leak!
      add_remove_button.clicked.connect (() => { this.active_changed (); });

      update_buttons ();

      this.attach (button_box, 2, 3, 2, 3,
                   AttachOptions.SHRINK,
                   AttachOptions.FILL | AttachOptions.EXPAND,
                   0, 0);

      this.show ();
      update_state ();
    }
    
    protected override void realize ()
    {
      this.set_flags (WidgetFlags.NO_WINDOW);
      this.set_window (this.parent.get_window ());
      base.realize ();
    }

    protected override bool expose_event (Gdk.EventExpose event)
    {
      if (this.get_state () == StateType.SELECTED)
      {
        bool had_focus = Gtk.WidgetFlags.HAS_FOCUS in this.get_flags ();
        // fool theme engine to use proper bg color
        if (!had_focus) this.set_flags (Gtk.WidgetFlags.HAS_FOCUS);
        Gtk.paint_flat_box (this.style, event.window, this.get_state (),
                            ShadowType.NONE, event.area, this, "cell_odd",
                            this.allocation.x,
                            this.allocation.y,
                            this.allocation.width,
                            this.allocation.height - (last ? 0 : 1));
        if (!had_focus) this.unset_flags (Gtk.WidgetFlags.HAS_FOCUS);
      }

      if (!last)
      {
        Gtk.paint_hline (this.style, event.window, StateType.NORMAL,
                         event.area, this, null,
                         this.allocation.x,
                         this.allocation.x + this.allocation.width,
                         this.allocation.y + this.allocation.height - 1);
      }

      return base.expose_event (event);
    }

    public void update_state ()
    {
      bool enabled = owned_object.enabled;
      bool is_selected = this.get_state () == StateType.SELECTED;
      bool sensitive = enabled || (!enabled && is_selected);

      set_image ();

      title.set_sensitive (sensitive);
      description.set_sensitive (sensitive);
      description.wrap = is_selected;
      sub_description.set_visible (is_selected);

      add_remove_button.set_image (enabled ? remove_image : add_image);
      add_remove_button.set_tooltip_markup (enabled ?
        owned_object.remove_button_tooltip : owned_object.add_button_tooltip);
    }

    public void set_selected (bool selected)
    {
      this.set_state (selected ? StateType.SELECTED : StateType.NORMAL);

      if (selected)
      {
        button_box.show_all ();
      }
      else
      {
        button_box.hide ();
      }

      button_box.set_state (StateType.NORMAL);
      this.update_state ();
      this.queue_resize ();
    }

    private void set_image ()
    {
      Gdk.Pixbuf pixbuf = null;
      if (owned_object.force_pixbuf != null)
      {
        pixbuf = owned_object.force_pixbuf;
        if (pixbuf.get_width () != icon_size 
          || pixbuf.get_height () != icon_size)
        {
          pixbuf = pixbuf.scale_simple (icon_size, icon_size,
                                        Gdk.InterpType.BILINEAR);
        }
      }
      else
      {
        try
        {
#if VALA_0_12
          Gdk.Pixbuf temp_pb;
#else
          unowned Gdk.Pixbuf temp_pb;
#endif
          unowned IconTheme it = IconTheme.get_default ();
          try
          {
            temp_pb = it.load_icon (owned_object.icon,
                                    icon_size,
                                    IconLookupFlags.FORCE_SIZE);
          }
          catch (GLib.Error err)
          {
            temp_pb = it.load_icon (Gtk.STOCK_FILE,
                                    icon_size,
                                    IconLookupFlags.FORCE_SIZE);
          }
          pixbuf = temp_pb.copy ();
#if VALA_0_12
#else
          temp_pb.unref (); // careful here!
#endif
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
      }

      tile_image.set_sensitive (owned_object.enabled); // monochromatize

      tile_image.set_from_pixbuf (pixbuf);
      tile_image.show ();
    }

    private void set_text ()
    {
      title.set_markup (Markup.printf_escaped ("<b>%s</b>", owned_object.name));
      description.set_text (owned_object.description);

      if (owned_object.sub_description_title != "" &&
          owned_object.sub_description_text != "")
      {
        sub_description.set_markup (Markup.printf_escaped (
          "<small><b>%s</b> <i>%s</i></small>",
            owned_object.sub_description_title,
            owned_object.sub_description_text
          )
        );
      }
    }

    private void update_buttons ()
    {
      List<weak Widget> children = button_box.get_children ();
      foreach (weak Widget w in children)
      {
        button_box.remove (w);
      }

      foreach (weak Widget w in owned_object.get_extra_buttons ())
      {
        button_box.pack_start (w, false, false, 0);
        w.show ();
      }

      if (owned_object.show_action_button && add_remove_button != null)
      {
        button_box.pack_start (add_remove_button, false, false, 0);
      }
    }
  }
}