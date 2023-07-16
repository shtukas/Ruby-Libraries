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

class Solingen

    # Solingen::repository()
    def self.repository()
        "#{ENV["HOME"]}/Galaxy/DataHub/Solingen"
    end

    # Solingen::mikuTypeUUIDs()
    def self.mikuTypeUUIDs()
        
    end
end
