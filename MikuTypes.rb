# encoding: utf-8

=begin
MikuTypes
    MikuTypes::scan()
    MikuTypes::mikuTypeUUIDsCached(mikuType) # Cached
    MikuTypes::uuidEnumeratorForMikuTypeFromDisk(mikuType)
=end

=begin

MikuTypes is a blade management library.
It can be used to manage collections of blades with a "mikuType" attribute. We also expect a "uuid" attribute.
Was introduced when we decided to commit to blades for Catalyst and Nyx.
It also handle reconciliations and mergings

The main data type is MTx01: Map[uuid:String, filepath:String]
This is just a map from uuids to the blade filepaths. That map is stored in XCache.

We then have such a map per miku type. Given a miku type we maintain that map and store it in XCache.

Calling for a mikuType will return the blades that are known and haven't moved since the last time
the collection was indexed. If the client wants a proper enumeration of all the blade, they should use
the scanner.

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

=begin
Blades
    Blades::init(mikuType, uuid)
    Blades::setAttribute2(uuid, attribute_name, value)
    Blades::getAttributeOrNull1(uuid, attribute_name)
    Blades::getMandatoryAttribute1(filepath, attribute_name)
    Blades::addToSet(uuid, set_id, element_id, value)
    Blades::removeFromSet(uuid, set_id, element_id)
    Blades::putDatablob(uuid, key, datablob)
    Blades::getDatablobOrNull(uuid, key)
=end

require_relative "XCache.rb"

# -----------------------------------------------------------------------------------

class MikuTypes

    # MikuTypes::registerFilepath(filepath1)
    def self.registerFilepath(filepath1)
        raise "(error: 2b647489-123c-48ba-a2e7-4e8e79da648e) filepath: #{filepath1}" if !File.exist?(filepath1)
        uuid = Blades::getMandatoryAttribute1(filepath1, "uuid")
        mikuType = Blades::getMandatoryAttribute1(filepath1, "mikuType")
        mtx01 = XCache::getOrNull("blades:mikutype->MTx01:mapping:42da489f9ef7:#{mikuType}")
        if mtx01.nil? then
            mtx01 = {}
        else
            mtx01 = JSON.parse(mtx01)
        end

        filepath0 = mtx01[uuid]

        if filepath0 and (filepath0.class.to_s == "String") and File.exist?(filepath0) and filepath1 != filepath0 and (Blades::getMandatoryAttribute1(filepath0, "uuid") == uuid) then
            # We have two blades with the same uuid. We might want to merge them.
            puts "We have two blades with the same uuid:"
            puts "    - #{filepath0}"
            puts "    - #{filepath1}"
            puts "Merging..."

            db1 = SQLite3::Database.new(filepath1)
            db0 = SQLite3::Database.new(filepath0)

            # We move all the objects from db0 to db1

            db0.busy_timeout = 117
            db0.busy_handler { |count| true }
            db0.results_as_hash = true
            db0.execute("select * from records", []) do |row|
                db1.execute "delete from records where record_uuid=?", [row["record_uuid"]]
                db1.execute "insert into records (record_uuid, operation_unixtime, operation_type, _name_, _data_) values (?, ?, ?, ?, ?)", [row["record_uuid"], row["operation_unixtime"], row["operation_type"], row["_name_"], row["_data_"]]
            end

            db0.close
            db1.close

            # We delete filepath0 and we rename/keep filepath1

            FileUtils.rm(filepath0)
            filepath1 = Blades::rename(filepath1)
            puts "New file: #{filepath1}"

        end

        #puts "registering:"
        #puts "    uuid     : #{uuid}"
        #puts "    filepath1: #{filepath1}"
        #puts "    mikuType : #{mikuType}"

        mtx01[uuid] = filepath1
        XCache::set("blades:uuid->filepath:mapping:7239cf3f7b6d:#{uuid}", filepath1)
        XCache::set("blades:mikutype->MTx01:mapping:42da489f9ef7:#{mikuType}", JSON.generate(mtx01))
    end

    # MikuTypes::unregisterFilepath(mikuType, filepath)
    def self.unregisterFilepath(mikuType, filepath)
        mtx01 = XCache::getOrNull("blades:mikutype->MTx01:mapping:42da489f9ef7:#{mikuType}")
        if mtx01.nil? then
            mtx01 = {}
        else
            mtx01 = JSON.parse(mtx01)
        end
        mtx01 = mtx01.to_a.reject{|pair| pair[1] == filepath }.to_h
        XCache::set("blades:mikutype->MTx01:mapping:42da489f9ef7:#{mikuType}", JSON.generate(mtx01))
    end

    # -------------------------------------------

    # MikuTypes::bladesFilepathsEnumerator()
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

    # MikuTypes::bladesFilepathEnumeratorForMikuType(mikuType)
    def self.bladesFilepathEnumeratorForMikuType(mikuType)
        Enumerator.new do |filepaths|
            MikuTypes::bladesFilepathsEnumerator().each{|filepath|
                if Blades::getMandatoryAttribute1(filepath, "mikuType") == mikuType then
                    filepaths << filepath
                end
            }
        end
    end

    # MikuTypes::scan()
    def self.scan()
        # scans the file system in search of blade-* files and update the cache
        MikuTypes::bladesFilepathsEnumerator().each{|filepath|
            #puts "scanning: #{filepath}"
            MikuTypes::registerFilepath(filepath)
        }
    end

    # MikuTypes::mikuTypeUUIDsCached(mikuType) # Array[filepath]
    def self.mikuTypeUUIDsCached(mikuType)
        mtx01 = XCache::getOrNull("blades:mikutype->MTx01:mapping:42da489f9ef7:#{mikuType}")
        if mtx01.nil? then
            mtx01 = {}
        else
            mtx01 = JSON.parse(mtx01)
        end

        mtx01
            .values
            .each{|filepath|
                if File.exist?(filepath) then
                    filepath
                else
                    # The file no longer exists at this location, we need to garbage collect it from the mtx01
                    MikuTypes::unregisterFilepath(mikuType, filepath)
                    nil
                end
            }

        mtx01 = XCache::getOrNull("blades:mikutype->MTx01:mapping:42da489f9ef7:#{mikuType}")
        if mtx01.nil? then
            mtx01 = {}
        else
            mtx01 = JSON.parse(mtx01)
        end
        mtx01.keys
    end

    # MikuTypes::uuidEnumeratorForMikuTypeFromDisk(mikuType)
    def self.uuidEnumeratorForMikuTypeFromDisk(mikuType)
        Enumerator.new do |uuids|
           MikuTypes::bladesFilepathEnumeratorForMikuType(mikuType).each{|filepath|
                uuids << Blades::getMandatoryAttribute1(filepath, "uuid")
           }
        end
    end
end
