import std/parseopt

proc parseFilename(): string = 

    var filename: string = ""

    for kind, key, val in getopt():
        case kind
        of cmdEnd: break
        of cmdShortOption, cmdLongOption:
            discard
        of cmdArgument:
            filename = key

    return filename

proc readBinaryDataFromFile*(): seq[byte] =
    var f: File 
    var bytes_read: seq[byte]

    if open(f, parseFilename(), fmRead):
        defer: f.close()
        bytes_read = newSeq[byte](f.getFileSize())
        discard f.readBytes(bytes_read, 0, bytes_read.len)
    else:
        echo "failed"
        return

    return bytes_read
