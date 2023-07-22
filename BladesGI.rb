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

$Items3A21470B42A7 = nil

class BladesGx

    # BladesGx::scan_merge()
    def self.scan_merge()
        mapping = {} # uuid => Array[filepath]

        filepaths = Blades::filepathsEnumerator().to_a

        filepaths.each{|filepath|
            uuid = Blades::getMandatoryAttribute1(filepath, "uuid")
            if mapping[uuid].nil? then
                mapping[uuid] = []
            end
            mapping[uuid] = (mapping[uuid] + [filepath]).uniq
        }

        mapping.values.select{|l| l.size > 1 }.each{|l|
            puts JSON.pretty_generate(l)
            l.reduce(l.first){|filepath1, filepath2|
                if filepath1 == filepath2 then
                    filepath1
                else
                    Blades::merge(filepath1, filepath2)
                end
            }
        }

        puts "operation completed with #{filepaths.size} blades"
    end

    # BladesGx::ensureInMemoryData()
    def self.ensureInMemoryData()
        return if !$Items3A21470B42A7.nil?
        puts "BladesGx::ensureInMemoryData()"
        $Items3A21470B42A7 = Blades::filepathsEnumerator().map{|filepath| BladeUtils::itemOrNull1(filepath) }
    end
end

class BladesGI

    # BladesGI::itemOrNull(uuid)
    def self.itemOrNull(uuid)
        # Without caching
        # BladeUtils::itemOrNull2(uuid)
    
        # With caching
        BladesGx::ensureInMemoryData()
        item = $Items3A21470B42A7.select{|item| item["uuid"] == uuid }.first
        return nil if item.nil?
        item.clone
    end

    # BladesGI::init(mikuType, uuid)
    def self.init(mikuType, uuid)
        Blades::init(mikuType, uuid)

        BladesGx::ensureInMemoryData()
        item = BladesGI::itemOrNull(uuid)
        $Items3A21470B42A7 << item
    end

    # BladesGI::setAttribute2(uuid, attribute_name, value)
    def self.setAttribute2(uuid, attribute_name, value)
        Blades::setAttribute2(uuid, attribute_name, value)

        BladesGx::ensureInMemoryData()
        $Items3A21470B42A7 = $Items3A21470B42A7.map{|item|
            if item["uuid"] == uuid then
                item[attribute_name] = value
            end
            item
        }
    end

    # BladesGI::destroy(uuid)
    def self.destroy(uuid)
        Blades::destroy(uuid)

        BladesGx::ensureInMemoryData()
        $Items3A21470B42A7 = $Items3A21470B42A7.select{|item| item["uuid"] != uuid }
    end

    # BladesGI::mikuType(mikuType)
    def self.mikuType(mikuType)
        BladesGx::ensureInMemoryData()
        $Items3A21470B42A7.select{|item| item["mikuType"] == mikuType }.map{|item| item.clone }
    end

    # BladesGI::all()
    def self.all()
        BladesGx::ensureInMemoryData()
        $Items3A21470B42A7.map{|item| item.clone }
    end

    # BladesGI::putDatablob2(uuid, datablob)
    def self.putDatablob2(uuid, datablob)
        Blades::putDatablob2(uuid, datablob)
    end
end
