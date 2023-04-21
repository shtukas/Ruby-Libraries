# encoding: utf-8

# MikuTypes is a blade management library.
# It can be used to manage collections of blades with a "mikuType" attribute.
# Was introduced when we decided to commit to blades for Catalyst and Nyx.
# It also handle reconciliations and mergings

=begin

The main data type is MTx01: Map[uuid:String, filepath:String]
This is just a map from uuids to the blade filepaths. That map is stored in XCache.

We then have such a map per miku type. Given a miku type we maintain that map and store it in XCache.

Calling for a mikuType will return the blades that are known and haven't moved since the last time
the collection was indexed. If the client wants a proper enumeration of all teh blade, they should use


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

    # MikuTypesCore::mikuTypeEnumerator(roots, mikuType)
    def self.mikuTypeEnumerator(roots, mikuType)
        # Enumerate the blade filepaths with a "mikuType" attribute
        Enumerator.new do |filepaths|
            MikuTypesCore::mikuTypedBladesEnumerator(roots).each{|filepath|
                if Blades::getAttributeOrNull(filepath, "mikuType") == mikuType then
                    filepaths << filepath
                end
            }
        end
    end

    # MikuTypesCore::scan(roots)
    def self.scan(roots)
        # scans the file system in search of .blade files with a "mikuType" attribute
    end
end
