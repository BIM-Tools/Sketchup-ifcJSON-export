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
    require File.join(PLUGIN_PATH, "obj.rb")
    require File.join(PLUGIN_PATH, "IfcGloballyUniqueId.rb")
    class IfcJsonExporter
      attr_accessor :root_objects
      def initialize( entities )
        @id_objects = []
        @ifc_objects = Array.new
        @geometry = Array.new

        # get timestamp
        time = Time.new
        timestamp = time.strftime("%Y-%m-%dT%H:%M:%S")
      
        # get originating_system
        originating_system = "SketchUp"
        if Sketchup.is_pro?
          originating_system = originating_system << " Pro"
        end
        number = Sketchup.version_number/100000000.floor
        originating_system = originating_system << " 20" << number.to_s
        originating_system = originating_system << " (" << Sketchup.version << ")"

        # get preprosessor versions
        preprocessor_version = "IFC-manager for SketchUp (#{VERSION})"

        @root_objects = {
          "type" => "ifcjson",
          "schema" => "IFC.JSON5a",
          "description" => "ViewDefinition [CoordinationView]",
          "timeStamp" => timestamp,
          "preprocessorVersion" => preprocessor_version,
          "originatingSystem" => originating_system,
          "data" => []
        }
        export_path = get_export_path()
  
        # only start export if path is valid
        unless export_path.nil?
          @root_objects["data"].concat( collect_objects( entities, Geom::Transformation.new() )[0] )
        end

        @root_objects["data"].concat( @ifc_objects  )
        @root_objects["data"].concat( @geometry  )

        to_file( export_path )
      end # def initialize

      def collect_objects(entities, parent_transformation, parent_guid=nil)
        child_objects = Array.new()
        faces = Array.new()
        entities.each do |entity|
          if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
            object_hash = Hash.new
            # object_hash["Name"] = entity.definition.name
            transformation = entity.transformation * parent_transformation
            object_hash.merge! get_properties(entity)

            # create unique guid
            guid = BimTools::IfcManager::IfcGloballyUniqueId.new(object_hash["globalId"])
            if parent_guid
              guid.set_parent_guid( parent_guid )
            end
            object_hash["globalId"] = guid.to_json()

            # add volume if object is manifold
            if entity.volume > 0
              object_hash["volume"] = entity.volume
            end

            isDecomposedBy, child_faces = collect_objects(entity.definition.entities, transformation, guid.to_s)

            unless isDecomposedBy.empty?
              object_hash["isDecomposedBy"] = isDecomposedBy
            end

            # only add representation if there are any faces
            if child_faces.length > 0
              obj = OBJ.new(child_faces, parent_transformation)
              representation_guid = BimTools::IfcManager::IfcGloballyUniqueId.new().to_json
              object_hash["representations"] = [
                {
                  "type": "ShapeRepresentation",
                  "ref": representation_guid
                }
              ]
              # {
              #   "Class": "ProductDefinitionShape",
              #   "Representations": [
              #     {
              #       "Class": "ShapeRepresentation",
              #       "RepresentationIdentifier": "Body",
              #       "RepresentationType": "OBJ",
              #       "Items": [obj.to_s]
              #     }
              #   ]
              # }

              # add geometry as seperate objects at the end of the file
              @geometry << {
                "type" => "ShapeRepresentation",
                "globalId" => representation_guid,
                "representationIdentifier" => "Body",
                "representationType" => "OBJ",
                "items" => [obj.to_s]
              }
            end
            if object_hash["type"]
              if !@id_objects.include? object_hash["globalId"]
                @ifc_objects << object_hash
              end
              object_hash = {
                "type" => object_hash["type"],
                "globalId" => object_hash["globalId"]
              }
              child_objects << object_hash
            end
          elsif entity.is_a?(Sketchup::Face)
            faces << entity
          end
        end
        return child_objects, faces
      end # def collect_objects

      def get_properties(entity)
        properties = Hash.new()
        definition = entity.definition
        ifc_type = definition.get_attribute "AppliedSchemaTypes", "IFC 2x3"
        if ifc_type

          # hack to remove IfcWallStandardCase
          if ifc_type == "IfcWallStandardCase"
            ifc_type = "IfcWall"
          end

          # Strip "Ifc" prefix
          properties["type"] = ifc_type[3..-1]

          # Collect IFC attributes from Sketchup object
          if definition.attribute_dictionaries['IFC 2x3']
            if props_ifc = definition.attribute_dictionaries['IFC 2x3'].attribute_dictionaries
              props_ifc.each do |prop_dict|
                prop = prop_dict.name
                  
                # get data for objects with additional nesting levels
                # like: path = ["IFC 2x3", "IfcWindow", "OverallWidth", "IfcPositiveLengthMeasure", "IfcLengthMeasure"]
                val_dict = return_value_dict( prop_dict )
                if val_dict["value"] && !val_dict["is_hidden"]
                  value = val_dict["value"]
                  if value != "" 
                    property_name = prop_dict.name[0].downcase + prop_dict.name[1..-1]
                    properties[property_name] = val_dict["value"]
                  end
                end
              end
            end
          end
        end
        return properties
      end # get_properties
    
      # find the dictionary containing "value" field
      def return_value_dict( dict )
        
        # if a field "value" exists then we are at the data level and data can be retrieved, otherwise dig deeper
        if dict.keys.include?("value")
          return dict
        else
          dict.attribute_dictionaries.each do | sub_dict |
            unless sub_dict.name == "instanceAttributes"
              return return_value_dict( sub_dict )
            end
          end
        end
      end # def return_value_dict

      def get_export_path()
  
        # get model current path
        model_path = Sketchup.active_model.path
        dirname = File.dirname(model_path)
  
        # get model file name
        if File.basename(model_path) == ""
          filename = "Untitled.json"
        else
          filename = File.basename(model_path, ".*") + ".json"
        end
  
        # enter save path
        UI.savepanel('Export Model', dirname, filename)
      end # get_export_path
    
      def to_file( file_path )
        File.open( file_path,"w" ) do | file |
          file.write( @root_objects.to_json )
        end
      end # def to_file
    end # IfcJsonExporter
  end # module IfcJson
  end # module BimTools
    