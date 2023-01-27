
# require "/Users/pascal/Galaxy/LucilleOS/Libraries/Ruby-Libraries/Marbles.rb"

# encoding: UTF-8

require 'sqlite3'

require 'fileutils'

require 'securerandom'
# SecureRandom.hex    #=> "eb693ec8252cd630102fd0d0fb7c3485"
# SecureRandom.hex(4) #=> "1ac4eb69"
# SecureRandom.uuid   #=> "2d931510-d99f-494a-8c67-87feb05e1594"

class MarblesElizabeth

    # @filepath

    def initialize(filepath)
        @filepath = filepath
    end

    def commitBlob(blob)
        Marbles::commitBlob(@filepath, blob)
    end

    def getBlobOrNull(nhash)
        Marbles::getBlobOrNull(@filepath, nhash)
    end

    def filepathToContentHash(filepath)
        "SHA256-#{Digest::SHA256.file(filepath).hexdigest}"
    end

    def readBlobErrorIfNotFound(nhash)
        Marbles::readBlobErrorIfNotFound(@filepath, nhash)
    end

    def datablobCheck(nhash)
        begin
            readBlobErrorIfNotFound(nhash)
            true
        rescue
            false
        end
    end
end

class Marbles

    # Marbles::issueNewEmptyMarbleFile(filepath)
    def self.issueNewEmptyMarbleFile(filepath)
        raise "[5f930502-bb08-4971-8323-27c0c0031477: #{filepath}]" if File.exist?(filepath)

        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.execute "create table _data_ (_key_ string, _value_ blob)", []
        db.close
        nil
    end

    # Marbles::keys(filepath)
    def self.keys(filepath)
        # Some operations may accidentally call those functions on a marble that has died, that create an empty file
        raise "ce1a703e-1104-44a6-b9ea-cc1c2f82bd8d" if !File.exist?(filepath)
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        keys = []
        db.execute("select _key_ from _data_", []) do |row|
            keys << row['_key_']
        end
        db.close
        keys
    end

    # -- key-value store --------------------------------------------------

    # Marbles::kvstore_set(filepath, key, value)
    def self.kvstore_set(filepath, key, value)
        # Some operations may accidentally call those functions on a marble that has died, that create an empty file
        raise "08bf2e43-d8cf-4873-b8e2-82f5c1e7fa2a" if !File.exist?(filepath)
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.transaction 
        db.execute "delete from _data_ where _key_=?", [key]
        db.execute "insert into _data_ (_key_, _value_) values (?,?)", [key, value]
        db.commit 
        db.close
    end

    # Marbles::kvstore_getOrNull(filepath, key)
    def self.kvstore_getOrNull(filepath, key) # binary data or null
        # Some operations may accidentally call those functions on a marble that has died, that create an empty file
        raise "ce1a703e-1104-44a6-b9ea-cc1c2f82bd8d" if !File.exist?(filepath)
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.results_as_hash = true
        value = nil
        db.execute("select * from _data_ where _key_=?", [key]) do |row|
            value = row['_value_']
        end
        db.close
        value
    end

    # Marbles::kvstore_get(filepath, key)
    def self.kvstore_get(filepath, key)
        data = Marbles::kvstore_getOrNull(filepath, key)
        raise "error: 80412ec7-7cb4-4e93-bb3f-e9bb81b22f8e: could not extract mandatory key '#{key}' at filepath '#{filepath}'" if data.nil?
        data
    end

    # Marbles::kvstore_destroy(filepath, key)
    def self.kvstore_destroy(filepath, key)
        # Some operations may accidentally call those functions on a marble that has died, that create an empty file
        raise "80a79666-bc77-4347-a114-93a87738ced0" if !File.exist?(filepath)
        db = SQLite3::Database.new(filepath)
        db.busy_timeout = 117
        db.busy_handler { |count| true }
        db.transaction 
        db.execute "delete from _data_ where _key_=?", [key]
        db.commit 
        db.close
    end

    # -- sets  --------------------------------------------------

    # Marbles::sets_add(filepath, setId, dataId, data)
    def self.sets_add(filepath, setId, dataId, data)
        raise "87462e7a-80f0-4a4b-8723-4d66a71ba88b" if !File.exist?(filepath)
        Marbles::kvstore_set(filepath, "#{setId}:#{dataId}", data)
    end

    # Marbles::sets_remove(filepath, setId, dataId)
    def self.sets_remove(filepath, setId, dataId)
        raise "934b097e-4cfc-40ba-b48d-93f5f04cf4f4" if !File.exist?(filepath)
        Marbles::kvstore_destroy(filepath, "#{setId}:#{dataId}")
    end

    # Marbles::sets_getElementByIdOrNull(filepath, setId, dataId)
    def self.sets_getElementByIdOrNull(filepath, setId, dataId)
        raise "8975c020-9645-4597-8e22-7d40572412b6: #{filepath}" if !File.exist?(filepath)
        Marbles::kvstore_getOrNull(filepath, "#{setId}:#{dataId}")
    end

    # Marbles::sets_getElements(filepath, setId)
    def self.sets_getElements(filepath, setId)
        raise "d0281dea-0fd8-4ead-88cf-ea591950ecdc: #{filepath}" if !File.exist?(filepath)
        Marbles::keys(filepath)
            .select{|key| key.start_with?("#{setId}:") }
            .map{|key| Marbles::kvstore_get(filepath, key) } # We could also use Marbles::kvstore_getOrNull
    end

    # -- data blobs store --------------------------------------------------

    # Marbles::commitBlob(filepath, blob)
    def self.commitBlob(filepath, blob)
        nhash = "SHA256-#{Digest::SHA256.hexdigest(blob)}"
        # Some operations may accidentally call those functions on a marble that has died, that create an empty file
        Marbles::kvstore_set(filepath, nhash, blob)
        nhash
    end

    # Marbles::getBlobOrNull(filepath, nhash)
    def self.getBlobOrNull(filepath, nhash)
        Marbles::kvstore_getOrNull(filepath, nhash)
    end

    # Marbles::readBlobErrorIfNotFound(filepath, nhash)
    def self.readBlobErrorIfNotFound(filepath, nhash)
        # Some operations may accidentally call those functions on a marble that has died, that create an empty file
        blob = Marbles::kvstore_getOrNull(filepath, nhash)
        return blob if blob
        raise "[Error: 3CCC5678-E1FE-4729-B72B-C7E5D7951983, nhash: #{nhash}]"
    end

    # -- tests --------------------------------------------------

    # Marbles::selfTest()
    def self.selfTest()
        filepath = "/tmp/#{SecureRandom.hex}"
        Marbles::issueNewEmptyMarbleFile(filepath)

        raise "1d464a8d-d4ed-4d81-8e02-1ebeae50df30" if !File.exist?(filepath)

        Marbles::kvstore_set(filepath, "key1", "value1")

        raise "8316ff18-00b9-4bb3-b1e1-93fec175feee" if (Marbles::kvstore_getOrNull(filepath, "key1") != "value1")
        raise "38965323-6b0e-4581-ba9b-af75df8137ef" if (Marbles::kvstore_get(filepath, "key1") != "value1")

        begin
            Marbles::kvstore_get(filepath, "key2") 
            puts "You should not read this"
        rescue
        end

        Marbles::sets_add(filepath, "set1", "1", "Alice")
        Marbles::sets_add(filepath, "set1", "1", "Beth")
        Marbles::sets_add(filepath, "set1", "2", "Celia")

        raise "c3c17399-e6ec-4792-985f-871517f4afc1" if (Marbles::sets_getElementByIdOrNull(filepath, "set1", "2") != "Celia")

        set = Marbles::sets_getElements(filepath, "set1")

        raise "258752df-0fa0-412a-999e-9ed50f1f66c0" if (set.sort.join(":") != "Beth:Celia")

        FileUtils.rm(filepath)
        puts "Marbles::selfTest(), all good!"
    end
end
