local component = require("component")
local bit32 = require("bit32")
local serialization = require("serialization")
local fs = require("filesystem")

local data = component.getPrimary("data")
if (not data) or (not data.ed25519) then
    error("libcert requires a t3 data card supporting ed25519 signing.")
end

local certdir = "/etc/certs"
local trustedFileName = "trusted"
local trustedPath = ("%s/%s"):format(certdir, trustedFileName)
--                   HDR VER ISR SUB KEY KFM FRM TO  FLG
local certPartFmt = "c6  H   s2  s2  s2  s1  d   d   B   "
--                   HDR VER ISR SUB KEY KFM FRM TO  FLG SIG
local certFullFmt = "c6  H   s2  s2  s2  s1  d   d   B   s1"

local certMagic = "cc.504"

if not fs.exists(certdir) then
    local ok, err = fs.makeDirectory(certdir)
    if not ok then
        error("failed to create " .. certdir .. ": " .. err)
    end
end

local function encodeSafe64(s)
    checkArg(1, s, "string")

    return data.encode64(s):gsub("%+", "-"):gsub("/", "_")
end

local function decodeSafe64(s)
    checkArg(1, s, "string")

    return data.decode64(s:gsub("-", "+"):gsub("_", "/"))
end

local p = {}
p._VERSION = 1

p.create = function(issuer, subject, pubKey, from, to, isSigner)
    checkArg(1, issuer, "string")
    checkArg(2, subject, "string")
    checkArg(3, pubKey, "table")
    checkArg(4, from, "number")
    checkArg(5, to, "number")
    checkArg(6, isSigner, "boolean")

    -- Flag Byte: 0, 0, 0, 0, 0, 0, 0, isSigner
    local flagByte = 0
    flagByte = bit32.bor(flagByte, bit32.lshift(isSigner and 1 or 0, 0))
    if not from then from = 0 end
    if not to then to = 0 end

    local pubKeyString = pubKey.serialize()
    local keyFmt = pubKey.keyType()
    local certPart = string.pack(certPartFmt, certMagic, p._VERSION, issuer, subject, pubKeyString, keyFmt, from, to, flagByte)
    return certPart
end

p.sign = function(certPart, key)
    checkArg(1, certPart, "string")
    checkArg(2, key, "table")

    local sig = data.ed25519(certPart, key)
    local cert = certPart .. string.pack("s1", sig)

    return cert
end

p.unpack = function(cert)
    checkArg(1, cert, "string")

    -- Flag Byte: 0, 0, 0, 0, 0, 0, 0, isSigner
    local ok, magic, version, issuer, subject, keyString, keyFmt, from, to, flags, sig = pcall(string.unpack, certFullFmt, cert)
    if not ok or magic ~= certMagic or version ~= p._VERSION or to < from or from < 0 or to < 0 then
        return nil
    end

    local isSigner = bit32.band(flags, bit32.rshift(1, 0)) ~= 0

    local key = data.deserializeKey(keyString, keyFmt)
    return issuer, subject, key, from, to, sig, isSigner
end

p.save = function(cert, overwrite)
    checkArg(1, cert, "string")

    local ok, subject = p.unpack(cert)
    if overwrite == nil then overwrite = false end

    if not ok then
        error("malformed certificate")
    end

    local certpath = ("%s/%s.cert"):format(certdir, encodeSafe64(subject))
    if not overwrite then
        if fs.exists(certpath) then
            error(certpath.." already exists.")
        end
    end

    local file = io.open(certpath, "w")
    file:write(cert)
    file:close()
end

p.load = function(subject)
    checkArg(1, subject, "string")

    local certpath = ("%s/%s.cert"):format(certdir, encodeSafe64(subject, "-_"))
    if not fs.exists(certpath) then
        return nil
    end

    local file = io.open(certpath, "r")
    local cert = file:read("*a")
    file:close()

    local ok = p.unpack(cert)
    if not ok then
        error("malformed certificate")
    end

    return cert
end

p.setTrust = function(cert, bool)
    checkArg(1, cert, "string")
    checkArg(2, bool, "boolean")

    local trustedList = {}

    local trustedFile = io.open(trustedPath, "r")
    if trustedFile then
        trustedList = serialization.unserialize(trustedFile:read("*a"))
        trustedFile:close()
    end

    trustedList[data.sha256(cert)] = bool

    local err
    trustedFile, err = io.open(trustedPath, "w")
    if trustedFile then
        trustedFile:write(serialization.serialize(trustedList))
        trustedFile:close()
    else
        error("failed to open " .. trustedPath .. ": " .. err)
    end
end

p.verify = function(cert, depth)
    checkArg(1, cert, "string")

    depth = (depth or 0) + 1
    if depth > 32 then
        error("certificate chains may not exceed 32 signers.")
    end

    local issuer, subject, _, from, to, sig = p.unpack(cert)
    if not issuer then
        return false
    end

    local trustedFile = io.open(trustedPath, "r")
    if trustedFile then
        local trustedList = serialization.unserialize(trustedFile:read("*a"))
        trustedFile:close()

        if trustedList[data.sha256(cert)] == true then
            return true
        end
    end

    if subject == issuer then
        return false
    end

    local icert = p.load(issuer)
    if not p.verify(icert, depth) then
        return false
    end

    local _, _, ikey, _, _, _, isParentSigner = p.unpack(icert)
    if not isParentSigner then
        return false
    end

    local curtime = os.time()
    if not (from == 0 and to == 0) then
        if curtime > to or curtime < from or to < from then
            return false
        end
    end

    local certPayload = cert:sub(1, -(2 + #sig))

    if data.ed25519(certPayload, ikey, sig) then
        return true
    else
        return false
    end
end

p.hasIssuer = function(cert)
    checkArg(1, cert, "string")

    local issuer = p.unpack(cert)
    if not issuer then
        return nil
    end

    if not p.load(issuer) then
        return false, issuer
    else
        return true
    end
end

p.getKey = function(cert)
    checkArg(1, cert, "string")

    local _, _, key= p.unpack(cert)
    return key
end

return p
