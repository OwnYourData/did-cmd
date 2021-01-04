#!/usr/bin/env ruby
# encoding: utf-8

require 'httparty'
require 'ed25519'
require 'base58'
require 'optparse'
require 'rbnacl'
require 'dag'

LOCATION_PREFIX = ";"

def oyd_encode(message)
    # Base58.encode(message.force_encoding('ASCII-8BIT').unpack('H*')[0].to_i(16))
    Base58.binary_to_base58(message.force_encoding('BINARY'))
end

def oyd_decode(message)
    # [Base58.decode(message.force_encoding('ASCII-8BIT')).to_s(16)].pack('H*')
    Base58.base58_to_binary(message)
end

def oyd_hash(message)
    oyd_encode(RbNaCl::Hash.sha256(message))
end

def dag_did(logs)
    dag = DAG.new
    dag_log = []
    log_hash = []
    i = 0
    dag_log << dag.add_vertex(id: i)
    logs.each do |el|
        i += 1
        dag_log << dag.add_vertex(id: i)
        log_hash << oyd_hash(el.to_json)
        if el["previous"] == []
            dag.add_edge from: dag_log[0], to: dag_log[i]
        else
            el["previous"].each do |p|
                position = log_hash.find_index(p)
                if !position.nil?
                    dag.add_edge from: dag_log[position+1], to: dag_log[i]
                end
            end
        end
    end unless logs.nil?
    return dag
end

def dag_update(vertex, logs, currentDID)
    vertex.successors.each do |v|
        current_log = logs[v[:id].to_i - 1]
        if currentDID["last_id"].nil?
            currentDID["last_id"] = current_log["id"].to_i
        else
            if currentDID["last_id"].to_i < current_log["id"].to_i
                currentDID["last_id"] = current_log["id"].to_i
            end
        end
        case current_log["op"]
        when 2,3 # CREATE, UPDATE
            doc_did = current_log["doc"]
            doc_location = get_location(doc_did)
            did_hash = doc_did.delete_prefix("did:oyd:")
            did10 = did_hash[0,10]
            doc = retrieve_document(doc_did, did10 + ".doc", doc_location, {})
            # check if sig matches did doc 
            if match_log_did?(current_log, doc)
                currentDID["doc_log_id"] = v[:id].to_i
                currentDID["did"] = doc_did
                currentDID["doc"] = doc
                if currentDID["last_sign_id"].nil?
                    currentDID["last_sign_id"] = current_log["id"].to_i
                else
                    if currentDID["last_sign_id"].to_i < current_log["id"].to_i
                        currentDID["last_sign_id"] = current_log["id"].to_i
                    end
                end
            end
        when 0
            # TODO: check if termination document exists
            currentDID["termination_log_id"] = v[:id].to_i
        end

        if v.successors.count > 0
            currentDID = dag_update(v, logs, currentDID)
        end
    end
    return currentDID
end

def match_log_did?(log, doc)
    # check if signature matches current document
    # check if signature in log is correct
    publicKeys = doc["key"]
    pubKey_string = publicKeys.split(":")[0] rescue ""
    pubKey = Ed25519::VerifyKey.new(Base58.base58_to_binary(pubKey_string))
    signature = oyd_decode(log["sig"])
    begin
        pubKey.verify(signature, log["doc"])
        return true
    rescue Ed25519::VerifyError
        return false
    end
end

def get_key(filename, key_type)
    begin
        f = File.open(filename)
        key_encoded = f.read
        f.close
    rescue
        return nil
    end
    if key_type == "sign"
        return Ed25519::SigningKey.new(Base58.base58_to_binary(key_encoded))
    else
        return Ed25519::VerifyKey.new(Base58.base58_to_binary(key_encoded))
    end
end

def get_file(filename)
    begin
        f = File.open(filename)
        content = f.read
        f.close
    rescue
        return nil
    end
    return content.to_s
end

def get_location(id)
    if id.include?(LOCATION_PREFIX)
        id_split = id.split(LOCATION_PREFIX)
        return id_split[1]
    else
        return "https://oydid.ownyourdata.eu"
    end
