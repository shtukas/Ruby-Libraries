# encoding: utf-8

# MikuTypes is a blade management library.
# It can be used to manage collections of blades with a "mikuType" attribute.
# Was introduced when we decided to commit to blades for Catalyst and Nyx.
# It also handle reconciliations and mergings

=begin

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

class MikuTypes

    # MikuTypes::repositoryRoots()
    def self.repositoryRoots()
        # This function needs to be reimplemented by clients, it return an array 
        # of file system locations where blades are looked for.
        raise "MikuTypes::repositoryRoots is not implemented yet."
    end

    # MikuTypes::bladesEnumerator(roots = nil)
    def self.bladesEnumerator(roots = nil)
        # Enumerate the blade filepaths
        roots = roots || MikuTypes::repositoryRoots()
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

    # MikuTypes::mikuTypedBlades(roots = nil)
    def self.mikuTypedBlades(roots = nil)
        # Enumerate the blade filepaths with a "mikuType" attribute
        Enumerator.new do |filepaths|
            MikuTypes::bladesEnumerator(roots).each{|filepath|
                if !Blades::getAttributeOrNull(filepath, "mikuType").nil? then
                    filepaths << filepath
                end
            }
        end
    end

    # MikuTypes::scan()
    def self.scan()
        # scans the file system in search of .blade files with a "mikuType" attribute
    end
end
