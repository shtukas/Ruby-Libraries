# encoding: utf-8

=begin
MikuTypes
    MikuTypesCore::bladesEnumerator(roots)
    MikuTypesCore::mikuTypedBladesEnumerator(roots)
    MikuTypesCore::mikuTypeBladesEnumerator(roots, mikuType)
    MikuTypesCore::scan(roots)
    MikuTypesCore::scanMonitor(roots, periodInSeconds)
    MikuTypesCore::mikuTypeFilepaths(mikuType)
=end

# MikuTypes is a blade management library.
# It can be used to manage collections of blades with a "mikuType" attribute. We also expect a "uuid" attribute.
# Was introduced when we decided to commit to blades for Catalyst and Nyx.
# It also handle reconciliations and mergings

=begin

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

    Blades::decideInitLocation(uuid)
    Blades::locateBladeUsingUUID(uuid)

    Blades::init(uuid)
    Blades::setAttribute(uuid, attribute_name, value)
    Blades::getAttributeOrNull(uuid, attribute_name)
    Blades::addToSet(uuid, set_id, element_id, value)
    Blades::removeFromSet(uuid, set_id, element_id)
    Blades::putDatablob(uuid, key, datablob)
    Blades::getDatablobOrNull(uuid, key)
=end

require_relative "XCache.rb"

# -----------------------------------------------------------------------------------

class MikuTypesCore

    # MikuTypesCore::bladesEnumerator(roots)
    def self.bladesEnumerator(roots)
        # Enumerate the blade filepaths
        roots = roots || MikuTypesCore::repositoryRoots()
        Enumerator.new do |filepaths|
            roots.each{|root|
                if File.exist?(root) then
                    begin
                        Find.find(root) do |path|
                            next if !File.file?(path)
                            filepath = path
                            if filepath[-6, 6] == ".blade" then
                                filepaths << path
                            end
                        end
                    rescue
                    end
                end
            }
        end
    end

    # MikuTypesCore::mikuTypedBladesEnumerator(roots)
    def self.mikuTypedBladesEnumerator(roots)
        # Enumerate the blade filepaths with a "mikuType" attribute
        Enumerator.new do |filepaths|
            MikuTypesCore::bladesEnumerator(roots).each{|filepath|
                if !Blades::getAttributeOrNull(filepath, "mikuType").nil? then
                    filepaths << filepath
                end
            }
        end
    end

    # MikuTypesCore::mikuTypeBladesEnumerator(roots, mikuType)
    def self.mikuTypeBladesEnumerator(roots, mikuType)
        # Enumerate the blade filepaths with a "mikuType" attribute
        Enumerator.new do |filepaths|
            MikuTypesCore::mikuTypedBladesEnumerator(roots).each{|filepath|
                if Blades::getAttributeOrNull(filepath, "mikuType") == mikuType then
                    filepaths << filepath
                end
            }
        end
    end

    # MikuTypesCore::registerFilepath(filepath1)
    def self.registerFilepath(filepath1)
        mikuType = Blades::getAttributeOrNull(filepath1, "mikuType")
        if mikuType.nil? then
            raise "(error: 2032bbb5-aafa-4dba-b587-cdb461b098c9) filepath: #{filepath1} (this should not have happened because we are expecting a mikutyped blade)"
        end

        uuid = Blades::getAttributeOrNull(filepath1, "uuid")
        if uuid.nil? then
            raise "(error: 70bee4c7-9909-447a-90bf-fee13d690356) filepath: #{filepath1}, uuid: #{uuid} (this should not have happened)"
        end

        mtx01 = XCache::getOrNull("922805bf-bd46-41f0-855b-3b3a89dcf598:#{mikuType}")
        if mtx01.nil? then
            mtx01 = {}
        else
            mtx01 = JSON.parse(mtx01)
        end

        filepath0 = mtx01[uuid]

        if filepath0 and File.exist?(filepath0) and filepath1 != filepath0 then
            # We have two blades with the same uuid. We might want to merge them.
            puts "We have two blades with the same uuid. We might want to merge them."
            puts "filepath0: #{filepath0}"
            puts "filepath1: #{filepath1}"
            puts "MikuTypes doesn't yet know how to do that"
            raise "method not implemented"
        end

        mtx01[uuid] = filepath1
        XCache::set("922805bf-bd46-41f0-855b-3b3a89dcf598:#{mikuType}", JSON.generate(mtx01))
    end

    # MikuTypesCore::scan(roots)
    def self.scan(roots)
        # scans the file system in search of .blade files and update the cache
        MikuTypesCore::mikuTypedBladesEnumerator(roots).each{|filepath|
            MikuTypesCore::registerFilepath(filepath)
        }
    end

    # MikuTypesCore::scanMonitor(roots, periodInSeconds)
    def self.scanMonitor(roots, periodInSeconds)
        Thread.new {
            sleep 10
            loop {
                MikuTypesCore::scan(roots)
                sleep periodInSeconds
            }
        }
    end

    # MikuTypesCore::mikuTypeFilepaths(mikuType)
    def self.mikuTypeFilepaths(mikuType)
        mtx01 = XCache::getOrNull("922805bf-bd46-41f0-855b-3b3a89dcf598:#{mikuType}")
        if mtx01.nil? then
            mtx01 = {}
        else
            mtx01 = JSON.parse(mtx01)
        end
        mtx01.values
    end
end
