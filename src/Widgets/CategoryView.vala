// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//  
//  Copyright (C) 2011 Giulio Collura
// 
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

using Gtk;
using Gee;

using Slingshot.Backend;

namespace Slingshot.Widgets {

    public class CategoryView : EventBox {

        private Gtk.Grid container;
        public Sidebar category_switcher;
        public VSeparator separator;
        public Widgets.Grid app_view;
        private Layout layout;
        public Switcher switcher;
        private SlingshotView view;
        private Label empty_cat_label;

        private Gtk.Grid page_switcher;

        private const string ALL_APPLICATIONS = _("All Applications");
        private const string NEW_FILTER = _("Create a new Filter");
        private int current_position = 0;
        private bool from_category = false;
        
        private HashMap<int, string> category_ids = new HashMap<int, string> ();
        
        public CategoryView (SlingshotView parent) {

            view = parent;

            set_visible_window (false);
            setup_ui ();
            connect_events ();

            category_switcher.selected = 0;

            set_size_request (view.columns*130 + 17, view.view_height);

        }

        private void setup_ui () {

            container = new Gtk.Grid ();

            var empty_cat_text = _("This Category is Empty");
            empty_cat_label = new Label ("<b><span size=\"larger\">" + empty_cat_text + "</span></b>");
            empty_cat_label.use_markup = true;

            category_switcher = new Sidebar ();
            category_switcher.can_focus = false;

            // Fill the sidebar
            int n = 0;
            
            var categories = new GLib.List<string> ();
            foreach (string cat_name in view.apps.keys)
                categories.append (cat_name);
                
            categories.sort ( (a, b) => {
                if (a > b)
                    return 1;
                else
                    return -1;
            });
            foreach (string cat_name in categories) {
                category_ids.set (n, cat_name);
            
                switch (cat_name) {
                    case "Accessories":
                        category_switcher.add_category (_("Accessories"));
                    break;
                    case "Universal Access":
                        category_switcher.add_category (_("Universal Access"));
                    break;
                    case "Graphics":
                        category_switcher.add_category (_("Graphics"));
                    break;
                    case "Development":
                        category_switcher.add_category (_("Development"));
                    break;
                    case "Other":
                        category_switcher.add_category (_("Other"));
                    break;
                    case "Internet":
                        category_switcher.add_category (_("Internet"));
                    break;
                    case "System":
                        category_switcher.add_category (_("System"));
                    break;
                    case "Multimedia":
                        category_switcher.add_category (_("Multimedia"));
                    break;
                    case "Games":
                        category_switcher.add_category (_("Games"));
                    break;
                    case "Office":
                        category_switcher.add_category (_("Office"));
                    break;
                }
                n++;
            }

            separator = new VSeparator ();

            layout = new Layout (null, null);

            app_view = new Widgets.Grid (view.rows, view.columns - 1);
            layout.put (app_view, 0, 0);
            layout.put (empty_cat_label, view.columns*130, view.rows * 130 / 2);
            layout.set_hexpand (true);
            layout.set_vexpand (true);

            // Create the page switcher
            switcher = new Switcher ();

            // A bottom widget to keep the page switcher center
            page_switcher = new Gtk.Grid ();
            var bottom_separator1 = new Label (""); // A fake label
            bottom_separator1.set_hexpand(true);
            var bottom_separator2 = new Label (""); // A fake label
            bottom_separator2.set_hexpand(true);
            page_switcher.attach (bottom_separator1, 0, 0, 1, 1);
            page_switcher.attach (switcher, 1, 0, 1, 1);
            page_switcher.attach (bottom_separator2, 2, 0, 1, 1);

            container.attach (category_switcher, 0, 0, 1, 1);
            container.attach (separator, 1, 0, 1, 1);
            container.attach (layout, 2, 0, 1, 1);

            add (container);

        }

