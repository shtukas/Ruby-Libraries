# encoding: utf-8

=begin
    Solingen::mikuTypeUUIDs(mikuType): Array[String]
    Solingen::mikuTypeFilepaths(mikuType): Array[Filepath] # returns blade filepaths for the mikuType 
    Solingen::registerBlade(filepath): Ensures that the uuid is registered in the right mikuType folder.
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

# create table energy (uuid string primary key, mikuType string, item string);

class BladesGI

    # BladesGI::itemOrNull(uuid)
    def self.itemOrNull(uuid)
        BladeUtils::itemOrNull2(uuid)
    end

    # BladesGI::init(mikuType, uuid)
    def self.init(mikuType, uuid)
        Blades::init(mikuType, uuid)
    end

    # BladesGI::setAttribute2(uuid, attribute_name, value)
    def self.setAttribute2(uuid, attribute_name, value)
        Blades::setAttribute2(uuid, attribute_name, value)
    end

    # BladesGI::destroy(uuid)
    def self.destroy(uuid)
        Blades::destroy(uuid)
    end

    # BladesGI::mikuType(mikuType)
    def self.mikuType(mikuType)

        # Before being returned to the called as an array of items a mikuType is an object in the XCache of the form
        # MikuType {
        #     "items"      => Array[Item]
        #     "expiration" => Integer
        #     "filepaths"  => Array[filepath]
        # }

        buildStructure = lambda {|mikuType|
            puts "building a new structure for #{mikuType}"
            items = []
            filepaths = []
            Blades::filepathsEnumerator().each{|filepath|
                item = BladeUtils::itemOrNull1(filepath)
                next if item.nil?
                if item["mikuType"] == mikuType then
                    items << item
                    filepaths << filepath
                end
            }
            {
                "items"      => items,
                "expiration" => Time.new.to_i + 86400,
                "filepaths"  => filepaths
            }
        }

        isValid = lambda {|structure|
            return false if (Time.new.to_i > structure["expiration"])
            return false if structure["filepaths"].any?{|filepath| !File.exist?(filepath) }
            true
        }

        key = "9e9134f6-d7b2-48db-84df-2eef84496453:#{mikuType}"
        structure = XCache::getOrNull(key)

        if structure.nil? then
            structure = buildStructure.call(mikuType)
            XCache::set(key, JSON.generate(structure))
            return structure["items"]
        end

        structure = JSON.parse(structure)

        if isValid.call(structure) then
            return structure["items"]
        end

        structure = buildStructure.call(mikuType)
        XCache::set(key, JSON.generate(structure))
        structure["items"]
    end

    # BladesGI::all()
    def self.all()
        Blades::filepathsEnumerator()
        .to_a
        .map{|filepath| BladeUtils::itemOrNull1(filepath) }
        .compact
    end

    # BladesGI::putDatablob2(uuid, datablob)
    def self.putDatablob2(uuid, datablob)
        Blades::putDatablob2(uuid, datablob)
    end
end

