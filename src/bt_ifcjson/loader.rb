#  loader.rb
#
#  Copyright 2020 Jan Brouwer <jan@brewsky.nl>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#

module BimTools  
  module IfcJson
  
    PLATFORM_IS_OSX     = ( Object::RUBY_PLATFORM =~ /darwin/i ) ? true : false
    PLATFORM_IS_WINDOWS = !PLATFORM_IS_OSX
    PLUGIN_PATH_IMAGE = File.join(PLUGIN_PATH, 'images')
    
    # set icon file type
    if Sketchup.version_number < 1600000000
      ICON_TYPE = '.png'
    elsif PLATFORM_IS_WINDOWS
      ICON_TYPE = '.svg'
    else # OSX
      ICON_TYPE = '.pdf'
    end

    require File.join(PLUGIN_PATH, 'exporter.rb')

    toolbar = UI::Toolbar.new "ifcJSON"
    btn_ifc_export = UI::Command.new('Export model to IFC') {
      IfcJsonExporter.new( Sketchup.active_model.entities )
    }
    btn_ifc_export.small_icon = File.join(PLUGIN_PATH_IMAGE, "IfcExport" + ICON_TYPE)
    btn_ifc_export.large_icon = File.join(PLUGIN_PATH_IMAGE, "IfcExport" + ICON_TYPE)
    btn_ifc_export.tooltip = 'Export model to ifcJSON'
    btn_ifc_export.status_bar_text = 'Export model to ifcJSON'

    toolbar.add_item btn_ifc_export
    toolbar.show
    
    # export selection from context menu
    UI.add_context_menu_handler do |context_menu|
      selection = Sketchup.active_model.selection
      unless selection.empty?
        context_menu.add_item( 'Export selection to ifcJSON' ) {
          IfcJsonExporter.new( selection )
        }
      end
    end
  end # module IfcJson
end # module BimTools