end

def retrieve_document(doc_hash, doc_file, doc_location, options)

    if doc_location == ""
        doc_location = "https://oydid.ownyourdata.eu"
    end

    case doc_location
    when /^http/
        retVal = HTTParty.get(doc_location + "/doc/" + doc_hash)
        if retVal.code != 200
            puts "Error: " + retVal.parsed_response("error").to_s
            exit(1)
        end
        if options[:trace]
            puts "GET " + doc_hash + " from " + doc_location
        end
        return retVal.parsed_response
    when "", "local"
        doc = {}
        begin
            f = File.open(doc_file)
            doc = JSON.parse(f.read) rescue {}
            f.close
        rescue

        end
        if doc == {}
            return nil
        end
    else
        return nil
    end
    return doc

end

def retrieve_log(did_hash, log_file, log_location, options)

    if log_location == ""
        log_location = "https://oydid.ownyourdata.eu"
    end

    case log_location
    when /^http/
        retVal = HTTParty.get(log_location + "/log/" + did_hash)
        if retVal.code != 200
            puts "Error: " + retVal.parsed_response("error").to_s
            exit(1)
        end
        if options[:trace]
            puts "GET log for " + did_hash + " from " + log_location
        end
        retVal = JSON.parse(retVal.to_s) rescue nil
        return retVal
    when "", "local"
        doc = {}
        begin
            f = File.open(log_file)
            doc = JSON.parse(f.read) rescue {}
            f.close
        rescue

        end
        if doc == {}
            return nil
        end
    else
        return nil
    end
    return doc
end


# expected DID format: did:oyd:123

def resolve_did(did, options)
    # setup
    currentDID = {
        "did": did,
        "doc": "",
        "log": [],
        "doc_log_id": nil,
        "termination_log_id": nil,
        "last_id": nil,
        "last_sign_id": nil,
        "error": 0,
        "message": ""
    }.transform_keys(&:to_s)
    did_hash = did.delete_prefix("did:oyd:")
    did10 = did_hash[0,10]

    # get did location
    did_location = ""
    if !options[:doc_location].nil?
        did_location = options[:doc_location]
    end
    if did_location.to_s == ""
        if !options[:location].nil?
            did_location = options[:location]
        end
    end
    if did_location.to_s == ""
        if did.include?(LOCATION_PREFIX)
            tmp = did.split(LOCATION_PREFIX)
            did = tmp[0]
            did_location = tmp[1]
        end
    end

    if did_location == ""
        did_location = "https://oydid.ownyourdata.eu"
    end

    # retrieve DID document
    did_document = retrieve_document(did, did10 +  ".doc", did_location, options)
    if did_document.nil?
        return nil
    end
    currentDID["doc"] = did_document
    if options[:trace]
        puts " .. DID document retrieved"
    end

    # get log location
    log_hash = did_document["log"]
    log_location = ""
    if !options[:log_location].nil?
        log_location = options[:log_location]
    end
    if log_location.to_s == ""
        if !options[:location].nil?
            log_location = options[:location]
        end
    end
    if log_location.to_s == ""
        if log_hash.include?(LOCATION_PREFIX)
            hash_split = log_hash.split(LOCATION_PREFIX)
            log_hash = hash_split[0]
            log_location = hash_split[1]
        end
    end

    if log_location == ""
        log_location = "https://oydid.ownyourdata.eu"
    end

    # retrieve log
    log_array = retrieve_log(log_hash, did10 + ".log", log_location, options)
    currentDID["log"] = log_array

    # traverse log to get current DID state
    dag = dag_did(log_array)
    currentDID = dag_update(dag.vertices.first, log_array, currentDID)

    return currentDID
end

