# encoding: utf-8

=begin
BLxs

=end

require 'fileutils'
# FileUtils.mkpath '/a/b/c'
# FileUtils.cp(src, dst)
# FileUtils.rm(path_to_image)
# FileUtils.rm_rf(dir)

require 'digest/sha1'
# Digest::SHA1.hexdigest 'foo'
# Digest::SHA1.file(myFile).hexdigest
# Digest::SHA256.hexdigest 'message'  
# Digest::SHA256.file(myFile).hexdigest

require 'json'

require 'securerandom'
# SecureRandom.hex    #=> "eb693ec8252cd630102fd0d0fb7c3485"
# SecureRandom.hex(4) #=> "eb693"
# SecureRandom.uuid   #=> "2d931510-d99f-494a-8c67-87feb05e1594"

require 'find'

require_relative "Blades.rb"

# -----------------------------------------------------------------------------------

=begin
    $LBXs = Array[LBX]
    LBX = Map[attribute, value] # all the values of a given blade
=end

$LBXs = []

class Solingen

    # Solingen::getLBXOrNull(uuid)
    def self.getLBXOrNull(uuid)
        $LBXs.select{|lbx| lbx[uuid]}.first.clone
    end

    # Solingen::replaceLBX(lbx)
    def self.replaceLBX(lbx)
        raise "(error: b8a21fc4-b939-4604-93ba-e979f73d271c) no uuid found in lbx: #{lbx}" if lbx["uuid"].nil?
        raise "(error: b8a21fc4-b939-4604-93ba-e979f73d271c) no uuid found in lbx: #{lbx}" if lbx["mikuType"].nil?
        liveblades = $LBXs.reject{|i| i["uuid"] == lbx["uuid"][0] }
        $LBXs = liveblades + [lbx.clone]
    end

    # Solingen::bladesFilepathsEnumerator()
    def self.bladesFilepathsEnumerator()
        Enumerator.new do |filepaths|
           begin
                Find.find(Blades::bladeRepository()) do |path|
                    next if !File.file?(path)
                    if Blades::isBlade(path) then
                        filepaths << path
                    end
                end
            rescue
            end
        end
    end

    # Solingen::load()
    def self.load()
        puts "Solingen::load()"
        Solingen::bladesFilepathsEnumerator().each{|filepath|
            lbx = {}
            db = SQLite3::Database.new(filepath)
            db.busy_timeout = 117
            db.busy_handler { |count| true }
            db.results_as_hash = true
            # We go through all the values, because the one we want is the last one
            db.execute("select * from records where operation_type=? order by operation_unixtime", ["attribute"]) do |row|
                lbx[row["_name_"]] = JSON.parse(row["_data_"])
            end
            db.close
            $LBXs << lbx
        }
        puts "loaded #{$LBXs.size} blades"
    end

    # ----------------------------------------------
    # Blade Bridge

    # Solingen::init(mikuType, uuid) # String : filepath
    def self.init(mikuType, uuid)
        Blades::init(mikuType, uuid)
        Solingen::replaceLBX({
            "uuid" => uuid,
            "mikuType" => mikuType
        })
    end

    # Solingen::setAttribute2(uuid, attribute_name, value)
    def self.setAttribute2(uuid, attribute_name, value)
        Blades::setAttribute2(uuid, attribute_name, value)
        lbx = Solingen::getLBXOrNull(uuid)
        return if lbx.nil?
        lbx[attribute_name] = value
        Solingen::replaceLBX(lbx)
    end

    # Solingen::getAttributeOrNull2(uuid, attribute_name)
    def self.getAttributeOrNull2(uuid, attribute_name)
        lbx = Solingen::getLBXOrNull(uuid)
        return lbx[attribute_name] if lbx
        nil
    end

    # Solingen::getMandatoryAttribute2(uuid, attribute_name)
    def self.getMandatoryAttribute2(uuid, attribute_name)
        value = Solingen::getAttributeOrNull2(uuid, attribute_name)
        if value.nil? then
            raise "(error: 1052d5d1-6c5b-4b58-b470-22de8b68f4c8) Failing mandatory attribute '#{attribute_name}' at blade uuid: '#{uuid}'"
        end
        value
    end

    # Solingen::addToSet2(uuid, set_name, value_id, value)
    def self.addToSet2(uuid, set_name, value_id, value)
        Blades::addToSet2(uuid, set_name, value_id, value)
    end

    # Solingen::removeFromSet2(uuid, set_name, value_id)
    def self.removeFromSet2(uuid, set_name, value_id)
        Blades::removeFromSet2(uuid, set_name, value_id)
    end

    # Solingen::getSet2(uuid, set_name)
    def self.getSet2(uuid, set_name)
        Blades::getSet2(uuid, set_name)
    end

    # Solingen::putDatablob2(uuid, datablob)  # nhash
    def self.putDatablob2(uuid, datablob)
        Blades::putDatablob2(uuid, datablob)
    end

    # Solingen::getDatablobOrNull2(uuid, nhash)
    def self.getDatablobOrNull2(uuid, nhash)
        Blades::getDatablobOrNull2(uuid, nhash)
    end

    # Solingen::destroy(uuid)
    def self.destroy(uuid)
        Blades::destroy(uuid)
    end

    # ----------------------------------------------
    # Data

    # Solingen::mikuTypes()
    def self.mikuTypes()
        $LBXs.map{|lbx| lbx["mikuType"] }.uniqu.sort
    end

    # Solingen::mikuTypeCount(mikuType)
    def self.mikuTypeCount(mikuType)
        $LBXs.select{|lbx| lbx["mikuType"] == mikuType }.size
    end

    # Solingen::mikuTypeItems(mikuType)
    def self.mikuTypeItems(mikuType)
        $LBXs.select{|lbx| lbx["mikuType"] == mikuType }
    end

    # Solingen::getItemOrNull(uuid)
    def self.getItemOrNull(uuid)
        $LBXs.select{|lbx| lbx["uuid"] == uuid }.first
    end
end

Solingen::load()
