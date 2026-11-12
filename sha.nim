import sequtils
import std/strutils

const initial_h0: uint32 = cast[uint32](0x67452301)
const initial_h1: uint32 = cast[uint32](0xEFCDAB89)
const initial_h2: uint32 = cast[uint32](0x98BADCFE)
const initial_h3: uint32 = cast[uint32](0x10325476)
const initial_h4: uint32 = cast[uint32](0xC3D2E1F0)

proc encodeMsgLength(value: int): seq[byte] = 
    var res: seq[byte]
    var i: int = 0
    var val: int = value * 8

    while i<8:
        res.insert(cast[byte](val), 0)
        val = val shr 8
        i+=1

    return res

proc applyPadding(msg: seq[byte]): seq[byte] = 
    var og_len_bytes: int = msg.len
    var padded_msg: seq[byte] = msg
    
    # add one to message
    padded_msg.add(cast[byte](128))

    var current_msg_len_in_bytes: int = padded_msg.len

    # pad with zeros...
    var bytes_to_pad: int = (((56 - current_msg_len_in_bytes) mod 64) + 64) mod 64

    for i in 0..<bytes_to_pad:
        padded_msg.add(cast[byte](0))
    
    var encoded_len: seq[byte] = encodeMsgLength(og_len_bytes)
    padded_msg = padded_msg.concat(encoded_len)

    # ...to fit the encoded length
    return padded_msg

proc extendBlocks(padded_msg: seq[byte]): seq[seq[uint32]] = 
    var extended_blocks: seq[seq[uint32]]
    var n_blocks: int = padded_msg.len div 64
    
    # for each block (1 block = 64 bytes = 512 bits)
    for i in 0..<n_blocks: 
        var part: seq[uint32]
        
        # and each word (1 word = 4 bytes = 32 bits)
        for j in 0..<16:
            var n: uint32 = 0
            
            # and each byte in word
            for k in 0..<4:
                n = n shl 8

                # do the magic
                n = n or cast[uint32](padded_msg[(i*64 + j*4 + k)])

            part.add(n)
        extended_blocks.add(part)

    return extended_blocks

proc bitwiseRotateLeft(n: uint32, x: uint32, w: uint32=32): uint32 = 
    return (x shl n) or (x shr (w - n))

proc hashTheShit(extended_blocks: seq[seq[uint32]]): string = 
    var h0: uint32 = initial_h0
    var h1: uint32 = initial_h1
    var h2: uint32 = initial_h2
    var h3: uint32 = initial_h3
    var h4: uint32 = initial_h4

    for bl in extended_blocks:

        var W: seq[uint32] = bl
        
        # extend each block
        for t in 16..80:
            var x: uint32 = (W[t-3] xor W[t-8] xor W[t-14] xor W[t-16])
            var w: uint32 = bitwiseRotateLeft(1, x)
            W.add(w)
        
        var a: uint32 = h0
        var b: uint32 = h1
        var c: uint32 = h2
        var d: uint32 = h3
        var e: uint32 = h4

        var K: uint32
        var f: uint32
        var T: uint32

        for t in 0..<80:
            if t <= 19:
                K = cast[uint32](0x5a827999)
                f = (b and c) or (not(b) and d)
            elif t <= 39:
                K = cast[uint32](0x6ed9eba1)
                f = b xor c xor d
            elif t <= 59:
                K = cast[uint32](0x8f1bbcdc)
                f = (b and c) or (b and d) or (c and d)
            else:
                K = cast[uint32](0xca62c1d6)
                f = b xor c xor d
            
            T = (bitwiseRotateLeft(5, a) + f + e + K + W[t])
            e = d
            d = c
            c = bitwiseRotateLeft(30, b)
            b = a
            a = T

        h0 = (h0 + a)
        h1 = (h1 + b)
        h2 = (h2 + c)
        h3 = (h3 + d)
        h4 = (h4 + e)
    
    return toHex(h0, 8) & toHex(h1, 8) & toHex(h2, 8) & toHex(h3, 8) & toHex(h4, 8)

proc generateSHA1Hash*(raw_bytes: seq[byte]): string =
    
    var padded_msg: seq[byte] = applyPadding(raw_bytes)
    var extended_blocks: seq[seq[uint32]] = extendBlocks(padded_msg) 
    var hash: string = hashTheShit(extended_blocks)

    return hash
