#  exporter.rb
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
    class OBJ
      def initialize( faces, transformation )
        @vertices = Array.new
        @polygons = Array.new
        faces.each do |face|
          if face.is_a? Sketchup::Face

            # get triangulated faces
            mesh = face.mesh(0)
            i = 1
            mesh.polygons.each do |polygon|
              total_points = @vertices.length
              polygon_indexes = Array.new
              polygon_points = mesh.polygon_points_at(i)
              
              polygon_points.each do |polygon_point|
                
                # convert point to obj vertex string
                vertex_position = polygon_point.transform transformation
                @vertices << "v #{vertex_position.to_a.join(" ")}"
              end
              polygon.each do |polygon_index|
                polygon_indexes << polygon_index.abs+total_points
              end

              # convert polygon to obj face string
              @polygons << "f #{polygon_indexes.join(" ")}"
              i += 1
            end
          end
        end
      end # def initialize

      def to_s()
        return @vertices.join("\n") << "\n" << @polygons.join("\n")
      end
    end # OBJ
  end # module IfcJson
end # module BimTools
      