        private void connect_events () { 

            category_switcher.selection_changed.connect ((name, nth) => {
            
                view.reset_category_focus ();
                
                string category = category_ids.get (nth);
                
                if (category == ALL_APPLICATIONS)
                    show_all_apps ();
                else
                    show_filtered_apps (category);

            });
  
            layout.scroll_event.connect ((event) => {
                switch (event.direction.to_string ()) {
                    case "GDK_SCROLL_UP":
                    case "GDK_SCROLL_LEFT":
                        switcher.set_active (switcher.active - 1);
                        break;
                    case "GDK_SCROLL_DOWN":
                    case "GDK_SCROLL_RIGHT":
                        switcher.set_active (switcher.active + 1);
                        break;
                }
                return false;
            });

            app_view.new_page.connect ((page) => {
                if (switcher.size == 0)
                    switcher.append ("1");
                switcher.append (page);
                
                /* Prevents pages from changing */
                from_category = true;
            });

            switcher.active_changed.connect (() => {
                if (from_category || switcher.active - switcher.old_active == 0) {
                    from_category = false;
                    return;
                }

                if (switcher.active > switcher.old_active) {
                    page_right (switcher.active - switcher.old_active);
                }
                else
                {
                    page_left (switcher.old_active - switcher.active);
                }
                
                view.searchbar.grab_focus (); // this is because otherwise focus isn't the current page
            });

        }

        private void add_app (App app) {

            var app_entry = new AppEntry (app);
            app_entry.app_launched.connect (view.hide_slingshot);
            app_view.append (app_entry);
            app_entry.show_all ();

        }

        private void show_all_apps () {

            app_view.clear ();

            foreach (App app in view.app_system.get_apps_by_name ())
                add_app (app);

            layout.move (app_view, 0, 0);
            current_position = 0;

        }

        private void show_filtered_apps (string category) {

            switcher.clear_children ();
            app_view.clear ();

            if (category == NEW_FILTER) {

                // This needs to be implemented
                layout.move (empty_cat_label, (view.columns - 2)*130/2, view.rows*130 / 2);

            } else {
    
                if (view.apps[category].size == 0) {
                    layout.move (empty_cat_label, (view.columns - 2)*130/2, view.rows*130 / 2);
                } else {
                    layout.move (empty_cat_label, view.columns*130, view.rows*130 / 2);
                    foreach (App app in view.apps[category])
                        add_app (app);
                }

            }
            switcher.set_active (0);

            layout.move (app_view, 0, 0);
            current_position = 0;

        }

        public int page_left (int step = 1) {

            int columns = app_view.get_page_columns ();

            if (current_position < 0) {
                int count = 0;
                int val = columns*130*step / 10;
                Timeout.add (20 / (step*step*2), () => {

                    if (count >= columns*130*step) {
                        count = 0;
                        return false;
                    }
                    layout.move (app_view, current_position + val, 0);
                    current_position += val;
                    count += val;
                    return true;

                }, Priority.DEFAULT_IDLE);
              /*
                layout.move (app_view, current_position + columns*130*step, 0);
                return current_position += columns*130*step;
                */
            }
            
            return 0;
        }

        public int page_right (int step = 1) {

            int columns = app_view.get_page_columns ();
            int pages = app_view.get_n_pages ();

            if ((- current_position) < (columns*(pages - 1)*130)) {
                int count = 0;
                int val = columns*130*step / 10;
                Timeout.add(20 / (2*step*step), () => {
                    
                    if (count >= columns*130*step) {
                        count = 0;
                        return false;
                    }
    
                    layout.move (app_view, current_position - val, 0);
                    current_position -= val;
                    count += val;
                    return true;

                }, Priority.DEFAULT_IDLE);
            }

            /*int columns = app_view.get_page_columns ();
            int pages = app_view.get_n_pages ();
            
            if ((- current_position) < (columns*(pages - 1)*130)) {

                layout.move (app_view, current_position - columns*130*step, 0);
                return current_position -= columns*130*step;
            }*/

            return 0;
        }

        public void show_page_switcher (bool show) {

            if (page_switcher.get_parent () == null)
                view.bottom.attach (page_switcher, 1, 0, 1, 1);
            
            if (show)
                page_switcher.show_all ();
            else
                page_switcher.hide ();

        }

    }

}