def write_did(content, did, mode, options)
    # generate did_doc and did_key
    did_doc = JSON.parse(content.join("")) rescue {}
    did_old = nil
    prev_hash = []
    revoc_log = nil
    old_log = nil
    doc_location = options[:doc_location]

    if mode == "create"
        first_id = 1
        operation_mode = 2 # CREATE
        privateKey = Ed25519::SigningKey.generate
        revocationKey = Ed25519::SigningKey.generate
    else # mode == "update"  => read information
        did_info = resolve_did(did, options)
        if did_info["error"] != 0
            puts "Error: " + did_info["message"]
            exit(1)
        end

        did = did_info["did"]
        did_old = did
        did_hash = did.delete_prefix("did:oyd:")
        did10 = did_hash[0,10]
        did10_old = did10
        if doc_location.to_s == ""
            if did_hash.include?(LOCATION_PREFIX)
                hash_split = did_hash.split(LOCATION_PREFIX)
                did_hash = hash_split[0]
                doc_location = hash_split[1]
            end
        end
        first_id = did_info["last_id"].to_i + 1
        operation_mode = 3 # UPDATE
        old_log = did_info["log"]

        privateKey = get_key(did10 + "_private_key.b58", "sign")
        revocationKey = get_key(did10 + "_revocation_key.b58", "sign")
        revocationLog = get_file(did10 + "_revocation.json")
        revoc_log = JSON.parse(revocationLog)
        revoc_log["previous"] = [
            oyd_hash(old_log[did_info["doc_log_id"].to_i - 1].to_json), 
            oyd_hash(old_log[did_info["termination_log_id"].to_i - 1].to_json)
        ]
        prev_hash = [oyd_hash(revoc_log.to_json)]
    end

    publicKey = privateKey.verify_key
    pubRevoKey = revocationKey.verify_key
    did_key = Base58.binary_to_base58(publicKey.to_bytes) + ":" + Base58.binary_to_base58(pubRevoKey.to_bytes)

    # build new revocation document
    subDid = {"doc": did_doc, "key": did_key}.to_json
    subDidHash = oyd_hash(subDid)
    signedSubDidHash = oyd_encode(revocationKey.sign(subDidHash))
    r1 = { "ts": Time.now.to_i,
           "op": 1, # REVOKE
           "doc": subDidHash,
           "sig": signedSubDidHash }.transform_keys(&:to_s)
    # check if signedSubDidHahs is valid?
    #   signature = [Base58.decode(signedSubDidHash).to_s(16)].pack('H*')
    #   message = subDidHash
    #   pubRevoKey.verify(signature, message)

    # build termination log entry
    l2_doc = oyd_hash(r1.to_json)
    if !doc_location.nil?
        l2_doc += LOCATION_PREFIX + doc_location.to_s
    end    
    l2 = { "ts": Time.now.to_i,
           "op": 0, # TERMINATE
           "doc": l2_doc,
           "sig": oyd_encode(privateKey.sign(l2_doc)),
           "previous": [] }.transform_keys(&:to_s)

    # build actual DID document
    log_str = oyd_hash(l2.to_json)
    if !doc_location.nil?
        log_str += LOCATION_PREFIX + doc_location.to_s
    end
    didDocument = { "doc": did_doc,
                    "key": did_key,
                    "log": log_str }.transform_keys(&:to_s)

    # build creation log entry
    l1_doc = oyd_hash(didDocument.to_json)
    if !doc_location.nil?
        l1_doc += LOCATION_PREFIX + doc_location.to_s
    end
    l1 = { "ts": Time.now.to_i,
           "op": operation_mode, # CREATE
           "doc": l1_doc,
           "sig": oyd_encode(privateKey.sign(l1_doc)),
           "previous": prev_hash }.transform_keys(&:to_s)

    # create DID
    did = "did:oyd:" + l1_doc
    did10 = l1_doc[0,10]

    if doc_location.to_s == ""
        doc_location = "https://oydid.ownyourdata.eu"
    end

    # wirte data based on location
    case doc_location.to_s
    when /^http/
        # build object to post
        did_data = {
            "did": did,
            "did-document": didDocument,
            "logs": [revoc_log, l1, l2].flatten.compact
        }

        oydid_url = doc_location.to_s + "/doc"
        retVal = HTTParty.post(oydid_url,
            headers: { 'Content-Type' => 'application/json' },
            body: did_data.to_json )
        if retVal.code != 200
            puts "Error: " + retVal.parsed_response['error'].to_s
            exit(1)            
        end
        File.write(did10 + "_private_key.b58", Base58.binary_to_base58(privateKey.to_bytes))
        File.write(did10 + "_revocation_key.b58", Base58.binary_to_base58(revocationKey.to_bytes))
        File.write(did10 + "_revocation.json", r1.to_json)
    else
        # write files to disk
        File.write(did10 + "_private_key.b58", Base58.binary_to_base58(privateKey.to_bytes))
        File.write(did10 + "_revocation_key.b58", Base58.binary_to_base58(revocationKey.to_bytes))
        File.write(did10 + "_revocation.json", r1.to_json)
        File.write(did10 + ".log", [old_log, l1, l2].flatten.compact.to_json)
        if !did_old.nil?
            File.write(did10_old + ".log", [old_log, l1, l2].flatten.compact.to_json)
        end
        File.write(did10 + ".doc", didDocument.to_json)
        File.write(did10 + ".did", did)
    end

    # write DID to stdout
    if mode == "create"
        puts "created " + did
    else
        puts "updated " + did
    end
end

# commandline options
options = { }
opt_parser = OptionParser.new do |opt|
  opt.banner = "Usage: #{$0} OPERATION [OPTIONS]"
  opt.separator  ""
  opt.separator  "OPERATION"
  opt.separator  "OPTIONS"

  opt.on("-l","--location LOCATION","default URL to store/query DID data") do |loc|
    options[:location] = loc
  end
  opt.on("-t","--trace","show trace information when reading DID") do |trc|
    options[:trace] = true
  end
end
opt_parser.parse!
operation = ARGV.shift
input_did = ARGV.shift

if operation == "create" || operation == "update"
    content = []
    ARGF.each_line { |line| content << line }
end

if options[:doc_location].nil?
    options[:doc_location] = options[:location]
end
if options[:log_location].nil?
    options[:log_location] = options[:location]
end

case operation.to_s
when "create"
    write_did(content, nil, "create", options)
when "read"
    result = resolve_did(input_did, options)
    if result.nil?
        puts "Error: cannot resolve DID"
        exit (-1)
    end
    if result["error"] != 0
        puts "Error: " + result["message"].to_s
        exit(-1)
    end
    if !options[:trace]
        puts result["doc"].to_json
    end
when "log"
    log_hash = input_did
    result = resolve_did(input_did, options)
    if result.nil?
        if options[:log_location].nil?
            if input_did.include?(LOCATION_PREFIX)
                retVal = input_did.split(LOCATION_PREFIX)
                log_hash = retVal[0]
                log_location = retVal[1]
            end
        else
            log_location = options[:log_location]
        end
        result = HTTParty.get(log_location + "/log/" + log_hash)
        puts JSON.parse(result.to_s).to_json
    else
        puts result["log"].to_json
    end
when "update"
    write_did(content, input_did, "update", options)
when "clone", "delegate", "challenge", "confirm"
    puts "Warning: function not yet available"
else
    puts "Usage: oydid [OPERATION] [OPTION]"
    puts "manage DIDs using the oyd:did method"
    puts ""
    puts "operations:"
    puts "  create    - new DID, reads doc from STDIN"
    puts "  read      - output DID Document for given DID in option"
    puts "  update    - update DID Document, reads doc from STDIN and DID specified as option"
    puts "  log       - print complete log for given DID or log entry hash"
    puts "  clone     - clone DID to new location"
    puts "  delegate  - add log entry with additional keys for validating signatures of"
    puts "              document or revocation entries"
    puts "  challenge - publish challenge for given DID and revoke specified as options"
    puts "  confirm   - confirm specified clones for given DID"
    puts ""
    puts "options:"
    puts "  --doc-key   - filename with Base58 encoded private key for signing documents"
    puts "  --rev-key   - filename with Base58 encoded private key for signing a revocation"
    puts "  --show-hash - for log output additionally show hash value of each entry"
end
